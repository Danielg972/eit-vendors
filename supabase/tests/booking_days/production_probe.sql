-- Booking sheets, separate days inside a period (D-21): probe for the live database. Changes nothing.
-- It adds a temporary guide and a temporary organisation, saves a booking sheet with separate days as each of them on a
-- visible transport supplier, reads them back the way the app and the company's page do, and ends by raising an error
-- that carries the results, so everything it did is rolled back. Read the JSON after "PROBE".
-- Run it as one statement (Supabase SQL editor, or the connector's execute_sql).
--
-- What must come back:
--   full_days, limited_days = the five days; full_period = 2026-11-18..2026-11-26
--   company_days = the five days; company_private_keys = []   (the company's page gets no private field)
--   all_days_kept_as_list = ""            junk_cleaned = 2026-11-18,2026-11-22,2026-11-26
--   limited_sees_sheets = 1, limited_all_mine = true          (an organisation sees only its own sheet)
--   full_sees_sheets = 1, full_all_mine = true                 (a guide does not see the organisation's sheet)
--   helper_from_outside = false           plain_content_has_days_key = false
do $probe$
declare tl text := 'probe-limited-' || md5(random()::text) || md5(random()::text);
  tf text := 'probe-full-' || md5(random()::text) || md5(random()::text);
  r jsonb := '{}'::jsonb; vid text; a jsonb; b jsonb; c jsonb; o jsonb; l jsonb;
  five text := '2026-11-18,2026-11-19,2026-11-22,2026-11-24,2026-11-26';
  base jsonb := '{"date_from":"2026-11-18","date_to":"2026-11-27","service":"bus","booker_name":"Probe","booker_phone":"050-000-0000","pax":"24","client_ref":"probe client","private_note":"probe private"}'::jsonb;
begin
  insert into public.members (name,email,role,token_hash,status,member_type,sections,org,credentials)
  values ('Probe Org','probe-limited@invalid.test','Other',public._hash(tl),'approved','limited','transport,guides,hotels,sites,food','Probe Yeshiva','probe probe probe probe probe');
  insert into public.members (name,email,role,token_hash,status) values ('Probe Guide','probe-full@invalid.test','Licensed tour guide',public._hash(tf),'approved');
  select v.id into vid from public.vendors v where not v.hidden and v.category = 'Transport' order by v.id limit 1;
  if vid is null then raise exception 'PROBE %', '{"error":"no visible transport supplier"}'; end if;

  a := public.booking_save(tf, vid, base || jsonb_build_object('days', five))::jsonb;
  r := r || jsonb_build_object('full_days', a->>'days', 'full_period', (a->>'date_from') || '..' || (a->>'date_to'));
  o := public.booking_open(a->>'key')::jsonb;
  r := r || jsonb_build_object('company_days', o->>'days',
    'company_private_keys', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(o) k where k in ('client_ref','private_note','owner','owner_name','vendor_id','id','key','quote_id')));
  b := public.booking_save(tf, vid, base || jsonb_build_object('id', a->>'id', 'days', '2026-11-18,2026-11-19,2026-11-20,2026-11-21,2026-11-22,2026-11-23,2026-11-24,2026-11-25,2026-11-26,2026-11-27'))::jsonb;
  r := r || jsonb_build_object('all_days_kept_as_list', b->>'days',
    'plain_content_has_days_key', (select public._booking_content(x) ? 'days' from public.bookings x where x.id = (a->>'id')::uuid));
  b := public.booking_save(tf, vid, base || jsonb_build_object('id', a->>'id', 'days', '2026-11-26,2026-11-18,2026-11-18,2026-12-25,2026-02-30,junk,2026-11-22'))::jsonb;
  r := r || jsonb_build_object('junk_cleaned', b->>'days');

  c := public.booking_save(tl, vid, base || jsonb_build_object('days', five))::jsonb;
  r := r || jsonb_build_object('limited_days', c->>'days');
  l := public.bookings_list(tl)::jsonb;
  r := r || jsonb_build_object('limited_sees_sheets', jsonb_array_length(l), 'limited_all_mine', (select coalesce(bool_and((e->>'mine')::boolean), false) from jsonb_array_elements(l) e));
  l := public.bookings_list(tf)::jsonb;
  r := r || jsonb_build_object('full_sees_sheets', jsonb_array_length(l), 'full_all_mine', (select coalesce(bool_and((e->>'mine')::boolean), false) from jsonb_array_elements(l) e));
  r := r || jsonb_build_object('helper_from_outside', has_function_privilege('anon', 'public._booking_days_clean(text,text,text)', 'execute') or has_function_privilege('authenticated', 'public._booking_days_clean(text,text,text)', 'execute'));
  raise exception 'PROBE %', r::text;
end $probe$;
