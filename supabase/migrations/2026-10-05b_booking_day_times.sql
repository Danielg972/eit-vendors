-- D-24 and D-25 (5 Oct 2026), booking sheets.
--
-- D-24: on a booking sheet of more than one day, each day has its own pick-up time and estimated finish.
-- The owner, 5 Oct 2026, 15:34: "each day needs its own start and finsh time. there should be be timated."
-- Adds bookings.day_plan (jsonb): {"2026-10-20": {"start":"08:30","end":"18:00","route":"…"}, …}.
-- '{}' = the sheet's one pick-up and drop-off time apply to every day.
--
-- D-25: the guide can leave terms off a sheet.
-- The owner, 5 Oct 2026, 15:44: "can make "all of the terms youre expecting" removable by box. meaning if i want to
-- send without the "tip" or ;mileage etc".
-- Adds bookings.terms_off (text): a comma list out of hours, km, tolls, parking, tip, cancel, extras, payment.
-- '' = every term is on the sheet. A term left off is taken out of what the guide expects, is not taken from the
-- company's answer either, and is part of what both sides accept.
--
-- Every booking sheet made before this stays exactly as it is (both columns start empty).
-- Two new columns, three new internal helpers, five functions replaced. No grant, no policy; nothing is deleted or
-- dropped. Safe to run twice. Run on production through the connector on 5 Oct 2026, about 16:00, on the owner's word.

alter table public.bookings add column if not exists day_plan jsonb not null default '{}'::jsonb;
alter table public.bookings add column if not exists terms_off text not null default '';
do $do$ begin
  if not exists (select 1 from pg_constraint where conname = 'bookings_day_plan_check' and conrelid = 'public.bookings'::regclass) then
    alter table public.bookings add constraint bookings_day_plan_check
      check (jsonb_typeof(day_plan) = 'object'::text and length(day_plan::text) <= 30000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'bookings_terms_off_check' and conrelid = 'public.bookings'::regclass) then
    alter table public.bookings add constraint bookings_terms_off_check check (terms_off ~ '^[a-z,]{0,80}$'::text);
  end if;
end $do$;

create or replace function public._booking_plan_clean(p_plan jsonb, p_from text, p_to text, p_days text)
 returns jsonb language plpgsql stable set search_path to ''
as $function$
declare k text; v jsonb; o jsonb := '{}'::jsonb; s text; e text; r text; n int := 0;
begin
  if p_plan is null or jsonb_typeof(p_plan) <> 'object' then return o; end if;
  if coalesce(p_from,'') = '' or coalesce(p_to,'') = '' or p_to <= p_from then return o; end if;   -- one day: the sheet's own times
  for k, v in select key, value from jsonb_each(p_plan) order by key loop
    continue when k !~ '^\d{4}-\d{2}-\d{2}$' or jsonb_typeof(v) <> 'object' or k < p_from or k > p_to;
    continue when coalesce(p_days,'') <> '' and not (k = any (string_to_array(p_days, ',')));
    s := case when coalesce(v->>'start','') ~ '^([01]\d|2[0-3]):[0-5]\d$' then v->>'start' else '' end;
    e := case when coalesce(v->>'end','') ~ '^([01]\d|2[0-3]):[0-5]\d$' then v->>'end' else '' end;
    r := left(trim(coalesce(v->>'route','')), 300);
    continue when s = '' and e = '' and r = '';
    o := o || jsonb_build_object(k, jsonb_strip_nulls(jsonb_build_object('start', nullif(s,''), 'end', nullif(e,''), 'route', nullif(r,''))));
    n := n + 1; exit when n >= 62;
  end loop;
  return o;
end $function$;

create or replace function public._terms_off_clean(p text)
 returns text language sql immutable set search_path to ''
as $function$
  select coalesce(string_agg(u.k, ',' order by u.ord), '')
  from unnest(array['hours','km','tolls','parking','tip','cancel','extras','payment']) with ordinality u(k, ord)
  where u.k = any (string_to_array(replace(coalesce(p,''), ' ', ''), ','))
$function$;

create or replace function public._terms_on(t jsonb, p_off text)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select coalesce(t, '{}'::jsonb)
    - case when 'hours' = any (o) then array['hours_incl','hours_from','overtime'] else '{}'::text[] end
    - case when 'km' = any (o) then array['km_incl','extra_km'] else '{}'::text[] end
    - case when 'tolls' = any (o) then array['tolls','tolls_note'] else '{}'::text[] end
    - case when 'parking' = any (o) then array['parking'] else '{}'::text[] end
    - case when 'tip' = any (o) then array['tip','tip_amt'] else '{}'::text[] end
    - case when 'cancel' = any (o) then array['cancel'] else '{}'::text[] end
    - case when 'extras' = any (o) then array['extras'] else '{}'::text[] end
    - case when 'payment' = any (o) then array['payment'] else '{}'::text[] end
  from (select string_to_array(coalesce(p_off,''), ',') as o) x
$function$;

create or replace function public._booking_json(b public.bookings)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',b.id,'vendor_id',b.vendor_id,'vendor_name',(select v.name from public.vendors v where v.id = b.vendor_id),
    'key',b.link_key,'status',b.status,'client_ref',b.client_ref,'booker_name',b.booker_name,'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'days',b.days,'day_plan',b.day_plan,'terms_off',b.terms_off,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
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
  -- D-24: each day's own times. A copy of the app from before D-24 sends no "day_plan": it is kept, cut down to the days still on the sheet.
  update public.bookings set day_plan = public._booking_plan_clean(
      case when p_booking ? 'day_plan' then p_booking->'day_plan' when prev.id is not null then prev.day_plan else '{}'::jsonb end,
      b.date_from, b.date_to, b.days)
  where id = bid returning * into b;
  -- D-25: terms the guide left off the sheet. They are taken out of what he expects and out of the terms already there.
  -- A copy of the app from before D-25 sends no "terms_off": the list is kept.
  update public.bookings set terms_off = public._terms_off_clean(
      case when p_booking ? 'terms_off' then p_booking->>'terms_off' when prev.id is not null then prev.terms_off else '' end)
  where id = bid returning * into b;
  if b.terms_off <> '' then
    update public.bookings set proposed = public._terms_on(proposed, b.terms_off), terms = public._terms_on(terms, b.terms_off) where id = bid returning * into b;
  end if;
  if jsonb_typeof(p_booking->'terms') = 'object' then
    if coalesce(public._terms_clean(p_booking->'terms')->>'price','') = '' then raise exception 'Add the price.'; end if;
    agreed := coalesce((p_booking->>'company_agreed')::boolean, false);
    update public.bookings set terms = public._terms_on(public._terms_clean(p_booking->'terms'), b.terms_off), terms_by = 'guide',
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
    'date_from',b.date_from,'date_to',b.date_to,'days',b.days,'day_plan',b.day_plan,'terms_off',b.terms_off,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,'answered_by',b.answered_by,
    'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,
    'guide_ok_at',b.guide_ok_at,'company_ok_at',b.company_ok_at,'company_ok_via',b.company_ok_via,'seen',b.seen_company);
end $function$;

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
  t := public._terms_on(t, b.terms_off);   -- D-25: a term the guide left off the sheet is not taken from the company either
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

create or replace function public._booking_content(b public.bookings)
 returns jsonb language sql stable set search_path to ''
as $function$
  select jsonb_build_object('date_from',b.date_from,'date_to',b.date_to,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'terms',b.terms)
    || case when b.days <> '' then jsonb_build_object('days', b.days) else '{}'::jsonb end   -- D-21; left out when empty, so sheets from before it compare as they did
    || case when b.day_plan <> '{}'::jsonb then jsonb_build_object('day_plan', b.day_plan) else '{}'::jsonb end   -- D-24; the same
    || case when b.terms_off <> '' then jsonb_build_object('terms_off', b.terms_off) else '{}'::jsonb end   -- D-25; the same
$function$;

revoke all on function public._booking_plan_clean(jsonb,text,text,text) from public, anon, authenticated;
revoke all on function public._terms_off_clean(text) from public, anon, authenticated;
revoke all on function public._terms_on(jsonb,text) from public, anon, authenticated;
