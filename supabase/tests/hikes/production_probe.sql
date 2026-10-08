-- Hikes (D-31): probe for the live database. Changes nothing.
-- It adds a temporary Eretz Israel Tours member, a temporary guide and a temporary organisation, opens hikes to all
-- inside its own transaction, calls the app's functions as each of them, and ends by raising an error that carries
-- the results, so everything it did is rolled back: members, setting, hikes, reports and route file. Read the JSON
-- after "PROBE". Run it as one statement (Supabase SQL editor, or the connector's execute_sql) after
-- supabase/migrations/2026-10-08_hikes.sql has been run, and after any later change to a hike function.
--
-- What must come back:
--   closed_member_list = []                closed_member_save = "Hikes are not open yet."
--   whoami_guide_hikes, whoami_org_hikes = true; whoami_org_type = "limited"
--   admin_hike_status = "approved"; admin_hike_by = "Eretz Israel Tours"
--   guide_hike_status = "pending"
--   org_sees_pending = false           (the organisation stands in for any other member)
--   org_detail_pending, org_gpx_pending = "That hike is not available."
--   member_approve = "Only Eretz Israel Tours can do that."
--   stale_approve = "This hike was changed after you opened it. Open it again and check it before you approve."
--   approve = "ok"; org_sees_after = true
--   writer_edit_after = "This hike is approved. Suggest a change and Eretz Israel Tours will update it."
--   org_report: n = 1, org = true, by = "Probe Org"
--   bad_gpx = "That route file holds something a GPX file should not. Save it again from your hiking app."
--   gpx_name = "route.gpx"; gpx_same = true
--   second_gpx = "This hike already has a route file."
--   emails_in_output = 0                   (no member's email, the probe's or a real one, in anything a hike call returned)
--   helpers_callable = false; tables_open = false; calls_granted = 7
--   rows_before = rows_now_minus_probe   (nothing of the list's own was touched)
do $probe$
declare ta text := 'probe-admin-' || md5(random()::text) || md5(random()::text);
  tg text := 'probe-guide-' || md5(random()::text) || md5(random()::text);
  tl text := 'probe-org-' || md5(random()::text) || md5(random()::text);
  r jsonb := '{}'::jsonb; a jsonb; g jsonb; d jsonb; x jsonb; err text; n0 int; seen timestamptz;
  gpx text := '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle"><wpt lat="31.5" lon="35.4"><name>Probe spot</name></wpt><trk><trkseg><trkpt lat="31.5" lon="35.4"><ele>-300</ele></trkpt><trkpt lat="31.51" lon="35.41"/></trkseg></trk></gpx>';
  base jsonb := '{"region":"Dead Sea & Judean Desert","official":true,"distance_km":"5","hours_from":"3","hours_to":"4","start_place":"Probe trailhead","notes":"Probe."}'::jsonb;
begin
  select count(*) into n0 from public.hikes;
  insert into public.members (name,email,role,token_hash,status,is_admin) values ('Probe Admin Person','probe-admin@invalid.test','',public._hash(ta),'approved',true);
  insert into public.members (name,email,role,token_hash,status) values ('Probe Guide','probe-guide@invalid.test','Licensed tour guide',public._hash(tg),'approved');
  insert into public.members (name,email,role,token_hash,status,member_type,sections,org,credentials)
  values ('Probe Org','probe-org@invalid.test','Other',public._hash(tl),'approved','limited','transport','Probe Yeshiva','probe probe probe probe probe');

  -- closed: as the setting stands on the live database when this runs, forced to 'admin' here
  insert into public.app_settings (key, value) values ('hikes_for','admin') on conflict (key) do update set value = 'admin';
  r := r || jsonb_build_object('closed_member_list', public.hikes_list(tg)::jsonb);
  begin perform public.hike_save(tg, base || '{"name":"Probe closed"}'); r := r || '{"closed_member_save":"SAVED"}';
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('closed_member_save', err); end;

  perform public.set_setting(ta, 'hikes_for', 'all');
  r := r || jsonb_build_object('whoami_guide_hikes', (public.whoami(tg)::jsonb)->'hikes', 'whoami_org_hikes', (public.whoami(tl)::jsonb)->'hikes', 'whoami_org_type', (public.whoami(tl)::jsonb)->'member_type');

  a := public.hike_save(ta, base || '{"name":"Probe admin hike","is_loop":true}')::jsonb;
  r := r || jsonb_build_object('admin_hike_status', a->'review_status', 'admin_hike_by', a->'by');
  g := public.hike_save(tg, base || jsonb_build_object('name','Probe guide hike','end_place','Probe road','gpx',gpx,'markers','[{"color":"blue","number":"1234"}]'::jsonb))::jsonb;
  r := r || jsonb_build_object('guide_hike_status', g->'review_status');
  r := r || jsonb_build_object('org_sees_pending', exists (select 1 from jsonb_array_elements(public.hikes_list(tl)::jsonb) e where e->>'id' = g->>'id'));
  begin perform public.hike_detail(tl, (g->>'id')::uuid); r := r || '{"org_detail_pending":"OPENED"}';
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('org_detail_pending', err); end;
  begin perform public.hike_gpx(tl, (g->>'id')::uuid); r := r || '{"org_gpx_pending":"FETCHED"}';
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('org_gpx_pending', err); end;
  begin perform public.hike_decide(tg, (g->>'id')::uuid, true, (g->>'updated_at')::timestamptz); r := r || '{"member_approve":"APPROVED"}';
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('member_approve', err); end;

  -- the admin reads it, the writer changes it, the approval of what was read is refused
  select (e->>'updated_at')::timestamptz into seen from jsonb_array_elements(public.hikes_list(ta)::jsonb) e where e->>'id' = g->>'id';
  perform public.hike_save(tg, base || jsonb_build_object('id', g->>'id', 'name','Probe guide hike','end_place','Probe road changed'));
  begin perform public.hike_decide(ta, (g->>'id')::uuid, true, seen); r := r || '{"stale_approve":"APPROVED"}';
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('stale_approve', err); end;
  select (e->>'updated_at')::timestamptz into seen from jsonb_array_elements(public.hikes_list(ta)::jsonb) e where e->>'id' = g->>'id';
  perform public.hike_decide(ta, (g->>'id')::uuid, true, seen); r := r || '{"approve":"ok"}';
  r := r || jsonb_build_object('org_sees_after', exists (select 1 from jsonb_array_elements(public.hikes_list(tl)::jsonb) e where e->>'id' = g->>'id'));
  begin perform public.hike_save(tg, base || jsonb_build_object('id', g->>'id', 'name','Probe renamed')); r := r || '{"writer_edit_after":"SAVED"}';
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('writer_edit_after', err); end;

  d := public.hike_report_save(tl, (g->>'id')::uuid, '{"walked_on":"2026-09-01","group_size":"30","age_min":"14","age_max":"17","difficulty":"moderate","cliffs":"yes","firing_zone":"crosses","bathrooms":"none"}')::jsonb;
  r := r || jsonb_build_object('org_report', jsonb_build_object('n', d->'hike'->'r'->'n', 'org', d->'reports'->0->'org', 'by', d->'reports'->0->'by', 'cliffs', d->'hike'->'r'->'cliffs'));
  begin perform public.hike_save(ta, base || jsonb_build_object('id', a->>'id', 'name','Probe admin hike','is_loop',true,'gpx','<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle"><metadata><author><name>x</name></author></metadata><trk><trkseg><trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/></trkseg></trk></gpx>')); r := r || '{"bad_gpx":"SAVED"}';
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('bad_gpx', err); end;
  x := public.hike_gpx(tl, (g->>'id')::uuid)::jsonb;
  r := r || jsonb_build_object('gpx_name', x->'name', 'gpx_same', (x->>'body') = gpx);
  begin perform public.hike_report_save(tl, (g->>'id')::uuid, jsonb_build_object('walked_on','2026-09-02','gpx',gpx)); r := r || '{"second_gpx":"SAVED"}';
  exception when others then get stacked diagnostics err = message_text; r := r || jsonb_build_object('second_gpx', err); end;

  r := r || jsonb_build_object('emails_in_output', (select count(*) from (values (public.hikes_list(tl)::text), (public.hikes_list(tg)::text), (public.hikes_list(ta)::text),
      (public.hike_detail(tl, (g->>'id')::uuid)::text), (public.hike_detail(ta, (g->>'id')::uuid)::text)) v(t)
      where t like '%invalid.test%' or t like '%Probe Admin Person%' or exists (select 1 from public.members mm where mm.email <> '' and position(mm.email in t) > 0)));
  r := r || jsonb_build_object(
    'helpers_callable', (select bool_or(has_function_privilege(ro, p.oid, 'execute')) from pg_proc p, unnest(array['anon','authenticated','public']) ro where p.pronamespace = 'public'::regnamespace and p.proname like '\_hike%'),
    'tables_open', (select bool_or(coalesce(c.relacl::text,'') ~ '(^|[{,])(anon|authenticated)?=') or not bool_and(c.relrowsecurity) from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname in ('hikes','hike_reports','hike_gpx')),
    'calls_granted', (select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('hikes_list','hike_detail','hike_save','hike_decide','hike_report_save','hike_report_hide','hike_gpx') and has_function_privilege('anon', p.oid, 'execute')),
    'rows_before', n0, 'rows_now_minus_probe', (select count(*) from public.hikes where id::text not in (a->>'id', g->>'id')));
  raise exception 'PROBE %', r::text;
end $probe$;
