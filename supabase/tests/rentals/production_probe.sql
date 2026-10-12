-- Eshkol / Midbari rentals (D-42) and wineries under Restaurant and Attraction / Site (D-43): probe for the live database.
-- Changes nothing. It adds a temporary Eretz Israel Tours member, a temporary guide, three temporary organisations and
-- three temporary rental companies, opens rentals and wineries inside its own transaction, calls the app's functions as
-- each of them, and ends by raising an error that carries the results, so everything it did is rolled back: members,
-- suppliers, vehicles, days, reviews and both settings. Read the JSON after "PROBE". Run it as one statement (Supabase
-- SQL editor, or the connector's execute_sql) after supabase/migrations/2026-10-12_rentals.sql and
-- 2026-10-12b_wineries_under_sites.sql have been run, and after any later change to a rental function.
-- Before 2026-10-12c_vehicle_rental_category.sql has been run the companies are Transport that also offer Vehicle Rental
-- (category_on_list = false); afterwards their category is Vehicle Rental itself.
--
-- What must come back:
--   closed_guide_vehicles = 0; closed_guide_save = "Eshkol / Midbari rentals are not open yet."
--   closed_guide_sees_company = (true before file c: the company is Transport; false after it: Vehicle Rental stays hidden)
--   guide_vehicles = 2           (the approved, visible company's two; none of the hidden or the pending one)
--   guide_hidden_open, guide_pending_open = "That vehicle is not available."
--   guide_agent_price = 600      (a full member sees the agent day price, C5)
--   org_vehicles = 2; org_retail_price = 850
--   org_agent_price = null; org_agent_hidden = true; org_sees_600 = false   (C3)
--   org_none_vehicles = 0        (an organisation without Transportation)
--   day_by = "Probe Guide"; day_tomorrow = "booked"; last_by = "Probe Org"
--   no_source = "Write where the price is from, for example \"their price list\"."
--   guide_edit_admins = "Only the member who added this vehicle, or Eretz Israel Tours, can change it."
--   org_agent_stored = false     (an organisation's vehicle is never an agent price)
--   review_names_vehicle = true
--   emails_in_output = 0
--   wineries_off_sites, wineries_off_food, wineries_off_none: 0, (the live count), 0
--   wineries_on_sites, wineries_on_food, wineries_on_none: (the live count), (the live count), 0
--   orgs_gaining_wineries = how many approved organisations see sites but not restaurants
--   tables_open = false; helpers_callable = false; calls_granted = 6
do $probe$
declare ta text := 'probe-admin-' || md5(random()::text) || md5(random()::text);
  tg text := 'probe-guide-' || md5(random()::text) || md5(random()::text);
  t1 text := 'probe-org1-' || md5(random()::text) || md5(random()::text);
  t2 text := 'probe-org2-' || md5(random()::text) || md5(random()::text);
  t3 text := 'probe-org3-' || md5(random()::text) || md5(random()::text);
  r jsonb := '{}'::jsonb; x jsonb; err text; cat text; vc text; vh text; vp text; v1 uuid; v2 uuid; v3 uuid; out text := '';
  base jsonb;
begin
  cat := case when (select pg_get_constraintdef(oid) from pg_constraint where conname = 'vendors_category_check') like '%Vehicle Rental%' then 'Vehicle Rental' else 'Transport' end;
  r := r || jsonb_build_object('category_on_list', cat = 'Vehicle Rental');
  insert into public.members (name, email, token_hash, status, is_admin, role) values ('Probe Admin', 'probe-admin@probe.invalid', public._hash(ta), 'approved', true, '');
  insert into public.members (name, email, token_hash, status, role) values ('Probe Guide', 'probe-guide@probe.invalid', public._hash(tg), 'approved', 'Licensed tour guide');
  insert into public.members (name, email, token_hash, status, role, member_type, sections, org) values
    ('Probe Org', 'probe-org1@probe.invalid', public._hash(t1), 'approved', '', 'limited', 'transport,sites', 'Probe Org'),
    ('Probe Org Food', 'probe-org2@probe.invalid', public._hash(t2), 'approved', '', 'limited', 'food', 'Probe Org Food'),
    ('Probe Org None', 'probe-org3@probe.invalid', public._hash(t3), 'approved', '', 'limited', 'hotels', 'Probe Org None');
  perform set_config('app.admin', 'on', true); perform set_config('app.editor', 'probe-admin@probe.invalid', true);
  insert into public.vendors (name, category, also_categories) values ('Probe rentals', cat, case when cat = 'Transport' then 'Vehicle Rental' else '' end) returning id into vc;
  insert into public.vendors (name, category, also_categories, hidden) values ('Probe rentals hidden', cat, case when cat = 'Transport' then 'Vehicle Rental' else '' end, true) returning id into vh;
  insert into public.vendors (name, category, also_categories) values ('Probe rentals pending', cat, case when cat = 'Transport' then 'Vehicle Rental' else '' end) returning id into vp;
  update public.vendors set review_status = 'pending' where id = vp;
  perform set_config('app.admin', 'off', true);
  base := jsonb_build_object('vendor_id', vc, 'licence_type', 'eshkol', 'make_model', 'Probe car', 'year', '2022', 'passenger_seats', '7',
    'cost_per_day', '850', 'vat', 'plus_vat', 'km_included_per_day', '200', 'cost_per_extra_km', '1.80', 'price_source', 'Probe list', 'price_checked_on', to_char(public._il_today(), 'YYYY-MM-DD'));
  -- closed (as live: rentals_for not set)
  update public.app_settings set value = 'admin' where key in ('rentals_for', 'wineries_for');
  v1 := (public.rental_vehicle_save(ta, base)::jsonb)->>'id';
  v2 := (public.rental_vehicle_save(ta, base || '{"make_model":"Probe agent car","cost_per_day":"600","is_agent":true}'::jsonb)::jsonb)->>'id';
  perform public.rental_vehicle_save(ta, base || jsonb_build_object('vendor_id', vh, 'make_model', 'Probe hidden car'));
  v3 := (public.rental_vehicle_save(ta, base || jsonb_build_object('vendor_id', vp, 'make_model', 'Probe pending car'))::jsonb)->>'id';
  r := r || jsonb_build_object('closed_guide_vehicles', json_array_length(public.rentals_list(tg)));
  begin perform public.rental_vehicle_save(tg, base); exception when others then r := r || jsonb_build_object('closed_guide_save', sqlerrm); end;
  r := r || jsonb_build_object('closed_guide_sees_company', exists (select 1 from json_array_elements(public.vendors_list(tg)) e where e->>'id' = vc));
  r := r || jsonb_build_object('wineries_off_sites', (select count(*) from json_array_elements(public.vendors_list(t1)) e where e->>'category' = 'Winery'),
    'wineries_off_food', (select count(*) from json_array_elements(public.vendors_list(t2)) e where e->>'category' = 'Winery'),
    'wineries_off_none', (select count(*) from json_array_elements(public.vendors_list(t3)) e where e->>'category' = 'Winery'));
  -- open
  insert into public.app_settings (key, value) values ('rentals_for', 'all'), ('wineries_for', 'all') on conflict (key) do update set value = excluded.value;
  x := public.rentals_list(tg)::jsonb; out := out || x::text;
  r := r || jsonb_build_object('guide_vehicles', jsonb_array_length(x),
    'guide_agent_price', (select e->'cost_per_day' from jsonb_array_elements(x) e where (e->>'id')::uuid = v2));
  begin perform public.rental_vehicle(tg, (select id from public.rental_vehicles where vendor_id = vh)); exception when others then r := r || jsonb_build_object('guide_hidden_open', sqlerrm); end;
  begin perform public.rental_vehicle(tg, v3); exception when others then r := r || jsonb_build_object('guide_pending_open', sqlerrm); end;
  x := public.rentals_list(t1)::jsonb; out := out || x::text || public.rental_vehicle(t1, v2)::text;
  r := r || jsonb_build_object('org_vehicles', jsonb_array_length(x),
    'org_retail_price', (select e->'cost_per_day' from jsonb_array_elements(x) e where (e->>'id')::uuid = v1),
    'org_agent_price', (select e->'cost_per_day' from jsonb_array_elements(x) e where (e->>'id')::uuid = v2),
    'org_agent_hidden', (select e->'price_hidden' from jsonb_array_elements(x) e where (e->>'id')::uuid = v2),
    'org_sees_600', (x::text || public.rental_vehicle(t1, v2)::text) like '%600%',
    'org_none_vehicles', json_array_length(public.rentals_list(t3)));
  x := public.rental_day_set(tg, v1, public._il_today() + 1, 'booked')::jsonb; out := out || x::text;
  r := r || jsonb_build_object('day_by', x->'last'->>'by',
    'day_tomorrow', (select e->>'tomorrow' from json_array_elements(public.rentals_list(tg)) e where (e->>'id')::uuid = v1));
  perform public.rental_day_set(t1, v1, public._il_today() + 3, 'free');
  x := public.rental_vehicle(tg, v1)::jsonb; out := out || x::text;
  r := r || jsonb_build_object('last_by', x->'last'->>'by');
  begin perform public.rental_vehicle_save(ta, base || '{"price_source":""}'::jsonb); exception when others then r := r || jsonb_build_object('no_source', sqlerrm); end;
  begin perform public.rental_vehicle_save(tg, base || jsonb_build_object('id', v1)); exception when others then r := r || jsonb_build_object('guide_edit_admins', sqlerrm); end;
  x := public.rental_vehicle_save(t1, base || '{"make_model":"Probe org car","is_agent":true}'::jsonb)::jsonb;
  r := r || jsonb_build_object('org_agent_stored', (select is_agent from public.rental_vehicles where id = (x->>'id')::uuid));
  perform public.rental_review_post(tg, v1, 'Probe review.', '5', false);
  r := r || jsonb_build_object('review_names_vehicle', exists (select 1 from json_array_elements((public.vendor_detail(ta, vc)::json)->'notes') e where e->>'body' = 'Probe review.' and (e->>'vehicle_id')::uuid = v1));
  r := r || jsonb_build_object('emails_in_output', (select count(*) from regexp_matches(out, '@', 'g')));
  r := r || jsonb_build_object('wineries_on_sites', (select count(*) from json_array_elements(public.vendors_list(t1)) e where e->>'category' = 'Winery'),
    'wineries_on_food', (select count(*) from json_array_elements(public.vendors_list(t2)) e where e->>'category' = 'Winery'),
    'wineries_on_none', (select count(*) from json_array_elements(public.vendors_list(t3)) e where e->>'category' = 'Winery'),
    'wineries_visible_live', (select count(*) from public.vendors where category = 'Winery' and not hidden));
  r := r || jsonb_build_object('orgs_gaining_wineries', (select count(*) from public.members where status = 'approved' and member_type = 'limited' and email not like 'probe-%'
    and 'sites' = any (string_to_array(sections, ',')) and not 'food' = any (string_to_array(sections, ','))));
  r := r || jsonb_build_object('tables_open', (select bool_or(coalesce(c.relacl::text, '') ~ '(^|[{,])(anon|authenticated)?=' or not c.relrowsecurity) from pg_class c
      where c.relnamespace = 'public'::regnamespace and c.relname in ('rental_vehicles','rental_days')),
    'helpers_callable', (select bool_or(has_function_privilege(ro, p.oid, 'execute')) from pg_proc p, unnest(array['anon','authenticated','public']) ro
      where p.pronamespace = 'public'::regnamespace and p.proname = any (array['_il_today','_is_rental','_rental_json','_rental_vendor_ok','_rentals_on','_wineries_on','_can_see','_section_of'])),
    'calls_granted', (select count(*) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('rentals_list','rental_vehicle','rental_vehicle_save','rental_vehicle_archive','rental_day_set','rental_review_post') and has_function_privilege('anon', p.oid, 'execute')));
  raise exception 'PROBE %', r::text;
end $probe$;
