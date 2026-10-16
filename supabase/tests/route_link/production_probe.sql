-- "Open in Mapeak" opens the route (D-53): probe for the live database. Changes nothing.
-- It adds a temporary Eretz Israel Tours member, a temporary guide and a temporary second guide, adds hikes inside its
-- own transaction, calls hike_route_link as each of them and _hike_route_public as the edge function does, and ends by
-- raising an error that carries the results, so everything it did is rolled back. Read the JSON after "PROBE".
-- Run it as one statement (Supabase SQL editor, or the connector's execute_sql) after
-- supabase/migrations/2026-10-16_hike_route_link.sql, and after any later change to a hike function.
--
-- What must come back:
--   bad_link = "Your link is not active. Ask Eretz Israel Tours for a new one."  (or the app's own wording for it)
--   other_pending = "That hike is not available."        (a guide who cannot see another's waiting hike)
--   own_pending = "This hike opens in Mapeak once Eretz Israel Tours has approved it."
--   no_route = "This hike has no route file yet."
--   code_ok = true; code_stable = true                    (32 letters; the same for the guide, the other guide and the admin)
--   public_same = true                                    (_hike_route_public gives exactly the stored GPX)
--   wrong_code = true                                     (a wrong code gives nothing)
--   removed_public = true; removed_link = "This hike has no route file yet."
--   rejected_public = true                                (a hike taken off the list gives nothing)
--   anon_public = "permission denied ..."                 (the lookup cannot be called from outside)
--   real_codes_untouched = true                           (no code of a real hike was made or changed)
do $probe$
declare ta text := 'probe-admin-' || md5(random()::text) || md5(random()::text);
  tg text := 'probe-guide-' || md5(random()::text) || md5(random()::text);
  t2 text := 'probe-guide2-' || md5(random()::text) || md5(random()::text);
  r jsonb := '{}'::jsonb; h1 jsonb; h2 jsonb; hp jsonb; c1 text; err text; codes0 text;
  gpx text := '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle"><trk><trkseg><trkpt lat="31.5" lon="35.4"/><trkpt lat="31.51" lon="35.41"/></trkseg></trk></gpx>';
  base jsonb := '{"region":"Dead Sea & Judean Desert","official":true,"distance_km":"5","hours_from":"3","hours_to":"4","start_place":"Probe trailhead","notes":"Probe.","source":"walked"}'::jsonb;
  seen text;
begin
  select coalesce(string_agg(hike_id::text || '=' || coalesce(link_code, ''), ',' order by hike_id), '') into codes0 from public.hike_gpx;
  insert into public.members (name, email, token_hash, status, is_admin, role) values ('Probe Admin', 'probe-admin@probe.invalid', public._hash(ta), 'approved', true, '');
  insert into public.members (name, email, token_hash, status, role, license_no, phone) values ('Probe Guide', 'probe-guide@probe.invalid', public._hash(tg), 'approved', 'Licensed tour guide', '0', '');
  insert into public.members (name, email, token_hash, status, role, license_no, phone) values ('Probe Guide Two', 'probe-guide2@probe.invalid', public._hash(t2), 'approved', 'Licensed tour guide', '0', '');
  insert into public.app_settings (key, value) values ('hikes_for', 'all') on conflict (key) do update set value = 'all';
  h1 := public.hike_save(ta, base || jsonb_build_object('name', 'Probe With Route', 'gpx', gpx));
  h2 := public.hike_save(ta, base || jsonb_build_object('name', 'Probe No Route'));
  hp := public.hike_save(tg, base || jsonb_build_object('name', 'Probe Waiting', 'gpx', gpx));
  begin perform public.hike_route_link('probe-no-such-link-0000000000000000', (h1->>'id')::uuid); r := r || '{"bad_link":"returned"}'; exception when others then r := r || jsonb_build_object('bad_link', sqlerrm); end;
  begin perform public.hike_route_link(t2, (hp->>'id')::uuid); r := r || '{"other_pending":"returned"}'; exception when others then r := r || jsonb_build_object('other_pending', sqlerrm); end;
  begin perform public.hike_route_link(tg, (hp->>'id')::uuid); r := r || '{"own_pending":"returned"}'; exception when others then r := r || jsonb_build_object('own_pending', sqlerrm); end;
  begin perform public.hike_route_link(tg, (h2->>'id')::uuid); r := r || '{"no_route":"returned"}'; exception when others then r := r || jsonb_build_object('no_route', sqlerrm); end;
  c1 := public.hike_route_link(tg, (h1->>'id')::uuid);
  r := r || jsonb_build_object('code_ok', c1 ~ '^[A-Za-z0-9_-]{32}$',
    'code_stable', c1 = public.hike_route_link(t2, (h1->>'id')::uuid) and c1 = public.hike_route_link(ta, (h1->>'id')::uuid) and c1 = public.hike_route_link(tg, (h1->>'id')::uuid),
    'public_same', public._hike_route_public(c1) = gpx,
    'wrong_code', public._hike_route_public(repeat('A', 32)) is null and public._hike_route_public('%') is null);
  perform public.hike_save(ta, base || jsonb_build_object('id', h1->>'id', 'name', 'Probe With Route', 'gpx_remove', true));
  r := r || jsonb_build_object('removed_public', public._hike_route_public(c1) is null);
  begin perform public.hike_route_link(tg, (h1->>'id')::uuid); r := r || '{"removed_link":"returned"}'; exception when others then r := r || jsonb_build_object('removed_link', sqlerrm); end;
  perform public.hike_save(ta, base || jsonb_build_object('id', h1->>'id', 'name', 'Probe With Route', 'gpx', gpx));
  perform public.hike_decide(ta, (h1->>'id')::uuid, false);
  r := r || jsonb_build_object('rejected_public', public._hike_route_public(c1) is null);
  begin set local role anon; perform public._hike_route_public(c1); reset role; r := r || '{"anon_public":"returned"}'; exception when others then reset role; r := r || jsonb_build_object('anon_public', sqlerrm); end;
  r := r || jsonb_build_object('real_codes_untouched', codes0 = (select coalesce(string_agg(hike_id::text || '=' || coalesce(link_code, ''), ',' order by hike_id), '') from public.hike_gpx
      where hike_id not in ((h1->>'id')::uuid, (h2->>'id')::uuid, (hp->>'id')::uuid)));
  raise exception 'PROBE %', r;
end $probe$;
