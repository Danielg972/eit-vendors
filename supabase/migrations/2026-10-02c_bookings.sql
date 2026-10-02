-- Booking sheets for buses and vans (2 Oct 2026). See docs/DECISIONS.md D-5. Run after 2026-10-02b_drivers.sql.
-- Paste the whole file into the Supabase SQL editor for project wjuqtjlrtcywjaspjpwu and run it once.
-- supabase/schema.sql already includes everything below; this file is the step-by-step change. Safe to run twice.
--
-- A guide fills in the job (date, pick-up, route, drop-off), sends the company a link, and the company fills in the
-- price and terms: hours and km included, overtime, extra km, Kvish 6, parking, tip, cancellation, payment, free text.
-- The company is NOT a member. Its link carries one random key that opens that one booking and nothing else
-- (booking_open / booking_answer below); it never reaches the supplier list, a member, or another booking.

create table if not exists public.bookings (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  owner text not null,
  owner_name text default ''::text not null,
  link_key text not null,
  status text default 'waiting'::text not null,
  client_ref text default ''::text not null,
  booker_name text default ''::text not null,
  booker_phone text default ''::text not null,
  date_from text default ''::text not null,
  date_to text default ''::text not null,
  pax text default ''::text not null,
  service text default ''::text not null,
  seats text default ''::text not null,
  tourists boolean default true not null,
  pickup_time text default ''::text not null,
  pickup_place text default ''::text not null,
  route text default ''::text not null,
  dropoff_time text default ''::text not null,
  dropoff_place text default ''::text not null,
  note text default ''::text not null,
  private_note text default ''::text not null,
  proposed jsonb default '{}'::jsonb not null,
  terms jsonb default '{}'::jsonb not null,
  terms_by text default ''::text not null,
  answered_by text default ''::text not null,
  answered_at timestamp with time zone,
  answers integer default 0 not null,
  shared boolean default true not null,
  quote_id uuid,
  confirmed_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint bookings_pkey primary key (id),
  constraint bookings_link_key_key unique (link_key),
  constraint bookings_vendor_id_fkey foreign key (vendor_id) references public.vendors(id) on delete cascade,
  constraint bookings_quote_id_fkey foreign key (quote_id) references public.quotes(id) on delete set null,
  constraint bookings_status_check check (status = any (array['waiting'::text, 'answered'::text, 'confirmed'::text, 'cancelled'::text])),
  constraint bookings_terms_by_check check (terms_by = any (array[''::text, 'company'::text, 'guide'::text])),
  constraint bookings_date_from_check check (date_from = ''::text or date_from ~ '^\d{4}-\d{2}-\d{2}$'::text),
  constraint bookings_date_to_check check (date_to = ''::text or date_to ~ '^\d{4}-\d{2}-\d{2}$'::text),
  constraint bookings_seats_check check (seats = ''::text or seats ~ '^\d{1,3}$'::text),
  constraint bookings_service_check check (service = any (array[''::text, 'bus'::text, 'midibus'::text, 'van20'::text, 'van16'::text, 'van10'::text, 'van8'::text, 'car'::text, 'jeep_vehicle'::text, 'transfer'::text])),
  constraint bookings_lengths_check check (length(client_ref) <= 160 and length(booker_name) <= 80 and length(booker_phone) <= 40 and length(pax) <= 20
    and length(pickup_time) <= 20 and length(dropoff_time) <= 20 and length(pickup_place) <= 160 and length(dropoff_place) <= 160
    and length(route) <= 1500 and length(note) <= 1500 and length(private_note) <= 3000 and length(answered_by) <= 80 and length(link_key) >= 32)
);
alter table public.bookings enable row level security;
create index if not exists bookings_vendor_idx on public.bookings using btree (vendor_id);
create index if not exists bookings_owner_idx on public.bookings using btree (owner);
revoke all on table public.bookings from public, anon, authenticated;
grant all on table public.bookings to service_role;

-- Keep only known term keys, with plain numbers and short text.
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
    'cancel', nullif(left(trim(coalesce(t->>'cancel','')),200),''),
    'payment', nullif(left(trim(coalesce(t->>'payment','')),200),''),
    'note', nullif(left(trim(coalesce(t->>'note','')),1500),'')))
  from (select case when jsonb_typeof(p) = 'object' then p else '{}'::jsonb end as t) x
$function$;
revoke all on function public._terms_clean(jsonb) from public, anon, authenticated;

-- Who may use booking sheets: Eretz Israel Tours only, until the setting bookings_for is 'all'.
create or replace function public._bookings_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select m.is_admin or coalesce((select value from public.app_settings where key = 'bookings_for'), '') = 'all'
$function$;
revoke all on function public._bookings_on(public.members) from public, anon, authenticated;

-- What the guide (or Eretz Israel Tours) gets back. Only ever built for the owner or the admin.
create or replace function public._booking_json(b public.bookings)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',b.id,'vendor_id',b.vendor_id,'vendor_name',(select v.name from public.vendors v where v.id = b.vendor_id),
    'key',b.link_key,'status',b.status,'client_ref',b.client_ref,'booker_name',b.booker_name,'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'private_note',b.private_note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,
    'answered_by',b.answered_by,'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,'shared',b.shared,'in_tracker',b.quote_id is not null,
    'mine', b.owner = coalesce(current_setting('app.editor', true),''),
    'owner_name',b.owner_name,
    'owner_role',(select mm.role from public.members mm where mm.email = b.owner limit 1),
    'owner_admin',(select mm.is_admin from public.members mm where mm.email = b.owner limit 1),
    'created_at',b.created_at,'updated_at',b.updated_at)
$function$;
revoke all on function public._booking_json(public.bookings) from public, anon, authenticated;

-- A confirmed sheet becomes a "Booked" quote on the supplier, so it feeds the Quotes tab like any other quote:
-- anonymous to colleagues unless switched off, never the client. The free-text notes are not copied.
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
    case when t ? 'cancel' then 'Free cancellation until: ' || (t->>'cancel') end,
    case when t ? 'payment' then 'Payment: ' || (t->>'payment') end,
    'From a confirmed booking sheet.');
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

-- The guide saves his half. A new sheet gets its link key here. If p_booking carries "terms", the guide is typing in
-- what the company told him (phone, WhatsApp), and the sheet counts as answered by the guide.
create or replace function public.booking_save(p_token text, p_vendor text, p_booking jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; bid uuid := nullif(p_booking->>'id','')::uuid; b public.bookings; prev public.bookings;
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
    insert into public.bookings (vendor_id, owner, owner_name, link_key) values (p_vendor, m.email, m.name, public._new_token()) returning id into bid;
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
    -- the guide typed the company's answer himself
    if coalesce(public._terms_clean(p_booking->'terms')->>'price','') = '' then raise exception 'Add the price the company gave you.'; end if;
    update public.bookings set terms = public._terms_clean(p_booking->'terms'), terms_by = 'guide', status = 'answered',
      answered_by = left(trim(coalesce(p_booking->>'answered_by','')),80), answered_at = now() where id = bid returning * into b;
  elsif prev.id is not null and prev.status = 'answered' and prev.terms_by = 'company'
    and (prev.date_from, prev.date_to, prev.pax, prev.service, prev.seats, prev.pickup_time, prev.pickup_place, prev.route, prev.dropoff_time, prev.dropoff_place)
        is distinct from (b.date_from, b.date_to, b.pax, b.service, b.seats, b.pickup_time, b.pickup_place, b.route, b.dropoff_time, b.dropoff_place) then
    -- the job changed after the company answered: its answer no longer stands, so it has to send it again
    update public.bookings set status = 'waiting' where id = bid returning * into b;
  end if;
  return public._booking_json(b);
end $function$;
revoke all on function public.booking_save(text,text,jsonb) from public; grant execute on function public.booking_save(text,text,jsonb) to anon, authenticated;

-- A member's own booking sheets (Eretz Israel Tours: everyone's). p_vendor '' = all suppliers.
create or replace function public.bookings_list(p_token text, p_vendor text default ''::text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if not public._bookings_on(m) then return '[]'::json; end if;
  return coalesce((select json_agg(public._booking_json(b) order by (b.status in ('cancelled')), coalesce(nullif(b.date_from,''),'9999') desc, b.created_at desc)
    from public.bookings b
    where (m.is_admin or b.owner = m.email) and (coalesce(p_vendor,'') = '' or b.vendor_id = p_vendor)), '[]'::json);
end $function$;
revoke all on function public.bookings_list(text,text) from public; grant execute on function public.bookings_list(text,text) to anon, authenticated;

-- confirmed: the guide accepts the company's terms; the sheet locks and feeds the Quotes tab.
-- cancelled: the link stops taking answers. open: unlock it again (the company can change its answer).
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
    if b.status <> 'answered' or coalesce(b.terms->>'price','') = '' then raise exception 'The company has not sent its price yet.'; end if;
    update public.bookings set status = 'confirmed', confirmed_at = now(), updated_at = now() where id = p_id returning * into b;
    qid := public._booking_to_quote(b);
    update public.bookings set quote_id = qid where id = p_id returning * into b;
  elsif p_status = 'cancelled' then
    if b.quote_id is not null then update public.quotes set status = 'Received', updated_at = now() where id = b.quote_id and status = 'Booked'; end if;
    update public.bookings set status = 'cancelled', updated_at = now() where id = p_id returning * into b;
  elsif p_status = 'open' then
    if b.quote_id is not null then delete from public.quotes where id = b.quote_id; end if;
    update public.bookings set status = case when coalesce(terms->>'price','') <> '' then 'answered' else 'waiting' end,
      confirmed_at = null, quote_id = null, updated_at = now() where id = p_id returning * into b;
  else
    raise exception 'Unknown status.';
  end if;
  return public._booking_json(b);
end $function$;
revoke all on function public.booking_set_status(text,uuid,text) from public; grant execute on function public.booking_set_status(text,uuid,text) to anon, authenticated;

create or replace function public.booking_delete(p_token text, p_id uuid)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members; b public.bookings;
begin
  m := public._auth(p_token);
  select * into b from public.bookings where id = p_id and (owner = m.email or m.is_admin);
  if b.id is null then return; end if;
  if b.quote_id is not null then delete from public.quotes where id = b.quote_id; end if;
  delete from public.bookings where id = p_id;
end $function$;
revoke all on function public.booking_delete(text,uuid) from public; grant execute on function public.booking_delete(text,uuid) to anon, authenticated;

-- ===== The company's side: no member token. The key in its link is the only thing it has. =====
-- Returns that one booking: the job, who is asking, and the terms so far. Never the owner's email, the client,
-- the private note, a supplier id, or anything else from the list.
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
    'answered_at',b.answered_at,'confirmed_at',b.confirmed_at);
end $function$;
revoke all on function public.booking_open(text) from public; grant execute on function public.booking_open(text) to anon, authenticated;

-- The company sends its half. Allowed until the guide confirms or cancels; it may correct its answer up to 30 times.
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
  update public.bookings set terms = t, terms_by = 'company', answered_by = left(trim(coalesce(p_name,'')),80), answered_at = now(),
    status = 'answered', answers = answers + 1, updated_at = now() where id = b.id;
  return public.booking_open(p_key);
end $function$;
revoke all on function public.booking_answer(text,jsonb,text) from public; grant execute on function public.booking_answer(text,jsonb,text) to anon, authenticated;

-- whoami: also the member's own phone (to fill in "booked by") and whether booking sheets are open to them.
create or replace function public.whoami(p_token text)
 returns json language sql security definer set search_path to ''
as $function$
  select json_build_object('name',name,'email',email,'status',status,'is_admin',is_admin,'role',role,'has_proof',proof_path is not null,'terms_version',terms_version,
    'reminder_due', (not is_admin) and (reminder_seen_at is null or reminder_seen_at < now() - interval '30 days'),
    'bcc_email', case when status = 'approved' then (select value from public.app_settings where key = 'bcc_email') else '' end,
    'bcc_opt_out', bcc_opt_out, 'bcc_ack', bcc_ack,
    'phone', phone,
    'bookings', status = 'approved' and (is_admin or coalesce((select value from public.app_settings where key = 'bookings_for'),'') = 'all'),
    'bookings_for', case when is_admin then coalesce((select value from public.app_settings where key = 'bookings_for'),'admin') else '' end)
  from public.members where token_hash = public._hash(p_token);
$function$;

-- set_setting: Eretz Israel Tours can open booking sheets to all colleagues (bookings_for = 'all') or keep them to itself ('admin').
create or replace function public.set_setting(p_token text, p_key text, p_value text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email','bookings_for') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  if p_key = 'bookings_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  insert into public.app_settings (key, value) values (p_key, lower(trim(p_value))) on conflict (key) do update set value = excluded.value;
end $function$;
