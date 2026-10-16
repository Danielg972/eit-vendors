-- Transport prices with their details (D-54): probe for the live database. Changes nothing: it adds temporary members
-- and suppliers, calls the app's functions as each of them, and ends by raising an error that carries the results, so
-- everything is rolled back. Read the JSON after "PROBE". Run as one statement after 2026-10-16_transport_details.sql.
--
-- What must come back:
--   saved_keys = "bags,city,dir,kind,paid,pax,time,veh"  (only known keys; "evil" dropped)
--   old_page_keeps = true          (a save without a transport key keeps the details)
--   cleared_by_new_page = true     (a save with an empty transport clears them)
--   guide_lines = 2                (agent + public on the visible company; nothing from the hidden one, the private line or another's own line)
--   guide_sees_agent = true; guide_sees_details = true
--   guide_own_line_mine = true     (after the guide adds his own line: 3 lines, one of them "mine")
--   org_lines = 1; org_sees_agent = false        (C3: an organisation never receives an agent rate)
--   org_none_lines = 0             (an organisation without Transportation)
--   admin_lines >= 4               (the admin sees the hidden company and the private line too)
--   detail_has_transport = true    (vendor_detail carries the details)
--   emails_in_output = 0; tables_open = false; clean_callable = false; call_granted = true
do $probe$
declare ta text := 'probe-admin-' || md5(random()::text) || md5(random()::text);
  tg text := 'probe-guide-' || md5(random()::text) || md5(random()::text);
  tc text := 'probe-col-' || md5(random()::text) || md5(random()::text);
  t1 text := 'probe-org1-' || md5(random()::text) || md5(random()::text);
  t2 text := 'probe-org2-' || md5(random()::text) || md5(random()::text);
  r jsonb := '{}'::jsonb; x jsonb; vc text; vh text; pid uuid; allout text := '';
  det jsonb := '{"kind":"transfer","dir":"from","city":"Probe City","veh":"van16","pax":"12","bags":"yes","paid":"quoted","time":"day","evil":"x"}'::jsonb;
begin
  insert into public.members (name, email, token_hash, status, is_admin, role) values ('Probe Admin', 'probe-admin@probe.invalid', public._hash(ta), 'approved', true, '');
  insert into public.members (name, email, token_hash, status, role) values ('Probe Guide', 'probe-guide@probe.invalid', public._hash(tg), 'approved', 'Licensed tour guide');
  insert into public.members (name, email, token_hash, status, role) values ('Probe Colleague', 'probe-col@probe.invalid', public._hash(tc), 'approved', 'Licensed tour guide');
  insert into public.members (name, email, token_hash, status, role, member_type, sections, org) values
    ('Probe Org', 'probe-org1@probe.invalid', public._hash(t1), 'approved', '', 'limited', 'transport', 'Probe Org'),
    ('Probe Org None', 'probe-org2@probe.invalid', public._hash(t2), 'approved', '', 'limited', 'hotels', 'Probe Org None');
  perform set_config('app.admin', 'on', true); perform set_config('app.editor', 'probe-admin@probe.invalid', true);
  insert into public.vendors (name, category) values ('Probe vans', 'Transport') returning id into vc;
  insert into public.vendors (name, category, hidden) values ('Probe vans hidden', 'Transport', true) returning id into vh;
  update public.vendors set review_status = 'approved' where id in (vc, vh);
  perform set_config('app.admin', 'off', true);
  -- admin lines: agent with details, public, private, and one on the hidden company
  perform public.price_save(ta, vc, jsonb_build_object('label','Airport transfer: Ben Gurion → Probe City · Van, 11–16 seats','audience','Vehicle','price','800','basis','Per vehicle','is_agent',true,'transport',det), '');
  perform public.price_save(ta, vc, jsonb_build_object('label','Day rate · Van, 11–16 seats','audience','Vehicle','price','2000','basis','Per day','is_agent',false,'transport','{"kind":"day","veh":"van16"}'::jsonb), '');
  perform public.price_save(ta, vc, jsonb_build_object('label','Private line','audience','Vehicle','price','1','basis','Per vehicle','is_agent',true,'private',true), '');
  perform public.price_save(ta, vh, jsonb_build_object('label','Hidden company line','audience','Vehicle','price','2','basis','Per vehicle','is_agent',true), '');
  perform public.price_save(tc, vc, jsonb_build_object('label','Colleague own','audience','Vehicle','price','3','basis','Per vehicle','mine',true), '');
  select id into pid from public.vendor_prices where vendor_id = vc and price = '800';
  r := r || jsonb_build_object('saved_keys', (select string_agg(k, ',' order by k) from jsonb_object_keys((select transport from public.vendor_prices where id = pid)) k));
  perform public.price_save(ta, vc, jsonb_build_object('id',pid,'label','Airport transfer: Ben Gurion → Probe City · Van, 11–16 seats','audience','Vehicle','price','850','basis','Per vehicle','is_agent',true), '');
  r := r || jsonb_build_object('old_page_keeps', (select transport->>'city' = 'Probe City' from public.vendor_prices where id = pid));
  x := (public.transport_prices(tg))::jsonb; allout := allout || x::text;
  x := (select coalesce(jsonb_agg(e),'[]') from jsonb_array_elements(x) e where e->>'vendor_id' in (vc, vh));
  r := r || jsonb_build_object('guide_lines', jsonb_array_length(x),
    'guide_sees_agent', exists (select 1 from jsonb_array_elements(x) e where (e->>'is_agent')::boolean),
    'guide_sees_details', exists (select 1 from jsonb_array_elements(x) e where e->'transport'->>'pax' = '12'));
  perform public.price_save(tg, vc, jsonb_build_object('label','Guide own','audience','Vehicle','price','4','basis','Per vehicle','mine',true,'transport','{"kind":"hour","veh":"van16"}'::jsonb), '');
  x := (select coalesce(jsonb_agg(e),'[]') from jsonb_array_elements((public.transport_prices(tg))::jsonb) e where e->>'vendor_id' = vc);
  r := r || jsonb_build_object('guide_own_line_mine', jsonb_array_length(x) = 3 and exists (select 1 from jsonb_array_elements(x) e where (e->>'mine')::boolean));
  x := (public.transport_prices(t1))::jsonb; allout := allout || x::text;
  x := (select coalesce(jsonb_agg(e),'[]') from jsonb_array_elements(x) e where e->>'vendor_id' in (vc, vh));
  r := r || jsonb_build_object('org_lines', jsonb_array_length(x), 'org_sees_agent', exists (select 1 from jsonb_array_elements(x) e where (e->>'is_agent')::boolean));
  x := (public.transport_prices(t2))::jsonb; allout := allout || x::text;
  r := r || jsonb_build_object('org_none_lines', jsonb_array_length(x));
  x := (select coalesce(jsonb_agg(e),'[]') from jsonb_array_elements((public.transport_prices(ta))::jsonb) e where e->>'vendor_id' in (vc, vh));
  r := r || jsonb_build_object('admin_lines', jsonb_array_length(x));
  x := (public.vendor_detail(tg, vc))::jsonb;
  r := r || jsonb_build_object('detail_has_transport', exists (select 1 from jsonb_array_elements(x->'prices') e where e->'transport'->>'city' = 'Probe City'));
  perform public.price_save(ta, vc, jsonb_build_object('id',pid,'label','Something else','audience','Vehicle','price','850','basis','Per vehicle','is_agent',true,'transport','{}'::jsonb), '');
  r := r || jsonb_build_object('cleared_by_new_page', (select transport = '{}'::jsonb from public.vendor_prices where id = pid));
  r := r || jsonb_build_object('emails_in_output', (select count(*) from regexp_matches(allout, '[a-z0-9._-]+@[a-z0-9.-]+', 'g')),
    'tables_open', exists (select 1 from information_schema.role_table_grants where table_schema = 'public' and table_name = 'vendor_prices' and grantee in ('anon','authenticated')),
    'clean_callable', has_function_privilege('anon', 'public._transport_clean(jsonb)', 'execute'),
    'call_granted', has_function_privilege('anon', 'public.transport_prices(text)', 'execute'));
  raise exception 'PROBE %', r::text;
end $probe$;
