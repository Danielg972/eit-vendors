-- D-55 (16 Oct 2026): food nearby gets "Kosher, certificate not checked", a pin on the map, food courts with their
-- places, and a "Problem?" report that reaches Eretz Israel Tours and the person who added the tip.
-- Adds only: two columns on vendor_food, one column on vendor_reports, two new tables, new functions, and new
-- versions of food_list and vendor_reports_list (same arguments, more fields). No table grants, no policies.
-- Nothing is deleted or dropped. Safe to run twice.

-- 1. A food tip can carry a pin ("31.771234,35.217654") and point at a food court on the list.
alter table public.vendor_food add column if not exists ll text not null default '';
alter table public.vendor_food add column if not exists court_id text references public.vendors(id) on delete set null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'vendor_food_ll_check') then
    alter table public.vendor_food add constraint vendor_food_ll_check check (ll = '' or ll ~ '^-?[0-9]{1,2}\.[0-9]{1,7},-?[0-9]{1,3}\.[0-9]{1,7}$');
  end if; end $$;

-- 2. The places inside a food court. The food court is a supplier (category Restaurant, type "Food court").
create table if not exists public.vendor_places (
  id uuid default gen_random_uuid() not null primary key,
  vendor_id text not null references public.vendors(id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 120),
  kosher text not null default '' check (length(kosher) <= 120),
  note text not null default '' check (length(note) <= 200),
  author text not null,
  author_name text not null default '',
  created_at timestamptz not null default now()
);
alter table public.vendor_places enable row level security;
create index if not exists vendor_places_vendor_idx on public.vendor_places (vendor_id);

-- 3. A report can be about one food tip.
alter table public.vendor_reports add column if not exists food_id uuid references public.vendor_food(id) on delete set null;

-- 4. Alerts a member sees in the app the next time he opens it (no email: D-5 is still open).
create table if not exists public.member_alerts (
  id uuid default gen_random_uuid() not null primary key,
  to_email text not null,
  kind text not null default 'report',
  message text not null default '' check (length(message) <= 2000),
  vendor_id text references public.vendors(id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
alter table public.member_alerts enable row level security;
create index if not exists member_alerts_to_idx on public.member_alerts (to_email) where read_at is null;

-- The kosher rule for tips and places (B7, D-7, D-8): never not kosher; "Kosher, no certificate" only by Eretz
-- Israel Tours. "Kosher, certificate not checked" is accepted from anyone (D-55).
create or replace function public._food_kosher_ok(p_kosher text, p_admin boolean)
 returns void language plpgsql immutable set search_path to '' as $function$
begin
  if coalesce(p_kosher,'') ~* '^\s*(not kosher|non[- ]?kosher|kosher[- ]style)' then raise exception 'Kosher places only.'; end if;
  if not p_admin and coalesce(p_kosher,'') ~* '^\s*kosher\W+(no|without)\s+(certificate|certification|teuda|teudah|hechsher)' then
    raise exception 'Kosher without a certificate is added only by Eretz Israel Tours. Choose "Kosher, certificate not checked" if it has one and you are not sure which.'; end if;
end $function$;

create or replace function public._ll_clean(p_ll text)
 returns text language sql immutable set search_path to '' as $function$
  select case when coalesce(p_ll,'') ~ '^\s*-?[0-9]{1,2}\.[0-9]+\s*,\s*-?[0-9]{1,3}\.[0-9]+\s*$'
    then round(split_part(p_ll,',',1)::numeric,6)::text || ',' || round(split_part(p_ll,',',2)::numeric,6)::text else '' end
$function$;

-- A food court the member may see: on the list, not hidden, in his sections.
create or replace function public._court_ok(m public.members, p_court text)
 returns boolean language sql stable security definer set search_path to '' as $function$
  select p_court is not null and exists (select 1 from public.vendors v where v.id = p_court
    and (m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories))))
$function$;

create or replace function public._places_json(p_court text, m public.members)
 returns json language sql stable security definer set search_path to '' as $function$
  select coalesce(json_agg(json_build_object('id',p.id,'name',p.name,'kosher',p.kosher,'note',p.note,'by',public._who(p.author),
    'mine',p.author=m.email,'created_at',p.created_at) order by p.created_at), '[]'::json)
  from public.vendor_places p where p.vendor_id = p_court
$function$;

-- New version of food_list: also the pin, the food court and its places.
CREATE OR REPLACE FUNCTION public.food_list(p_token text, p_vendor text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  return coalesce((select json_agg(json_build_object('id',f.id,'name',f.name,'kosher',f.kosher,'note',f.note,'by',public._who(f.author),'mine',f.author=m.email,'created_at',f.created_at,
      'll',f.ll,'court_id',case when public._court_ok(m, f.court_id) then f.court_id end,
      'places',case when public._court_ok(m, f.court_id) then public._places_json(f.court_id, m) end) order by f.created_at desc)
    from public.vendor_food f where f.vendor_id = p_vendor), '[]'::json);
end $function$
;

-- Adding a tip, with pin and food court. The old food_add stays for copies of the app from before D-55.
create or replace function public.food_add2(p_token text, p_vendor text, p_name text, p_kosher text, p_note text, p_ll text default '', p_court text default null)
 returns uuid language plpgsql security definer set search_path to '' as $function$
declare m public.members; i uuid;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  perform public._food_kosher_ok(p_kosher, m.is_admin);
  if p_court is not null and not public._court_ok(m, p_court) then raise exception 'That food court is not available.'; end if;
  if (select count(*) from public.vendor_food where author = m.email and created_at > now() - interval '1 hour') > 30 then raise exception 'Too many in a short time. Try again later.'; end if;
  insert into public.vendor_food (vendor_id, name, kosher, note, author, author_name, ll, court_id)
  values (p_vendor, trim(p_name), trim(coalesce(p_kosher,'')), trim(coalesce(p_note,'')), m.email, m.name, public._ll_clean(p_ll), p_court) returning id into i;
  return i;
end $function$;

-- The author (or Eretz Israel Tours) sets or changes a tip's pin.
create or replace function public.food_set_ll(p_token text, p_id uuid, p_ll text)
 returns void language plpgsql security definer set search_path to '' as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  update public.vendor_food set ll = public._ll_clean(p_ll) where id = p_id and (author = m.email or m.is_admin);
  if not found then raise exception 'Only the person who added the tip can move its pin.'; end if;
end $function$;

-- The places inside a food court.
create or replace function public.places_list(p_token text, p_vendor text)
 returns json language plpgsql security definer set search_path to '' as $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  return public._places_json(p_vendor, m);
end $function$;

create or replace function public.place_add(p_token text, p_vendor text, p_name text, p_kosher text, p_note text)
 returns void language plpgsql security definer set search_path to '' as $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if not exists (select 1 from public.vendors v where v.id = p_vendor) then raise exception 'That supplier no longer exists.'; end if;
  perform public._food_kosher_ok(p_kosher, m.is_admin);
  if (select count(*) from public.vendor_places where author = m.email and created_at > now() - interval '1 hour') > 40 then raise exception 'Too many in a short time. Try again later.'; end if;
  if exists (select 1 from public.vendor_places where vendor_id = p_vendor and lower(trim(name)) = lower(trim(p_name))) then raise exception 'That place is already listed here.'; end if;
  insert into public.vendor_places (vendor_id, name, kosher, note, author, author_name)
  values (p_vendor, trim(p_name), trim(coalesce(p_kosher,'')), trim(coalesce(p_note,'')), m.email, m.name);
end $function$;

create or replace function public.place_delete(p_token text, p_id uuid)
 returns void language plpgsql security definer set search_path to '' as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  delete from public.vendor_places where id = p_id and (author = m.email or m.is_admin);
end $function$;

-- "Problem?" on a food tip, or on a food court's page. Goes to Eretz Israel Tours' Supplier updates, and as an alert
-- to the person who added the tip (or the food court). The person who added it sees "a colleague", never a name.
create or replace function public.flag_problem(p_token text, p_vendor text, p_food uuid, p_kind text, p_message text)
 returns void language plpgsql security definer set search_path to '' as $function$
declare m public.members; f public.vendor_food; k text; what text; to_e text; vname text;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if (select count(*) from public.vendor_reports where author = m.email and created_at > now() - interval '1 hour') > 20 then raise exception 'Too many reports in a short time. Try again later.'; end if;
  k := case p_kind when 'Closed' then 'Closed' when 'Wrong place' then 'Moved' when 'Mistake' then 'Mistake' else 'Other' end;
  what := case p_kind when 'Not kosher' then 'Not kosher' when 'Wrong place' then 'Wrong place' when 'Closed' then 'Closed' else 'Problem' end;
  select name into vname from public.vendors where id = p_vendor;
  if p_food is not null then
    select * into f from public.vendor_food where id = p_food and vendor_id = p_vendor;
    if f.id is null then raise exception 'That tip is no longer there.'; end if;
    to_e := f.author;
    insert into public.vendor_reports (vendor_id, kind, message, author, author_name, food_id)
    values (p_vendor, k, left('Food tip "' || f.name || '": ' || what || case when trim(coalesce(p_message,'')) <> '' then '. ' || trim(p_message) else '' end, 2000), m.email, m.name, f.id);
    if to_e is not null and to_e <> m.email then
      insert into public.member_alerts (to_email, kind, message, vendor_id) values (to_e, 'food', left('A colleague flagged your food tip "' || f.name || '" on ' || coalesce(vname,'a supplier') || ': ' || what || case when trim(coalesce(p_message,'')) <> '' then '. ' || trim(p_message) else '' end, 2000), p_vendor);
    end if;
  else
    insert into public.vendor_reports (vendor_id, kind, message, author, author_name)
    values (p_vendor, k, left(what || case when trim(coalesce(p_message,'')) <> '' then '. ' || trim(p_message) else '' end, 2000), m.email, m.name);
    -- whoever added this food court
    select created_by into to_e from public.vendors where id = p_vendor;
    if to_e is null or to_e not like '%@%' then select author into to_e from public.vendor_food where court_id = p_vendor order by created_at limit 1; end if;
    if to_e is not null and to_e <> m.email then
      insert into public.member_alerts (to_email, kind, message, vendor_id) values (to_e, 'court', left('A colleague flagged the food court you added, ' || coalesce(vname,'') || ': ' || what || case when trim(coalesce(p_message,'')) <> '' then '. ' || trim(p_message) else '' end, 2000), p_vendor);
    end if;
  end if;
end $function$;

-- A member's own unread alerts, and marking them read.
create or replace function public.my_alerts(p_token text)
 returns json language plpgsql security definer set search_path to '' as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(json_build_object('id',a.id,'kind',a.kind,'message',a.message,'vendor_id',a.vendor_id,'created_at',a.created_at) order by a.created_at desc)
    from public.member_alerts a where a.to_email = m.email and a.read_at is null), '[]'::json);
end $function$;

create or replace function public.alerts_read(p_token text)
 returns void language plpgsql security definer set search_path to '' as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  update public.member_alerts set read_at = now() where to_email = m.email and read_at is null;
end $function$;

-- New version of vendor_reports_list: also says which food tip a report is about.
CREATE OR REPLACE FUNCTION public.vendor_reports_list(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',r.id,'vendor_id',r.vendor_id,'vendor_name',v.name,'kind',r.kind,'message',r.message,'anonymous',r.anonymous,
    'author_name',case when r.anonymous then '' else r.author_name end,'author',case when r.anonymous then '' else r.author end,'status',r.status,'by_owner',r.by_owner,'created_at',r.created_at,
    'food_id',r.food_id) order by (r.status='New') desc, r.created_at desc)
    from public.vendor_reports r join public.vendors v on v.id = r.vendor_id where r.status = 'New' or r.created_at > now() - interval '30 days'), '[]'::json);
end $function$
;

-- Only the app's own link-checked calls reach these (rule: no table grants, no policies).
revoke all on table public.vendor_places, public.member_alerts from public, anon, authenticated;
grant all on table public.vendor_places, public.member_alerts to service_role;
revoke all on function public._food_kosher_ok(text, boolean), public._ll_clean(text), public._court_ok(public.members, text), public._places_json(text, public.members) from public, anon, authenticated;
revoke all on function public.food_add2(text, text, text, text, text, text, text), public.food_set_ll(text, uuid, text), public.places_list(text, text),
  public.place_add(text, text, text, text, text), public.place_delete(text, uuid), public.flag_problem(text, text, uuid, text, text),
  public.my_alerts(text), public.alerts_read(text) from public;
grant execute on function public.food_add2(text, text, text, text, text, text, text), public.food_set_ll(text, uuid, text), public.places_list(text, text),
  public.place_add(text, text, text, text, text), public.place_delete(text, uuid), public.flag_problem(text, text, uuid, text, text),
  public.my_alerts(text), public.alerts_read(text) to anon, authenticated;
