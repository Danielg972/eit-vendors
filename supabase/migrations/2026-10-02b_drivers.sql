-- Driver reviews (2 Oct 2026). See docs/DECISIONS.md D-3. Run after 2026-10-02_quote_tracker.sql.
-- supabase/schema.sql already includes everything below; this file is the step-by-step change.
-- Safe to run twice.

-- "Coach" is now "Bus" everywhere (owner's wording). Existing supplier tags follow.
do $$ begin
  perform set_config('app.editor','system',true); perform set_config('app.admin','on',true);
  update public.vendors set tags = regexp_replace(tags, '\mCoach\M', 'Bus', 'g') where tags ~ '\mCoach\M';
end $$;

-- One driver = one phone number. The number is how colleagues know it is the same driver.
create or replace function public._phone_norm(p text)
 returns text language sql immutable set search_path to ''
as $function$
  select case when d like '00972%' then '0' || substr(d, 6) when d like '972%' and length(d) >= 11 then '0' || substr(d, 4) else d end
  from (select regexp_replace(coalesce(p,''), '\D', '', 'g') d) x
$function$;
revoke all on function public._phone_norm(text) from public, anon, authenticated;

create table if not exists public.drivers (
  id uuid default gen_random_uuid() not null,
  name text not null,
  phone text not null,
  phone_norm text not null,
  drives text default ''::text not null,
  created_by text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint drivers_pkey primary key (id),
  constraint drivers_phone_norm_key unique (phone_norm),
  constraint drivers_name_check check (length(trim(both from name)) >= 1 and length(trim(both from name)) <= 80),
  constraint drivers_phone_check check (length(phone) <= 40),
  constraint drivers_phone_norm_check check (phone_norm ~ '^\d{7,15}$'),
  constraint drivers_drives_check check (length(drives) <= 120)
);
alter table public.drivers enable row level security;

-- Which companies a driver drives for. A driver can be on more than one.
create table if not exists public.driver_vendors (
  driver_id uuid not null,
  vendor_id text not null,
  added_by text not null,
  created_at timestamp with time zone default now() not null,
  constraint driver_vendors_pkey primary key (driver_id, vendor_id),
  constraint driver_vendors_driver_id_fkey foreign key (driver_id) references public.drivers(id) on delete cascade,
  constraint driver_vendors_vendor_id_fkey foreign key (vendor_id) references public.vendors(id) on delete cascade
);
alter table public.driver_vendors enable row level security;
create index if not exists driver_vendors_vendor_idx on public.driver_vendors using btree (vendor_id);

create table if not exists public.driver_reviews (
  id uuid default gen_random_uuid() not null,
  driver_id uuid not null,
  vendor_id text,
  rating text not null,
  tags text default ''::text not null,
  body text default ''::text not null,
  trip_month text default ''::text not null,
  author text not null,
  author_name text default ''::text not null,
  created_at timestamp with time zone default now() not null,
  constraint driver_reviews_pkey primary key (id),
  constraint driver_reviews_driver_id_fkey foreign key (driver_id) references public.drivers(id) on delete cascade,
  constraint driver_reviews_vendor_id_fkey foreign key (vendor_id) references public.vendors(id) on delete set null,
  constraint driver_reviews_rating_check check (rating = any (array['1','2','3','4','5'])),
  constraint driver_reviews_tags_check check (length(tags) <= 300),
  constraint driver_reviews_body_check check (length(body) <= 1500),
  constraint driver_reviews_trip_month_check check (trip_month = '' or trip_month ~ '^\d{4}-\d{2}$')
);
alter table public.driver_reviews enable row level security;
create index if not exists driver_reviews_driver_idx on public.driver_reviews using btree (driver_id);

-- Tables are closed: RLS on, no policies, no grants. All access goes through the functions below.
revoke all on table public.drivers, public.driver_vendors, public.driver_reviews from anon, authenticated;

-- A driver with his reviews. Reviewers appear by name and role only (never email). Hidden suppliers are not named to colleagues.
create or replace function public._driver_json(d public.drivers, p_email text, p_admin boolean)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',d.id,'name',d.name,'phone',d.phone,'drives',d.drives,
    'can_edit', p_admin or d.created_by = p_email,
    'n',(select count(*) from public.driver_reviews r where r.driver_id = d.id),
    'avg',(select round(avg(r.rating::int)::numeric, 1) from public.driver_reviews r where r.driver_id = d.id),
    'vendors',coalesce((select json_agg(json_build_object('id',v.id,'name',v.name) order by v.name)
        from public.driver_vendors dv join public.vendors v on v.id = dv.vendor_id where dv.driver_id = d.id and (p_admin or not v.hidden)),'[]'::json),
    'reviews',coalesce((select json_agg(json_build_object('id',r.id,'rating',r.rating,'tags',r.tags,'body',r.body,'trip_month',r.trip_month,
          'vendor_id',case when v.id is not null and (p_admin or not v.hidden) then v.id end,
          'vendor_name',case when v.id is not null and (p_admin or not v.hidden) then v.name end,
          'by',public._who(r.author),'mine',r.author = p_email,'created_at',r.created_at) order by r.created_at desc)
        from public.driver_reviews r left join public.vendors v on v.id = r.vendor_id where r.driver_id = d.id),'[]'::json))
$function$;
revoke all on function public._driver_json(public.drivers, text, boolean) from public, anon, authenticated;

-- The drivers of one supplier.
create or replace function public.drivers_list(p_token text, p_vendor text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  return coalesce((select json_agg(public._driver_json(d, m.email, m.is_admin) order by d.name)
    from public.drivers d join public.driver_vendors dv on dv.driver_id = d.id where dv.vendor_id = p_vendor), '[]'::json);
end $function$;

-- Is this phone number already on the list? Returns the driver, or null.
create or replace function public.driver_find(p_token text, p_phone text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; d public.drivers;
begin
  m := public._auth(p_token);
  select * into d from public.drivers where phone_norm = public._phone_norm(p_phone);
  if d.id is null then return null; end if;
  return public._driver_json(d, m.email, m.is_admin);
end $function$;

-- Add a driver to a supplier. If the phone number is already on the list, that same driver is linked, not duplicated.
-- With an id: change the driver's details (the person who added him, or Eretz Israel Tours).
create or replace function public.driver_save(p_token text, p_vendor text, p_driver jsonb)
 returns uuid language plpgsql security definer set search_path to ''
as $function$
declare m public.members; d public.drivers; did uuid := nullif(p_driver->>'id','')::uuid;
  nm text := trim(left(coalesce(p_driver->>'name',''),80)); ph text := trim(left(coalesce(p_driver->>'phone',''),40));
  pn text := public._phone_norm(p_driver->>'phone'); dr text := trim(left(coalesce(p_driver->>'drives',''),120));
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if not exists (select 1 from public.vendors where id = p_vendor) then raise exception 'That supplier no longer exists.'; end if;
  if pn !~ '^\d{7,15}$' then raise exception 'Enter the driver''s phone number. It is how colleagues know it is the same driver.'; end if;
  if did is not null then
    select * into d from public.drivers where id = did;
    if d.id is null then raise exception 'That driver is no longer on the list.'; end if;
    if not (m.is_admin or d.created_by = m.email) then raise exception 'Only the person who added this driver, or Eretz Israel Tours, can change his details.'; end if;
    if nm = '' then raise exception 'Enter the driver''s name.'; end if;
    if exists (select 1 from public.drivers where phone_norm = pn and id <> did) then raise exception 'That phone number already belongs to another driver on the list.'; end if;
    update public.drivers set name = nm, phone = ph, phone_norm = pn, drives = dr, updated_at = now() where id = did;
  else
    select id into did from public.drivers where phone_norm = pn;
    if did is null then
      if nm = '' then raise exception 'Enter the driver''s name.'; end if;
      insert into public.drivers (name, phone, phone_norm, drives, created_by) values (nm, ph, pn, dr, m.email) returning id into did;
    end if;
  end if;
  insert into public.driver_vendors (driver_id, vendor_id, added_by) values (did, p_vendor, m.email) on conflict do nothing;
  return did;
end $function$;

-- Review a driver. p_vendor is the company he drove for on that trip (optional).
create or replace function public.driver_review_add(p_token text, p_driver uuid, p_vendor text, p_review jsonb)
 returns uuid language plpgsql security definer set search_path to ''
as $function$
declare m public.members; rid uuid; vid text := nullif(p_vendor,'');
begin
  m := public._auth(p_token);
  if not exists (select 1 from public.drivers where id = p_driver) then raise exception 'That driver is no longer on the list.'; end if;
  if coalesce(p_review->>'rating','') !~ '^[1-5]$' then raise exception 'Give a rating from 1 to 5.'; end if;
  if vid is not null then
    perform public._visible(vid, m.is_admin);
    if not exists (select 1 from public.vendors where id = vid) then raise exception 'That supplier no longer exists.'; end if;
    insert into public.driver_vendors (driver_id, vendor_id, added_by) values (p_driver, vid, m.email) on conflict do nothing;
  end if;
  insert into public.driver_reviews (driver_id, vendor_id, rating, tags, body, trip_month, author, author_name)
  values (p_driver, vid, p_review->>'rating', left(trim(coalesce(p_review->>'tags','')),300), left(trim(coalesce(p_review->>'body','')),1500),
    case when coalesce(p_review->>'trip_month','') ~ '^\d{4}-\d{2}$' then p_review->>'trip_month' else '' end, m.email, m.name)
  returning id into rid;
  return rid;
end $function$;

create or replace function public.driver_review_delete(p_token text, p_id uuid)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  delete from public.driver_reviews where id = p_id and (author = m.email or m.is_admin);
end $function$;

-- Take a driver off a supplier (Eretz Israel Tours, or whoever linked him there). With no supplier: remove the driver
-- and all his reviews (Eretz Israel Tours only).
create or replace function public.driver_remove(p_token text, p_driver uuid, p_vendor text)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if coalesce(p_vendor,'') = '' then
    if not m.is_admin then raise exception 'Only Eretz Israel Tours can do that.' using errcode = '42501'; end if;
    delete from public.drivers where id = p_driver;
  else
    delete from public.driver_vendors where driver_id = p_driver and vendor_id = p_vendor and (m.is_admin or added_by = m.email);
    if not found then raise exception 'Only Eretz Israel Tours, or the person who added him here, can take a driver off this supplier.'; end if;
  end if;
end $function$;

revoke all on function public.drivers_list(text,text) from public; grant execute on function public.drivers_list(text,text) to anon, authenticated;
revoke all on function public.driver_find(text,text) from public; grant execute on function public.driver_find(text,text) to anon, authenticated;
revoke all on function public.driver_save(text,text,jsonb) from public; grant execute on function public.driver_save(text,text,jsonb) to anon, authenticated;
revoke all on function public.driver_review_add(text,uuid,text,jsonb) from public; grant execute on function public.driver_review_add(text,uuid,text,jsonb) to anon, authenticated;
revoke all on function public.driver_review_delete(text,uuid) from public; grant execute on function public.driver_review_delete(text,uuid) to anon, authenticated;
revoke all on function public.driver_remove(text,uuid,text) from public; grant execute on function public.driver_remove(text,uuid,text) to anon, authenticated;
