-- Booking sheets, each day's own times (D-24) and terms left off (D-25): probe for the live database. Changes nothing.
-- It adds a temporary guide and a temporary organisation, saves booking sheets as each of them on a visible transport
-- supplier, answers one the way the company's page does, and ends by raising an error that carries the results, so
-- everything it did is rolled back. Read the JSON after "PROBE".
-- Run it as one statement (Supabase SQL editor, or the connector's execute_sql).
--
-- What must come back:
--   plan_kept = true; company_plan = true          (the times reach the company's page as saved)
--   company_private_keys = []                      (the company's page gets no private field)
--   off_list = "km,tip"; proposed_has_off = false  (terms left off are gone from what the guide expects)
--   company_terms_has_off = false; company_overtime = "200"   (the company cannot add them back; the rest is kept)
--   after_off_change_status = "waiting"            (one more term left off after acceptance: back to the company)
--   limited_plan_kept = true; limited_sees_sheets = 1; limited_all_mine = true
--   full_all_mine = true                           (a guide does not see the organisation's sheet)
--   helpers_from_outside = false                   old_sheet_content_keys has no day_plan and no terms_off
do $probe$
declare tl text := 'probe-limited-' || md5(random()::text) || md5(random()::text);
  tf text := 'probe-full-' || md5(random()::text) || md5(random()::text);
  r jsonb := '{}'::jsonb; vid text; a jsonb; c jsonb; o jsonb; l jsonb; x jsonb;
  five text := '2026-11-18,2026-11-19,2026-11-22,2026-11-24,2026-11-26';
  plan jsonb := '{"2026-11-18":{"start":"08:30","end":"18:00","route":"Dead Sea"},"2026-11-19":{"start":"10:30"},"2026-11-24":{"start":"09:00","end":"18:00"}}'::jsonb;
  full_terms jsonb := '{"price":"3000","currency":"ILS","vat":"not_applicable","hours_incl":"10","km_incl":"250","overtime":"200","extra_km":"5","tolls":"incl","parking":"incl","tip":"customary","tip_amt":"100","cancel":"48 hours"}'::jsonb;
  base jsonb := '{"date_from":"2026-11-18","date_to":"2026-11-27","service":"bus","booker_name":"Probe","booker_phone":"050-000-0000","pax":"24","client_ref":"probe client","private_note":"probe private"}'::jsonb;
begin
  insert into public.members (name,email,role,token_hash,status,member_type,sections,org,credentials)
  values ('Probe Org','probe-limited@invalid.test','Other',public._hash(tl),'approved','limited','transport,guides,hotels,sites,food','Probe Yeshiva','probe probe probe probe probe');
  insert into public.members (name,email,role,token_hash,status) values ('Probe Guide','probe-full@invalid.test','Licensed tour guide',public._hash(tf),'approved');
  select v.id into vid from public.vendors v where not v.hidden and v.category = 'Transport' order by v.id limit 1;
  if vid is null then raise exception 'PROBE %', '{"error":"no visible transport supplier"}'; end if;

  x := public.booking_save(tf, vid, base)::jsonb;   -- a plain sheet, as before the change
  r := r || jsonb_build_object('old_sheet_content_keys', (select jsonb_agg(k order by k) from jsonb_object_keys((select public._booking_content(b) from public.bookings b where b.id = (x->>'id')::uuid)) k));

  a := public.booking_save(tf, vid, base || jsonb_build_object('booker_name','Probe 2','days', five, 'day_plan', plan, 'proposed', full_terms, 'terms_off', 'tip,km'))::jsonb;
  r := r || jsonb_build_object('plan_kept', a->'day_plan' = plan, 'off_list', a->>'terms_off', 'proposed_has_off', (a->'proposed') ?| array['tip','tip_amt','km_incl','extra_km']);
  o := public.booking_open(a->>'key')::jsonb;
  r := r || jsonb_build_object('company_plan', o->'day_plan' = plan,
    'company_private_keys', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(o) k where k in ('client_ref','private_note','owner','owner_name','vendor_id','id','key','quote_id')));
  o := public.booking_answer(a->>'key', full_terms, 'Probe Co')::jsonb;
  r := r || jsonb_build_object('company_terms_has_off', (o->'terms') ?| array['tip','tip_amt','km_incl','extra_km'], 'company_overtime', o->'terms'->>'overtime', 'answered_status', o->>'status');
  x := public.booking_save(tf, vid, base || jsonb_build_object('id', a->>'id', 'booker_name','Probe 2','days', five, 'day_plan', plan, 'proposed', full_terms, 'terms_off', 'tip,km,parking'))::jsonb;
  r := r || jsonb_build_object('after_off_change_status', x->>'status', 'after_off_change_has_parking', (x->'terms') ? 'parking');

  c := public.booking_save(tl, vid, base || jsonb_build_object('days', five, 'day_plan', plan))::jsonb;
  l := public.bookings_list(tl)::jsonb;
  r := r || jsonb_build_object('limited_plan_kept', c->'day_plan' = plan, 'limited_sees_sheets', jsonb_array_length(l), 'limited_all_mine', (select coalesce(bool_and((e->>'mine')::boolean), false) from jsonb_array_elements(l) e));
  l := public.bookings_list(tf)::jsonb;
  r := r || jsonb_build_object('full_sees_sheets', jsonb_array_length(l), 'full_all_mine', (select coalesce(bool_and((e->>'mine')::boolean), false) from jsonb_array_elements(l) e));
  r := r || jsonb_build_object('helpers_from_outside', (select bool_or(has_function_privilege(u, f, 'execute')) from unnest(array['anon','authenticated']) u, unnest(array['public._booking_plan_clean(jsonb,text,text,text)','public._terms_off_clean(text)','public._terms_on(jsonb,text)']) f));
  raise exception 'PROBE %', r::text;
end $probe$;
