-- Eshkol / Midbari rentals (12 Oct 2026). See docs/DECISIONS.md D-42. Run after 2026-10-08c_brochure_kind.sql.
-- supabase/schema.sql already includes everything below; this file is the step-by-step change. Safe to run twice.
-- It only adds and replaces: two new tables, one new column on vendor_notes, new functions, and _section_of,
-- _can_see, whoami and set_setting replaced (each gains what rentals need; everything else in them is as it was).
-- It removes nothing, so it can go through the connector.
--
-- THE CATEGORY ITSELF IS IN ITS OWN FILE: 2026-10-12c_vehicle_rental_category.sql adds 'Vehicle Rental' to the list of
-- categories a supplier may have. That statement takes the old list off before it puts the new one on, so the owner
-- runs it himself in the Supabase SQL editor (rule G5). Until he has, a supplier cannot be saved in the new category;
-- everything in this file still works, and nothing here depends on the order the two files run in.
--
-- The owner, 12 Oct 2026, 09:15: "Add a category for eshkol/Midbari rental, with category of cost, milage, over mileage
-- cost, year make Of car, location, passenger seats, other terms of rental, color of car with availability calender,
-- notes for. Renter notes for review". Who marks the calendar: "Members only". 09:30: "put it as its own category".
--
-- A rental company is one supplier in the category Vehicle Rental (shown as "Eshkol / Midbari rental"). Its vehicles
-- hang under it, one row each, with a day price that is a dated reference (source and date, rule E4), km included,
-- the price of an extra km, the terms and notes for the renter. Each vehicle has a calendar: a day is free, booked or
-- not known (no row, or a row set back to not known). Any approved member who can see the vehicle marks a day; the
-- page shows who changed the calendar last and when, by name only (D1). No client names, trips or notes on a day.
-- A review is an ordinary review of the supplier (D-14, E9 unchanged) that may name the vehicle.
--
-- Who sees what:
--   * Until Eretz Israel Tours changes the setting rentals_for, only Eretz Israel Tours sees any of it, and a supplier
--     whose category is Vehicle Rental is hidden from every colleague:
--       'admin' = Eretz Israel Tours only (the default)      'all' = every approved member
--   * Organisations (limited members) see rentals with Transportation (section 'transport').
--   * A supplier that is hidden or waiting for review shows no vehicles to colleagues.
--   * An organisation never receives an agent day price (C3): on a vehicle marked agent, the day price, the extra-km
--     price and their source and date are left out for an organisation. An organisation cannot mark a vehicle agent.
--   * A private-price supplier (prices_private) sends no vehicle prices to colleagues, as with its price lines (D4).
--   * Nobody receives another member's email or phone: names only.

-- ===== tables =====
create table if not exists public.rental_vehicles (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,   -- the rental company (a supplier's id). No foreign key: a vehicle whose supplier is gone is never shown.
  licence_type text default 'eshkol'::text not null,
  make_model text default ''::text not null,
  year integer,
  colour text default ''::text not null,
  passenger_seats integer,
  pickup_location text default ''::text not null,
  cost_per_day numeric,
  currency text default 'ILS'::text not null,
  vat text default ''::text not null,
  km_included_per_day integer,
  cost_per_extra_km numeric,
  price_source text default ''::text not null,
  price_checked_on date,
  is_agent boolean default false not null,
  other_terms text default ''::text not null,
  renter_notes text default ''::text not null,
  archived boolean default false not null,   -- archive, never remove
  created_by text not null,
  created_at timestamp with time zone default now() not null,
  updated_by text not null,
  updated_at timestamp with time zone default now() not null,
  constraint rental_vehicles_pkey primary key (id),
  constraint rental_vehicles_licence_check check (licence_type = any (array['eshkol'::text, 'midbari'::text, 'both'::text])),
  constraint rental_vehicles_currency_check check (currency = any (array['ILS'::text, 'USD'::text, 'EUR'::text])),
  constraint rental_vehicles_vat_check check (vat = any (array[''::text, 'including_vat'::text, 'plus_vat'::text, 'not_applicable'::text])),
  constraint rental_vehicles_numbers_check check ((year is null or year between 1980 and 2100) and (passenger_seats is null or passenger_seats between 1 and 60)
    and (cost_per_day is null or cost_per_day between 0 and 1000000) and (km_included_per_day is null or km_included_per_day between 0 and 10000)
    and (cost_per_extra_km is null or cost_per_extra_km between 0 and 10000)),
  constraint rental_vehicles_lengths_check check (length(trim(both from make_model)) between 2 and 80 and length(colour) <= 40 and length(pickup_location) <= 200
    and length(price_source) <= 200 and length(other_terms) <= 2000 and length(renter_notes) <= 2000 and length(vendor_id) <= 60),
  constraint rental_vehicles_price_source_check check ((cost_per_day is null and cost_per_extra_km is null) or (price_source <> ''::text and price_checked_on is not null))
);
alter table public.rental_vehicles enable row level security;
create index if not exists rental_vehicles_vendor_idx on public.rental_vehicles using btree (vendor_id);

create table if not exists public.rental_days (
  vehicle_id uuid not null,
  day date not null,
  status text not null,
  set_by text not null,
  set_at timestamp with time zone default now() not null,
  constraint rental_days_pkey primary key (vehicle_id, day),
  constraint rental_days_status_check check (status = any (array['free'::text, 'booked'::text, 'unknown'::text]))
);
alter table public.rental_days enable row level security;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'rental_days_vehicle_id_fkey') then
    alter table public.rental_days add constraint rental_days_vehicle_id_fkey foreign key (vehicle_id) references public.rental_vehicles(id);
  end if;
end $$;
create index if not exists rental_days_set_idx on public.rental_days using btree (vehicle_id, set_at);

-- A review may name the vehicle it is about. '' / null = a review of the supplier as a whole, as before.
alter table public.vendor_notes add column if not exists vehicle_id uuid;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'vendor_notes_vehicle_id_fkey') then
    alter table public.vendor_notes add constraint vendor_notes_vehicle_id_fkey foreign key (vehicle_id) references public.rental_vehicles(id);
  end if;
end $$;

revoke all on table public.rental_vehicles, public.rental_days from public, anon, authenticated;
grant all on table public.rental_vehicles, public.rental_days to service_role;

-- ===== the switch =====
-- Rentals are open to Eretz Israel Tours, and to every approved member once the setting rentals_for is 'all'.
create or replace function public._rentals_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(m.is_admin or coalesce((select value from public.app_settings where key = 'rentals_for'), '') = 'all', false)
$function$;
revoke all on function public._rentals_on(public.members) from public, anon, authenticated;

-- ===== who may see a supplier: rentals belong to Transportation, and stay with Eretz Israel Tours until opened =====
create or replace function public._section_of(p_category text)
 returns text language sql immutable set search_path to ''
as $function$
  select case p_category when 'Transport' then 'transport' when 'Vehicle Rental' then 'transport' when 'Guide' then 'guides' when 'Hotel' then 'hotels'
    when 'Restaurant' then 'food' when 'Winery' then 'food'
    when 'Attraction / Site' then 'sites' when 'Activity' then 'sites' when 'Adventure' then 'sites' when 'National Parks' then 'sites'
    else 'other' end
$function$;
revoke all on function public._section_of(text) from public, anon, authenticated;

-- May this member see a supplier of this category (main, or one of its "also offers")?
-- A supplier whose main category is Vehicle Rental is seen only where rentals are open (D-42); "also offers Vehicle
-- Rental" counts towards an organisation's sections only where rentals are open.
create or replace function public._can_see(m public.members, p_category text, p_also text)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when coalesce(p_category,'') = 'Vehicle Rental' and not public._rentals_on(m) then false
    when not public._limited(m) then true
    else exists (select 1 from unnest(array[coalesce(p_category,'')] || string_to_array(coalesce(p_also,''), ',')) c
                 where trim(c) <> '' and (trim(c) <> 'Vehicle Rental' or public._rentals_on(m))
                   and public._section_of(trim(c)) = any (string_to_array(m.sections, ','))) end
$function$;
revoke all on function public._can_see(public.members,text,text) from public, anon, authenticated;

-- ===== vehicles: internal helpers =====
-- Is this supplier a rental company? Main category Vehicle Rental, or Vehicle Rental under "also offers".
create or replace function public._is_rental(v public.vendors)
 returns boolean language sql immutable set search_path to ''
as $function$
  select coalesce(v.category = 'Vehicle Rental' or coalesce(v.also_categories,'') ~* '(^|,)\s*Vehicle Rental\s*(,|$)', false)
$function$;
revoke all on function public._is_rental(public.vendors) from public, anon, authenticated;

-- May this member see this supplier's vehicles? Eretz Israel Tours always. Anyone else: rentals open, the supplier is a
-- rental company, not hidden, approved (not waiting for review), and in his sections.
create or replace function public._rental_vendor_ok(v public.vendors, m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(v.id is not null and m.id is not null and public._is_rental(v) and (m.is_admin or (public._rentals_on(m) and not v.hidden
    and v.review_status = 'approved' and public._can_see(m, v.category, v.also_categories))), false)
$function$;
revoke all on function public._rental_vendor_ok(public.vendors,public.members) from public, anon, authenticated;

-- Today in Israel.
create or replace function public._il_today()
 returns date language sql stable set search_path to ''
as $function$
  select (now() at time zone 'Asia/Jerusalem')::date
$function$;
revoke all on function public._il_today() from public, anon, authenticated;

-- One vehicle, for one member. Prices are left out for an organisation on an agent vehicle (C3) and for everyone but
-- Eretz Israel Tours and the member who added it on a private-price supplier (D4); price_hidden then says a price exists.
create or replace function public._rental_json(r public.rental_vehicles, v public.vendors, m public.members)
 returns jsonb language sql stable security definer set search_path to ''
as $function$
  select jsonb_build_object('id', r.id, 'vendor_id', r.vendor_id, 'licence_type', r.licence_type, 'make_model', r.make_model,
    'year', r.year, 'colour', r.colour, 'passenger_seats', r.passenger_seats, 'pickup_location', r.pickup_location,
    'cost_per_day', case when x.pv then r.cost_per_day end, 'cost_per_extra_km', case when x.pv then r.cost_per_extra_km end,
    'currency', r.currency, 'vat', case when x.pv then r.vat else '' end, 'km_included_per_day', r.km_included_per_day,
    'price_source', case when x.pv then r.price_source else '' end, 'price_checked_on', case when x.pv then r.price_checked_on end,
    'is_agent', x.pv and r.is_agent,
    'price_hidden', not x.pv and (r.cost_per_day is not null or r.cost_per_extra_km is not null),
    'other_terms', r.other_terms, 'renter_notes', r.renter_notes, 'archived', r.archived,
    'by', public._name(r.created_by), 'updated_by', public._name(r.updated_by), 'updated_at', r.updated_at, 'created_at', r.created_at,
    'mine', r.created_by = m.email, 'can_edit', coalesce(m.is_admin, false) or r.created_by = m.email,
    'tomorrow', coalesce((select d.status from public.rental_days d where d.vehicle_id = r.id and d.day = public._il_today() + 1), 'unknown'),
    'kept', exists (select 1 from public.rental_days d where d.vehicle_id = r.id and d.status <> 'unknown' and d.day >= public._il_today()))
  from (select coalesce(m.is_admin, false) or r.created_by = m.email
               or not (coalesce(v.prices_private, false) or (r.is_agent and public._limited(m))) as pv) x
$function$;
revoke all on function public._rental_json(public.rental_vehicles,public.vendors,public.members) from public, anon, authenticated;

-- ===== vehicles: calls the app makes =====
-- Every vehicle this member may see, with tomorrow's state. Archived vehicles: Eretz Israel Tours only.
create or replace function public.rentals_list(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if not public._rentals_on(m) then return '[]'::json; end if;
  return coalesce((select json_agg(public._rental_json(r, v, m) order by v.name, r.archived, r.make_model, r.created_at)
    from public.rental_vehicles r join public.vendors v on v.id = r.vendor_id
    where public._rental_vendor_ok(v, m) and (not r.archived or m.is_admin)), '[]'::json);
end $function$;
revoke all on function public.rentals_list(text) from public; grant execute on function public.rentals_list(text) to anon, authenticated;

-- One vehicle with its calendar (from the first of last month) and who changed the calendar last.
create or replace function public.rental_vehicle(p_token text, p_id uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; r public.rental_vehicles; v public.vendors;
begin
  m := public._auth(p_token);
  select * into r from public.rental_vehicles where id = p_id;
  select * into v from public.vendors where id = r.vendor_id;
  if r.id is null or not public._rental_vendor_ok(v, m) or (r.archived and not m.is_admin) then raise exception 'That vehicle is not available.'; end if;
  return json_build_object('vehicle', public._rental_json(r, v, m),
    'days', coalesce((select json_agg(json_build_object('day', d.day, 'status', d.status) order by d.day) from public.rental_days d
      where d.vehicle_id = r.id and d.status <> 'unknown' and d.day >= (date_trunc('month', public._il_today()) - interval '1 month')::date), '[]'::json),
    'last', (select json_build_object('by', public._name(d.set_by), 'at', d.set_at) from public.rental_days d where d.vehicle_id = r.id order by d.set_at desc limit 1));
end $function$;
revoke all on function public.rental_vehicle(text,uuid) from public; grant execute on function public.rental_vehicle(text,uuid) to anon, authenticated;

-- Add a vehicle to a rental company, or change one. Eretz Israel Tours changes any vehicle; a member changes the ones he added.
create or replace function public.rental_vehicle_save(p_token text, p_vehicle jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors; r public.rental_vehicles; d jsonb := coalesce(p_vehicle, '{}'::jsonb);
  t text; lt text; mk text; yr int; seats int; cost numeric; xkm numeric; km int; cur text; vt text; src text; chk date; ag boolean;
begin
  m := public._auth(p_token);
  if not public._rentals_on(m) then raise exception 'Eshkol / Midbari rentals are not open yet.'; end if;
  t := coalesce(d->>'id', '');
  if t <> '' then
    if t !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'That vehicle is not available.'; end if;
    select * into r from public.rental_vehicles where id = t::uuid;
    select * into v from public.vendors where id = r.vendor_id;
    if r.id is null or not public._rental_vendor_ok(v, m) or (r.archived and not m.is_admin) then raise exception 'That vehicle is not available.'; end if;
    if not (m.is_admin or r.created_by = m.email) then raise exception 'Only the member who added this vehicle, or Eretz Israel Tours, can change it.'; end if;
  else
    select * into v from public.vendors where id = coalesce(d->>'vendor_id', '');
    if v.id is null or not (m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories))) then raise exception 'That supplier is not available.'; end if;
    if not public._is_rental(v) then raise exception 'A vehicle can be added only to a supplier in Eshkol / Midbari rental.'; end if;
    if not public._rental_vendor_ok(v, m) then raise exception 'Vehicles can be added once Eretz Israel Tours has approved this supplier.'; end if;
  end if;
  lt := lower(trim(coalesce(d->>'licence_type', '')));
  if lt not in ('eshkol', 'midbari', 'both') then raise exception 'Choose Eshkol, Midbari or both.'; end if;
  mk := trim(coalesce(d->>'make_model', ''));
  if length(mk) < 2 or length(mk) > 80 then raise exception 'Write the make and model of the car.'; end if;
  t := trim(coalesce(d->>'year', ''));
  if t <> '' and t !~ '^\d{4}$' then raise exception 'Write the year the car was made, for example 2022.'; end if;
  yr := nullif(t, '')::int;
  if yr < 1980 or yr > extract(year from public._il_today())::int + 1 then raise exception 'Write the year the car was made, for example 2022.'; end if;
  t := trim(coalesce(d->>'passenger_seats', ''));
  if t <> '' and t !~ '^\d{1,2}$' then raise exception 'Passenger seats: a number from 1 to 60.'; end if;
  seats := nullif(t, '')::int;
  if seats < 1 or seats > 60 then raise exception 'Passenger seats: a number from 1 to 60.'; end if;
  t := replace(trim(coalesce(d->>'cost_per_day', '')), ',', '');
  if t <> '' and t !~ '^\d{1,6}(\.\d{1,2})?$' then raise exception 'Cost per day: a number, for example 850.'; end if;
  cost := nullif(t, '')::numeric;
  t := trim(coalesce(d->>'km_included_per_day', ''));
  if t <> '' and t !~ '^\d{1,4}$' then raise exception 'Km included per day: a whole number, for example 200.'; end if;
  km := nullif(t, '')::int;
  t := trim(coalesce(d->>'cost_per_extra_km', ''));
  if t <> '' and t !~ '^\d{1,4}(\.\d{1,2})?$' then raise exception 'Cost per extra km: a number, for example 1.80.'; end if;
  xkm := nullif(t, '')::numeric;
  cur := upper(trim(coalesce(nullif(d->>'currency', ''), 'ILS')));
  if cur not in ('ILS', 'USD', 'EUR') then raise exception 'Choose the currency.'; end if;
  vt := coalesce(d->>'vat', '');
  if vt not in ('', 'including_vat', 'plus_vat', 'not_applicable') then raise exception 'Choose how VAT is counted.'; end if;
  src := trim(coalesce(d->>'price_source', ''));
  chk := public._to_date(d->>'price_checked_on');
  if cost is not null or xkm is not null then   -- rule E4: every price carries its source and the date it was checked
    if src = '' then raise exception 'Write where the price is from, for example "their price list".'; end if;
    if chk is null then raise exception 'Write the date the price was checked.'; end if;
    if chk > public._il_today() then raise exception 'The date the price was checked cannot be in the future.'; end if;
  else src := ''; chk := null;
  end if;
  ag := coalesce((d->>'is_agent')::boolean, false) and not public._limited(m);   -- an organisation never adds an agent price (D-15)
  if length(coalesce(d->>'colour','')) > 40 or length(coalesce(d->>'pickup_location','')) > 200 or length(src) > 200
     or length(coalesce(d->>'other_terms','')) > 2000 or length(coalesce(d->>'renter_notes','')) > 2000 then raise exception 'One of the fields is too long.'; end if;
  if r.id is null then
    insert into public.rental_vehicles (vendor_id, licence_type, make_model, year, colour, passenger_seats, pickup_location, cost_per_day, currency, vat,
        km_included_per_day, cost_per_extra_km, price_source, price_checked_on, is_agent, other_terms, renter_notes, created_by, updated_by)
      values (v.id, lt, mk, yr, trim(coalesce(d->>'colour','')), seats, trim(coalesce(d->>'pickup_location','')), cost, cur, vt,
        km, xkm, src, chk, ag, trim(coalesce(d->>'other_terms','')), trim(coalesce(d->>'renter_notes','')), m.email, m.email)
      returning * into r;
  else
    update public.rental_vehicles set licence_type = lt, make_model = mk, year = yr, colour = trim(coalesce(d->>'colour','')), passenger_seats = seats,
        pickup_location = trim(coalesce(d->>'pickup_location','')), cost_per_day = cost, currency = cur, vat = vt, km_included_per_day = km,
        cost_per_extra_km = xkm, price_source = src, price_checked_on = chk, is_agent = case when public._limited(m) then r.is_agent else ag end,
        other_terms = trim(coalesce(d->>'other_terms','')), renter_notes = trim(coalesce(d->>'renter_notes','')), updated_by = m.email, updated_at = now()
      where id = r.id returning * into r;
  end if;
  return public._rental_json(r, v, m);
end $function$;
revoke all on function public.rental_vehicle_save(text,jsonb) from public; grant execute on function public.rental_vehicle_save(text,jsonb) to anon, authenticated;

-- Archive a vehicle (it leaves every colleague's list; nothing is removed). The member who added it or Eretz Israel Tours
-- archives it; only Eretz Israel Tours brings it back.
create or replace function public.rental_vehicle_archive(p_token text, p_id uuid, p_archived boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; r public.rental_vehicles; v public.vendors;
begin
  m := public._auth(p_token);
  select * into r from public.rental_vehicles where id = p_id;
  select * into v from public.vendors where id = r.vendor_id;
  if r.id is null or not public._rental_vendor_ok(v, m) or (r.archived and not m.is_admin) then raise exception 'That vehicle is not available.'; end if;
  if not (m.is_admin or (r.created_by = m.email and coalesce(p_archived, true))) then raise exception 'Only the member who added this vehicle, or Eretz Israel Tours, can archive it.'; end if;
  update public.rental_vehicles set archived = coalesce(p_archived, true), updated_by = m.email, updated_at = now() where id = r.id returning * into r;
  return public._rental_json(r, v, m);
end $function$;
revoke all on function public.rental_vehicle_archive(text,uuid,boolean) from public; grant execute on function public.rental_vehicle_archive(text,uuid,boolean) to anon, authenticated;

-- Mark one day of a vehicle's calendar: 'free', 'booked' or 'unknown' (not known). Any member who can see the vehicle.
-- The day carries only its state, who set it and when: no client, trip or note (D6, D-30).
create or replace function public.rental_day_set(p_token text, p_vehicle uuid, p_day date, p_status text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; r public.rental_vehicles; v public.vendors; st text := lower(trim(coalesce(p_status, '')));
begin
  m := public._auth(p_token);
  select * into r from public.rental_vehicles where id = p_vehicle;
  select * into v from public.vendors where id = r.vendor_id;
  if r.id is null or r.archived or not public._rental_vendor_ok(v, m) then raise exception 'That vehicle is not available.'; end if;
  if st not in ('free', 'booked', 'unknown') then raise exception 'A day is free, booked or not known.'; end if;
  if p_day is null or p_day < public._il_today() - 31 or p_day > public._il_today() + 730 then raise exception 'Choose a day from last month to two years ahead.'; end if;
  insert into public.rental_days (vehicle_id, day, status, set_by, set_at) values (r.id, p_day, st, m.email, now())
    on conflict (vehicle_id, day) do update set status = excluded.status, set_by = excluded.set_by, set_at = excluded.set_at;
  return json_build_object('day', p_day, 'status', st, 'last', json_build_object('by', public._name(m.email), 'at', now()));
end $function$;
revoke all on function public.rental_day_set(text,uuid,date,text) from public; grant execute on function public.rental_day_set(text,uuid,date,text) to anon, authenticated;

-- A review that names the vehicle. It is the supplier review in force (review_post: D-14, E9), with the vehicle added.
create or replace function public.rental_review_post(p_token text, p_vehicle uuid, p_body text, p_rating text, p_private boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; r public.rental_vehicles; v public.vendors; res json;
begin
  m := public._auth(p_token);
  select * into r from public.rental_vehicles where id = p_vehicle;
  select * into v from public.vendors where id = r.vendor_id;
  if r.id is null or r.archived or not public._rental_vendor_ok(v, m) then raise exception 'That vehicle is not available.'; end if;
  if length(trim(coalesce(p_body, ''))) < 1 then raise exception 'Write your review first.'; end if;
  res := public.review_post(p_token, v.id, p_body, p_rating, p_private);
  update public.vendor_notes set vehicle_id = r.id where vendor_id = v.id and author = m.email and created_at = now() and vehicle_id is null;
  return res;
end $function$;
revoke all on function public.rental_review_post(text,uuid,text,text,boolean) from public; grant execute on function public.rental_review_post(text,uuid,text,text,boolean) to anon, authenticated;

-- ===== the switch in the Team tab, and what the app is told =====
create or replace function public.set_setting(p_token text, p_key text, p_value text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email','bookings_for','jobs_for','hikes_for','rentals_for') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  if p_key = 'bookings_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'jobs_for' and lower(trim(p_value)) not in ('admin','receive','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'hikes_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'rentals_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  insert into public.app_settings (key, value) values (p_key, lower(trim(p_value))) on conflict (key) do update set value = excluded.value;
end $function$;
revoke all on function public.set_setting(text,text,text) from public; grant execute on function public.set_setting(text,text,text) to anon, authenticated;

-- whoami: also what kind of member this is and what he sees, so the app shows only that.
create or replace function public.whoami(p_token text)
 returns json language sql security definer set search_path to ''
as $function$
  select json_build_object('name',name,'email',email,'status',status,'is_admin',is_admin,'role',case when org <> '' then 'Organisation, not in tourism' else role end,'has_proof',proof_path is not null,'terms_version',terms_version,
    'reminder_due', (not is_admin) and (reminder_seen_at is null or reminder_seen_at < now() - interval '30 days'),
    'bcc_email', case when status = 'approved' then (select value from public.app_settings where key = 'bcc_email') else '' end,
    'bcc_opt_out', bcc_opt_out, 'bcc_ack', bcc_ack,
    'phone', phone,
    'bookings', status = 'approved' and public._bookings_on(m),
    'bookings_for', case when is_admin then coalesce((select value from public.app_settings where key = 'bookings_for'),'admin') else '' end,
    'jobs', status = 'approved' and public._jobs_on(m),
    'jobs_post', status = 'approved' and public._jobs_post(m),
    'jobs_for', case when is_admin then coalesce((select value from public.app_settings where key = 'jobs_for'),'admin') else '' end,
    'hikes', status = 'approved' and public._hikes_on(m),
    'hikes_for', case when is_admin then coalesce((select value from public.app_settings where key = 'hikes_for'),'admin') else '' end,
    'rentals', status = 'approved' and public._rentals_on(m),
    'rentals_for', case when is_admin then coalesce((select value from public.app_settings where key = 'rentals_for'),'admin') else '' end,
    'member_type', case when public._limited(m) then 'limited' else 'full' end,
    'sections', case when public._limited(m) then sections else '' end,
    'see_quotes', not public._limited(m) or see_quotes,
    'see_guide_rates', not public._limited(m) or see_guide_rates,
    'see_transport_reviews', not public._limited(m) or see_transport_reviews,
    'see_reviews', not public._limited(m) or see_reviews,
    'org', org)
  from public.members m where token_hash = public._hash(p_token);
$function$;
revoke all on function public.whoami(text) from public; grant execute on function public.whoami(text) to anon, authenticated;
