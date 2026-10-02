-- Booking sheets, second step (2 Oct 2026): both sides accept; changes come back for approval; a cancellation policy box.
-- See docs/DECISIONS.md D-5 (owner, 15:20). Run after 2026-10-02c_bookings.sql.
-- Paste the whole file into the Supabase SQL editor for project wjuqtjlrtcywjaspjpwu and run it once. Safe to run twice.
--
-- How acceptance works: whoever sends a version has accepted it. The company's answer is its acceptance; the guide then
-- accepts, and the sheet locks. If either side changes anything before that, the other side's acceptance is cleared and
-- it must accept again. Each side's last-seen version is kept (seen_guide, seen_company) so the pages can mark in red
-- what the other side changed since.
-- The last statement also opens booking sheets to all approved colleagues (owner, 15:16: "a live version for everybody
-- is fine right now").

alter table public.bookings
  add column if not exists guide_ok_at timestamp with time zone,
  add column if not exists company_ok_at timestamp with time zone,
  add column if not exists company_ok_via text default ''::text not null,
  add column if not exists seen_guide jsonb,
  add column if not exists seen_company jsonb;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'bookings_company_ok_via_check') then
    alter table public.bookings add constraint bookings_company_ok_via_check check (company_ok_via = any (array[''::text, 'link'::text, 'guide'::text]));
  end if;
end $$;
-- Sheets made before this change: carry over who had already agreed.
update public.bookings set company_ok_at = answered_at, company_ok_via = case when terms_by = 'guide' then 'guide' else 'link' end
  where company_ok_at is null and status in ('answered','confirmed') and coalesce(terms->>'price','') <> '';
update public.bookings set guide_ok_at = coalesce(confirmed_at, updated_at) where guide_ok_at is null and status in ('waiting','confirmed');

-- Cancellation policy: room for a pasted policy (1,500 characters instead of 200).
create or replace function public._terms_clean(p jsonb)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select jsonb_strip_nulls(jsonb_build_object(
    'price', case when t->>'price' ~ '^\d{1,7}(\.\d{1,2})?$' then t->>'price' end,
    'currency', case when t->>'currency' in ('ILS','USD','EUR') then t->>'currency' end,
    'vat', case when t->>'vat' in ('including_vat','plus_vat','not_applicable') then t->>'vat' end,
    'hours_incl', case when t->>'hours_incl' ~ '^\d{1,2}(\.\d)?$' then t->>'hours_incl' end,
    'km_incl', case when t->>'km_incl' ~ '^\d{1,4}$' then t->>'km_incl' end,
    'hours_from', case when t->>'hours_from' in ('pickup','depot') then t->>'hours_from' end,
    'overtime', case when t->>'overtime' ~ '^\d{1,7}(\.\d{1,2})?$' then t->>'overtime' end,
    'extra_km', case when t->>'extra_km' ~ '^\d{1,7}(\.\d{1,2})?$' then t->>'extra_km' end,
    'tolls', case when t->>'tolls' in ('incl','extra') then t->>'tolls' end,
    'tolls_note', nullif(left(trim(coalesce(t->>'tolls_note','')),80),''),
    'parking', case when t->>'parking' in ('incl','extra') then t->>'parking' end,
    'tip', case when t->>'tip' in ('none','customary') then t->>'tip' end,
    'tip_amt', case when t->>'tip_amt' ~ '^\d{1,7}(\.\d{1,2})?$' then t->>'tip_amt' end,
    'extras', nullif(left(trim(coalesce(t->>'extras','')),300),''),
    'cancel', nullif(left(trim(coalesce(t->>'cancel','')),1500),''),
    'payment', nullif(left(trim(coalesce(t->>'payment','')),200),''),
    'note', nullif(left(trim(coalesce(t->>'note','')),1500),'')))
  from (select case when jsonb_typeof(p) = 'object' then p else '{}'::jsonb end as t) x
$function$;
revoke all on function public._terms_clean(jsonb) from public, anon, authenticated;

-- Everything both sides agree on: the job and the terms. Used to tell whether a sheet changed, and kept as "last seen".
create or replace function public._booking_content(b public.bookings)
 returns jsonb language sql stable set search_path to ''
as $function$
  select jsonb_build_object('date_from',b.date_from,'date_to',b.date_to,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'terms',b.terms)
$function$;
revoke all on function public._booking_content(public.bookings) from public, anon, authenticated;

create or replace function public._booking_json(b public.bookings)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',b.id,'vendor_id',b.vendor_id,'vendor_name',(select v.name from public.vendors v where v.id = b.vendor_id),
    'key',b.link_key,'status',b.status,'client_ref',b.client_ref,'booker_name',b.booker_name,'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'private_note',b.private_note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,
    'answered_by',b.answered_by,'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,'shared',b.shared,'in_tracker',b.quote_id is not null,
    'guide_ok_at',b.guide_ok_at,'company_ok_at',b.company_ok_at,'company_ok_via',b.company_ok_via,'seen',b.seen_guide,
    'mine', b.owner = coalesce(current_setting('app.editor', true),''),
    'owner_name',b.owner_name,
    'owner_role',(select mm.role from public.members mm where mm.email = b.owner limit 1),
    'owner_admin',(select mm.is_admin from public.members mm where mm.email = b.owner limit 1),
    'created_at',b.created_at,'updated_at',b.updated_at)
$function$;
revoke all on function public._booking_json(public.bookings) from public, anon, authenticated;

create or replace function public._booking_to_quote(b public.bookings)
 returns uuid language plpgsql security definer set search_path to ''
as $function$
declare qid uuid := b.quote_id; t jsonb := b.terms; oid uuid; days int := 1; lab text; fees jsonb := '{}'::jsonb; cond text;
begin
  if coalesce(t->>'price','') = '' then return null; end if;
  if qid is not null and not exists (select 1 from public.quotes where id = qid) then qid := null; end if;
  if qid is null then
    insert into public.quotes (vendor_id, owner, owner_name) values (b.vendor_id, b.owner, b.owner_name) returning id into qid;
  end if;
  begin
    if b.date_from <> '' and b.date_to <> '' and b.date_to >= b.date_from then days := (b.date_to::date - b.date_from::date) + 1; end if;
  exception when others then days := 1; end;
  lab := case b.service when 'bus' then 'Bus' when 'midibus' then 'Midibus' when 'van20' then 'Van' when 'van16' then 'Van' when 'van10' then 'Van'
    when 'van8' then 'Van' when 'car' then 'Car' when 'jeep_vehicle' then 'Jeep / 4x4' when 'transfer' then 'Transfer' else 'Vehicle' end;
  if t ? 'overtime' then fees := fees || jsonb_build_object('overtime', jsonb_build_object('s','extra','amt',t->>'overtime')); end if;
  if t ? 'extra_km' then fees := fees || jsonb_build_object('extra_km', jsonb_build_object('s','extra','amt',t->>'extra_km')); end if;
  if t ? 'tolls' then fees := fees || jsonb_build_object('tolls', jsonb_strip_nulls(jsonb_build_object('s',t->>'tolls','note',t->>'tolls_note'))); end if;
  if t ? 'parking' then fees := fees || jsonb_build_object('parking', jsonb_build_object('s',t->>'parking')); end if;
  cond := concat_ws(E'\n',
    case t->>'hours_from' when 'pickup' then 'Hours counted from the pick-up.' when 'depot' then 'Hours counted from leaving the depot.' end,
    case t->>'tip' when 'none' then 'Driver tip: not expected.' when 'customary' then 'Driver tip: customary' || coalesce(', about ' || (t->>'tip_amt') || ' a day', '') || '.' end,
    case when t ? 'extras' then 'Other extras: ' || (t->>'extras') end,
    case when t ? 'cancel' then 'Cancellation policy: ' || (t->>'cancel') else 'Cancellation policy: none given.' end,
    case when t ? 'payment' then 'Payment: ' || (t->>'payment') end,
    'From a booking sheet accepted by both sides.');
  update public.quotes set title = b.client_ref, date_from = b.date_from, date_to = b.date_to, pax = b.pax, units = '1 vehicle',
    received_on = to_char(coalesce(b.answered_at, now()), 'YYYY-MM-DD'), status = 'Booked', currency = coalesce(t->>'currency','ILS'),
    vat = coalesce(t->>'vat',''), conditions = left(cond, 3000), shared = b.shared, updated_at = now()
  where id = qid;
  delete from public.quote_options where quote_id = qid;
  insert into public.quote_options (quote_id, name, sort, service, seats, hours_incl, km_incl, fees)
  values (qid, case when b.seats <> '' then b.seats || '-seat ' || lower(lab) else lab end, 0, b.service, b.seats,
    coalesce(t->>'hours_incl',''), coalesce(t->>'km_incl',''), public._fees_clean(fees))
  returning id into oid;
  insert into public.quote_lines (option_id, label, kind, price, unit, qty, times, sort)
  values (oid, lab || ' with driver', 'Base', t->>'price', 'per vehicle per day', '1', days::text, 0);
  return qid;
end $function$;
revoke all on function public._booking_to_quote(public.bookings) from public, anon, authenticated;

-- The guide saves. Saving a version is accepting it (guide_ok_at). If the sheet's content changed after the company
-- answered, the company's acceptance is cleared and it has to accept again (status back to 'waiting').
-- p_booking "terms": the guide writes the terms himself. With "company_agreed": true he is typing in what the company
-- told him by phone or WhatsApp (its acceptance is recorded as given through the guide); without it he is proposing
-- different terms, which go back to the company for approval.
create or replace function public.booking_save(p_token text, p_vendor text, p_booking jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; bid uuid := nullif(p_booking->>'id','')::uuid; b public.bookings; prev public.bookings; agreed boolean;
begin
  m := public._auth(p_token);
  if not public._bookings_on(m) then raise exception 'Booking sheets are not open yet.' using errcode = '42501'; end if;
  perform public._visible(p_vendor, m.is_admin);
  if not exists (select 1 from public.vendors where id = p_vendor) then raise exception 'That supplier no longer exists.'; end if;
  if bid is not null then
    select * into prev from public.bookings where id = bid and vendor_id = p_vendor and (owner = m.email or m.is_admin);
    if prev.id is null then raise exception 'Only the person who made this booking sheet, or Eretz Israel Tours, can change it.'; end if;
    if prev.status in ('confirmed','cancelled') then raise exception 'This booking sheet is closed. Reopen it to change it.'; end if;
  else
    if (select count(*) from public.bookings where owner = m.email and created_at > now() - interval '1 day') >= 100 then
      raise exception 'Too many booking sheets in one day. Try again tomorrow.'; end if;
    insert into public.bookings (vendor_id, owner, owner_name, link_key, guide_ok_at) values (p_vendor, m.email, m.name, public._new_token(), now()) returning id into bid;
  end if;
  update public.bookings set
    client_ref = left(coalesce(p_booking->>'client_ref',''),160),
    booker_name = left(trim(coalesce(p_booking->>'booker_name','')),80),
    booker_phone = left(trim(coalesce(p_booking->>'booker_phone','')),40),
    date_from = case when coalesce(p_booking->>'date_from','') ~ '^\d{4}-\d{2}-\d{2}$' then p_booking->>'date_from' else '' end,
    date_to = case when coalesce(p_booking->>'date_to','') ~ '^\d{4}-\d{2}-\d{2}$' then p_booking->>'date_to' else '' end,
    pax = left(coalesce(p_booking->>'pax',''),20),
    service = case when coalesce(p_booking->>'service','') = any (array['bus','midibus','van20','van16','van10','van8','car','jeep_vehicle','transfer']) then p_booking->>'service' else '' end,
    seats = case when coalesce(p_booking->>'seats','') ~ '^\d{1,3}$' then p_booking->>'seats' else '' end,
    tourists = coalesce((p_booking->>'tourists')::boolean, true),
    pickup_time = left(coalesce(p_booking->>'pickup_time',''),20), pickup_place = left(coalesce(p_booking->>'pickup_place',''),160),
    route = left(coalesce(p_booking->>'route',''),1500),
    dropoff_time = left(coalesce(p_booking->>'dropoff_time',''),20), dropoff_place = left(coalesce(p_booking->>'dropoff_place',''),160),
    note = left(coalesce(p_booking->>'note',''),1500), private_note = left(coalesce(p_booking->>'private_note',''),3000),
    proposed = public._terms_clean(p_booking->'proposed'),
    shared = coalesce((p_booking->>'shared')::boolean, true), updated_at = now()
  where id = bid returning * into b;
  if b.booker_name = '' then update public.bookings set booker_name = m.name where id = bid returning * into b; end if;
  if jsonb_typeof(p_booking->'terms') = 'object' then
    if coalesce(public._terms_clean(p_booking->'terms')->>'price','') = '' then raise exception 'Add the price.'; end if;
    agreed := coalesce((p_booking->>'company_agreed')::boolean, false);
    update public.bookings set terms = public._terms_clean(p_booking->'terms'), terms_by = 'guide',
      answered_by = case when agreed then left(trim(coalesce(p_booking->>'answered_by','')),80) else answered_by end,
      answered_at = case when agreed then now() else answered_at end,
      company_ok_at = case when agreed then now() end, company_ok_via = case when agreed then 'guide' else '' end,
      status = case when agreed then 'answered' else 'waiting' end
    where id = bid returning * into b;
  elsif prev.id is not null and prev.status = 'answered' and public._booking_content(prev) is distinct from public._booking_content(b) then
    -- the job changed after the company accepted: its acceptance no longer stands
    update public.bookings set status = 'waiting', company_ok_at = null, company_ok_via = '' where id = bid returning * into b;
  end if;
  -- what the guide has now seen and stands behind
  update public.bookings set seen_guide = public._booking_content(b), guide_ok_at = case when b.status = 'waiting' then now() else guide_ok_at end
  where id = bid returning * into b;
  return public._booking_json(b);
end $function$;
revoke all on function public.booking_save(text,text,jsonb) from public; grant execute on function public.booking_save(text,text,jsonb) to anon, authenticated;

-- confirmed: the guide accepts what the company accepted; the sheet locks and feeds the Quotes tab.
-- cancelled: the link stops taking answers. open: unlock it again.
create or replace function public.booking_set_status(p_token text, p_id uuid, p_status text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; b public.bookings; qid uuid;
begin
  m := public._auth(p_token);
  if not public._bookings_on(m) then raise exception 'Booking sheets are not open yet.' using errcode = '42501'; end if;
  select * into b from public.bookings where id = p_id and (owner = m.email or m.is_admin);
  if b.id is null then raise exception 'Only the person who made this booking sheet, or Eretz Israel Tours, can change it.'; end if;
  if p_status = 'confirmed' then
    if b.status <> 'answered' or coalesce(b.terms->>'price','') = '' or b.company_ok_at is null then raise exception 'The company has not accepted this version yet.'; end if;
    update public.bookings set status = 'confirmed', confirmed_at = now(), guide_ok_at = now(), seen_guide = public._booking_content(b), updated_at = now() where id = p_id returning * into b;
    qid := public._booking_to_quote(b);
    update public.bookings set quote_id = qid where id = p_id returning * into b;
  elsif p_status = 'cancelled' then
    if b.quote_id is not null then update public.quotes set status = 'Received', updated_at = now() where id = b.quote_id and status = 'Booked'; end if;
    update public.bookings set status = 'cancelled', updated_at = now() where id = p_id returning * into b;
  elsif p_status = 'open' then
    if b.quote_id is not null then delete from public.quotes where id = b.quote_id; end if;
    update public.bookings set status = case when coalesce(terms->>'price','') <> '' and company_ok_at is not null then 'answered' else 'waiting' end,
      guide_ok_at = case when coalesce(terms->>'price','') <> '' and company_ok_at is not null then null else now() end,
      confirmed_at = null, quote_id = null, updated_at = now() where id = p_id returning * into b;
  else
    raise exception 'Unknown status.';
  end if;
  return public._booking_json(b);
end $function$;
revoke all on function public.booking_set_status(text,uuid,text) from public; grant execute on function public.booking_set_status(text,uuid,text) to anon, authenticated;

-- ===== The company's side (link key only) =====
create or replace function public.booking_open(p_key text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare b public.bookings;
begin
  if coalesce(length(p_key),0) < 32 then raise exception 'This link is not active.' using errcode = '28000'; end if;
  select * into b from public.bookings where link_key = p_key;
  if b.id is null then raise exception 'This link is not active.' using errcode = '28000'; end if;
  return json_build_object('status',b.status,
    'company',(select v.name from public.vendors v where v.id = b.vendor_id),
    'booker_name',b.booker_name,'booker_role',(select mm.role from public.members mm where mm.email = b.owner limit 1),'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,'answered_by',b.answered_by,
    'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,
    'guide_ok_at',b.guide_ok_at,'company_ok_at',b.company_ok_at,'company_ok_via',b.company_ok_via,'seen',b.seen_company);
end $function$;
revoke all on function public.booking_open(text) from public; grant execute on function public.booking_open(text) to anon, authenticated;

-- The company accepts the sheet as it stands (after the guide changed the job or proposed other terms).
-- If the guide's acceptance of this same version stands, both sides have now accepted: the sheet locks.
create or replace function public.booking_accept(p_key text, p_name text default ''::text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare b public.bookings; qid uuid;
begin
  if coalesce(length(p_key),0) < 32 then raise exception 'This link is not active.' using errcode = '28000'; end if;
  select * into b from public.bookings where link_key = p_key for update;
  if b.id is null then raise exception 'This link is not active.' using errcode = '28000'; end if;
  if b.status = 'cancelled' then raise exception 'This booking was cancelled.'; end if;
  if b.status in ('confirmed','answered') then return public.booking_open(p_key); end if;
  if coalesce(b.terms->>'price','') = '' then raise exception 'Fill in the price.'; end if;
  update public.bookings set company_ok_at = now(), company_ok_via = 'link', seen_company = public._booking_content(b),
    answered_by = case when trim(coalesce(p_name,'')) <> '' then left(trim(p_name),80) else answered_by end, answered_at = now(),
    status = case when guide_ok_at is not null then 'confirmed' else 'answered' end,
    confirmed_at = case when guide_ok_at is not null then now() end, updated_at = now()
  where id = b.id returning * into b;
  if b.status = 'confirmed' then
    qid := public._booking_to_quote(b);
    update public.bookings set quote_id = qid where id = b.id;
  end if;
  return public.booking_open(p_key);
end $function$;
revoke all on function public.booking_accept(text,text) from public; grant execute on function public.booking_accept(text,text) to anon, authenticated;

-- The company sends its terms. Sending them is accepting them. The guide's acceptance is cleared: he has to accept
-- what the company wrote. Sending back exactly what the guide proposed counts as accepting it.
create or replace function public.booking_answer(p_key text, p_terms jsonb, p_name text default ''::text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare b public.bookings; t jsonb := public._terms_clean(p_terms);
begin
  if coalesce(length(p_key),0) < 32 then raise exception 'This link is not active.' using errcode = '28000'; end if;
  select * into b from public.bookings where link_key = p_key for update;
  if b.id is null then raise exception 'This link is not active.' using errcode = '28000'; end if;
  if b.status = 'confirmed' then raise exception 'This booking is already confirmed. To change it, contact the person who sent it.'; end if;
  if b.status = 'cancelled' then raise exception 'This booking was cancelled.'; end if;
  if b.answers >= 30 then raise exception 'This sheet was changed too many times. Contact the person who sent it.'; end if;
  if coalesce(t->>'price','') = '' then raise exception 'Fill in the price.'; end if;
  if b.status = 'waiting' and b.guide_ok_at is not null and b.terms = t then return public.booking_accept(p_key, p_name); end if;
  -- when the company revises an earlier answer, the guide's page compares against that earlier answer
  update public.bookings set terms = t, terms_by = 'company', answered_by = left(trim(coalesce(p_name,'')),80), answered_at = now(),
    status = 'answered', company_ok_at = now(), company_ok_via = 'link', guide_ok_at = null, answers = answers + 1, updated_at = now(),
    seen_guide = case when coalesce(b.terms->>'price','') <> '' then jsonb_set(coalesce(seen_guide, public._booking_content(b)), '{terms}', b.terms) else seen_guide end
  where id = b.id returning * into b;
  update public.bookings set seen_company = public._booking_content(b) where id = b.id;
  return public.booking_open(p_key);
end $function$;
revoke all on function public.booking_answer(text,jsonb,text) from public; grant execute on function public.booking_answer(text,jsonb,text) to anon, authenticated;

-- Open booking sheets to all approved colleagues.
insert into public.app_settings (key, value) values ('bookings_for', 'all') on conflict (key) do update set value = excluded.value;
