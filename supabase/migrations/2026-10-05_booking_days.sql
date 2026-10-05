-- D-21 (5 Oct 2026): a booking sheet can ask for separate days inside a period, not only a first and a last date.
-- The owner, 5 Oct 2026, 11:07: "it only has full dates example nov 18 -27 what if i need only 5 dates during that
-- period? how do i delinieate days?" and at 11:12, asked whether to prepare the preview: "yes".
--
-- Adds one column, bookings.days: a comma list of the chosen days, '' = every day from the first date to the last
-- (so every booking sheet made before this stays exactly as it is). The chosen days go to the company's one-booking
-- page with the rest of the job, count as part of what both sides accept (a change comes back in red), and set the
-- number of days on the quote a confirmed sheet leaves in the Quotes tab.
--
-- One new column, one new internal helper, five functions replaced. No grant, no policy; no DELETE, no DROP.
-- Safe to run twice. NOT RUN ON PRODUCTION until the owner says to go live.

alter table public.bookings add column if not exists days text not null default '';
do $do$ begin
  if not exists (select 1 from pg_constraint where conname = 'bookings_days_check' and conrelid = 'public.bookings'::regclass) then
    alter table public.bookings add constraint bookings_days_check
      check (days = ''::text or (length(days) <= 700 and days ~ '^\d{4}-\d{2}-\d{2}(,\d{4}-\d{2}-\d{2})+$'::text));
  end if;
end $do$;

create or replace function public._booking_days_clean(p_days text, p_from text, p_to text)
 returns text language plpgsql stable set search_path to ''
as $function$
declare d text; picked text[] := '{}'; last_day text := coalesce(nullif(p_to,''), p_from); n int;
begin
  if coalesce(p_days,'') = '' or coalesce(p_from,'') = '' then return ''; end if;
  for d in select distinct x from unnest(string_to_array(left(p_days, 4000), ',')) x
           where x ~ '^\d{4}-\d{2}-\d{2}$' and x >= p_from and x <= last_day order by 1 limit 62 loop
    begin
      if to_char(d::date, 'YYYY-MM-DD') = d then picked := picked || d; end if;
    exception when others then null; end;
  end loop;
  n := coalesce(array_length(picked, 1), 0);
  if n < 2 then return ''; end if;
  if n = (picked[n]::date - picked[1]::date) + 1 then return ''; end if;
  return array_to_string(picked, ',');
end $function$;

create or replace function public._booking_json(b public.bookings)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',b.id,'vendor_id',b.vendor_id,'vendor_name',(select v.name from public.vendors v where v.id = b.vendor_id),
    'key',b.link_key,'status',b.status,'client_ref',b.client_ref,'booker_name',b.booker_name,'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'days',b.days,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
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
    if b.days <> '' then days := array_length(string_to_array(b.days, ','), 1);   -- D-21: separate days inside the period
    elsif b.date_from <> '' and b.date_to <> '' and b.date_to >= b.date_from then days := (b.date_to::date - b.date_from::date) + 1; end if;
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
    case when b.days <> '' then days::text || ' separate days between these dates.' end,
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
  -- D-21: separate days inside the period. A copy of the app from before D-21 sends no "days": they are kept unless it moved the dates.
  update public.bookings set days = public._booking_days_clean(
      case when p_booking ? 'days' then p_booking->>'days'
           when prev.id is not null and prev.date_from = b.date_from and prev.date_to = b.date_to then prev.days else '' end, b.date_from, b.date_to)
  where id = bid returning * into b;
  if b.days <> '' then   -- the first and the last chosen day are the period
    update public.bookings set date_from = split_part(b.days, ',', 1), date_to = reverse(split_part(reverse(b.days), ',', 1)) where id = bid returning * into b;
  end if;
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
    'booker_name',b.booker_name,
    'booker_role',(select case when mm.org <> '' then mm.org else mm.role end from public.members mm where mm.email = b.owner limit 1),
    'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'days',b.days,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,'answered_by',b.answered_by,
    'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,
    'guide_ok_at',b.guide_ok_at,'company_ok_at',b.company_ok_at,'company_ok_via',b.company_ok_via,'seen',b.seen_company);
end $function$;

create or replace function public._booking_content(b public.bookings)
 returns jsonb language sql stable set search_path to ''
as $function$
  select jsonb_build_object('date_from',b.date_from,'date_to',b.date_to,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'terms',b.terms)
    || case when b.days <> '' then jsonb_build_object('days', b.days) else '{}'::jsonb end   -- D-21; left out when empty, so sheets from before it compare as they did
$function$;

revoke all on function public._booking_days_clean(text,text,text) from public, anon, authenticated;
