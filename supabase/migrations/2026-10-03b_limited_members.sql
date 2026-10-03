-- Limited members: organisations that are not in tourism (decision D-12, 3 Oct 2026).
-- People who book busses, guides or hotels for a school, a yeshiva or another organisation join as LIMITED members.
-- Eretz Israel Tours chooses, per member, which sections of the list they see. The rules are enforced here, in the
-- database, not only hidden in the app:
--   1. members.member_type ('full' | 'limited'), members.sections (comma list of transport, guides, hotels, sites, food,
--      other), and four switches: see_quotes (bus and van quotes, booking sheets), see_guide_rates, see_transport_reviews,
--      see_reviews (guides' and agents' reviews outside transport). members.org and members.credentials hold what an
--      organisation wrote when it asked to join (free text instead of a license).
--   2. A limited member never receives an agent price: not vendors.agentPrice, not a price line marked is_agent, not the
--      agent sign-up link or how-to, and not a guide's or agent's quote outside the cases its switches allow.
--   3. What a limited member adds is shown to everyone, limited members too: price lines ("organisation rates"), quotes,
--      notes ("reviews", with an optional 1-5 rating) and driver reviews. Each is stamped org = true when it is written.
--      Organisation rates and quotes are shown without the name; Eretz Israel Tours sees who added them.
--   4. Limited members get no Jobs tab, and booking sheets only with the transport section and see_quotes.
--   5. New RPCs: member_set_access (admin), request_access_org (an organisation asks to join) and review_add (a note
--      with an optional rating). request_access and note_add keep their signatures, so a copy of the app from before
--      this change keeps working. An organisation is stored with role 'Other' and its name in members.org: the name
--      is what marks it (the role check on members is left as it is).
--   6. A quote is stamped org by a trigger on insert, so quote_save and the booking-sheet code are not touched.
-- Needs the jobs change (2026-10-03_jobs.sql: _csv_keys, _jobs_on, _jobs_post, _job_fits, whoami with jobs).
-- This file only adds and replaces: it removes no column, constraint, function or row, and none of the functions it
-- replaces removes rows. price_delete, quote_save, request_access, member_decide and the booking code are untouched.
-- Safe to run twice.

begin;

-- ===== 1. Columns =====
alter table public.members add column if not exists member_type text default 'full'::text not null;
alter table public.members add column if not exists sections text default ''::text not null;
alter table public.members add column if not exists see_quotes boolean default true not null;
alter table public.members add column if not exists see_guide_rates boolean default false not null;
alter table public.members add column if not exists see_transport_reviews boolean default true not null;
alter table public.members add column if not exists see_reviews boolean default false not null;
alter table public.members add column if not exists org text default ''::text not null;
alter table public.members add column if not exists credentials text default ''::text not null;
alter table public.vendor_notes add column if not exists org boolean default false not null;
alter table public.vendor_notes add column if not exists rating text default ''::text not null;
alter table public.driver_reviews add column if not exists org boolean default false not null;
alter table public.vendor_prices add column if not exists org boolean default false not null;
alter table public.quotes add column if not exists org boolean default false not null;
alter table public.vendor_files add column if not exists org boolean default false not null;

do $do$ begin
  if not exists (select 1 from pg_constraint where conname = 'members_access_check' and conrelid = 'public.members'::regclass) then
    alter table public.members add constraint members_access_check CHECK (((member_type = ANY (ARRAY['full'::text, 'limited'::text])) AND (sections ~ '^((transport|guides|hotels|sites|food|other)(,(transport|guides|hotels|sites|food|other))*)?$'::text) AND (length(org) <= 120) AND (length(credentials) <= 1000)));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'vendor_notes_rating_check' and conrelid = 'public.vendor_notes'::regclass) then
    alter table public.vendor_notes add constraint vendor_notes_rating_check CHECK ((rating = ANY (ARRAY[''::text, '1'::text, '2'::text, '3'::text, '4'::text, '5'::text])));
  end if;
end $do$;

-- ===== 2. Helpers (not RPCs) =====

-- _auth also remembers WHICH member is calling (app.member), so the helpers below can apply that member's access.
CREATE OR REPLACE FUNCTION public._auth(p_token text, p_admin boolean DEFAULT false)
 RETURNS members
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  select * into m from public.members where token_hash = public._hash(p_token) and status = 'approved';
  if m.id is null then raise exception 'Your link is not active. Ask Eretz Israel Tours for a new one.' using errcode = '28000'; end if;
  if p_admin and not m.is_admin then raise exception 'Only Eretz Israel Tours can do that.' using errcode = '42501'; end if;
  perform set_config('app.editor', m.email, true);
  perform set_config('app.admin', case when m.is_admin then 'on' else 'off' end, true);
  perform set_config('app.member', m.id::text, true);
  update public.members set last_seen_at = now() where id = m.id and (last_seen_at is null or last_seen_at < now() - interval '10 minutes');
  return m;
end $function$;

-- The member behind this call, as _auth saw him. Null before _auth has run.
create or replace function public._me()
 returns public.members language sql stable security definer set search_path to ''
as $function$
  select m from public.members m where m.id = nullif(current_setting('app.member', true), '')::uuid
$function$;

-- Which section of the list a category belongs to.
create or replace function public._section_of(p_category text)
 returns text language sql immutable set search_path to ''
as $function$
  select case p_category when 'Transport' then 'transport' when 'Guide' then 'guides' when 'Hotel' then 'hotels'
    when 'Restaurant' then 'food' when 'Winery' then 'food'
    when 'Attraction / Site' then 'sites' when 'Activity' then 'sites' when 'Adventure' then 'sites' when 'National Parks' then 'sites'
    else 'other' end
$function$;

-- A limited member: an organisation that is not in tourism. Eretz Israel Tours is never limited.
create or replace function public._limited(m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select coalesce(m.member_type = 'limited' and not m.is_admin, false)
$function$;

-- May this member see a supplier of this category (main, or one of its "also offers")?
create or replace function public._can_see(m public.members, p_category text, p_also text)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when not public._limited(m) then true
    else exists (select 1 from unnest(array[coalesce(p_category,'')] || string_to_array(coalesce(p_also,''), ',')) c
                 where trim(c) <> '' and public._section_of(trim(c)) = any (string_to_array(m.sections, ','))) end
$function$;

-- Does this member read guides' and agents' reviews on a supplier of this category?
-- Transport has its own switch (drivers, bus companies, van drivers); everything else follows see_reviews.
create or replace function public._reviews_open(m public.members, p_category text, p_also text)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when not public._limited(m) then true
    when p_category = 'Transport' or coalesce(p_also,'') ~* '(^|,)\s*Transport\s*(,|$)' then m.see_transport_reviews
    else m.see_reviews end
$function$;

-- One price line, for one member.
--   Own lines always. Private lines and private-price suppliers: owner and Eretz Israel Tours only.
--   Organisation rates (org): everyone. Another member's personal line: nobody else.
--   A limited member: no agent rates, and no prices at all on a guide unless see_guide_rates.
create or replace function public._price_visible(p public.vendor_prices, v public.vendors, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when coalesce(m.is_admin, false) then true
    when p.owner <> '' and p.owner = m.email then true
    when v.prices_private or p.private then false
    when p.org then true
    when p.owner <> '' then false
    when public._limited(m) then (not p.is_agent) and not (v.category = 'Guide' and not m.see_guide_rates)
    else true end
$function$;

-- One note, for one member. A limited member reads notes written by organisations, his own, what was copied from the
-- supplier's website, and everything else only where his switches open guides' and agents' reviews.
create or replace function public._note_visible(n public.vendor_notes, v public.vendors, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select not public._limited(m) or n.org or n.author = m.email or n.author like 'import from websites%'
    or public._reviews_open(m, v.category, v.also_categories)
$function$;

-- A file on a supplier, for a limited member: his own, another organisation's, or a photo or kosher certificate.
-- Price lists, receipts, contracts, booking confirmations and quotes from guides and agents can carry agent rates.
create or replace function public._file_visible(f public.vendor_files, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when coalesce(m.is_admin, false) or f.uploaded_by = m.email then true
    when f.private then false
    when public._limited(m) then f.org or f.kind in ('Photo','Kosher certificate')
    else true end
$function$;

-- For the files edge function (service key): may this member open this supplier's files, and is he limited?
create or replace function public._file_scope(p_member uuid, p_vendor text)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('can_see', m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories)),
    'limited', public._limited(m))
  from public.members m, public.vendors v where m.id = p_member and v.id = p_vendor
$function$;

-- Is a quote a transport quote, a guide quote, or something else?
create or replace function public._quote_kind(q public.quotes, v public.vendors)
 returns text language sql stable security definer set search_path to ''
as $function$
  select case
    when v.category = 'Guide' or exists (select 1 from public.quote_options o where o.quote_id = q.id and o.service in ('guide','guide_vehicle')) then 'guide'
    when v.category = 'Transport' or (exists (select 1 from public.quote_options o where o.quote_id = q.id)
      and not exists (select 1 from public.quote_options o where o.quote_id = q.id
        and o.service <> all (array['bus','midibus','van20','van16','van10','van8','car','jeep_vehicle','transfer']))) then 'transport'
    else 'other' end
$function$;

-- One quote, for one member (the supplier itself must already be visible to him, and not hidden).
--   Owner and Eretz Israel Tours: always. Not shared, or a private-price supplier: nobody else.
--   Full members: every shared quote. Limited members: quotes from organisations, bus and van quotes with see_quotes,
--   guide quotes with see_guide_rates. Never another guide's or agent's quote for a hotel, a site or an activity.
create or replace function public._quote_visible(q public.quotes, v public.vendors, m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select case when coalesce(m.is_admin, false) then true
    when public._limited(m) and not public._can_see(m, v.category, v.also_categories) then false
    when q.owner = m.email then true
    when not q.shared or v.prices_private then false
    when not public._limited(m) then true
    when q.org then true
    when public._quote_kind(q, v) = 'transport' then m.see_quotes and 'transport' = any (string_to_array(m.sections, ','))
    when public._quote_kind(q, v) = 'guide' then m.see_guide_rates and 'guides' = any (string_to_array(m.sections, ','))
    else false end
$function$;

-- A hidden supplier is for Eretz Israel Tours only; a limited member also needs the supplier's section.
CREATE OR REPLACE FUNCTION public._visible(p_vendor text, p_admin boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.vendors; m public.members;
begin
  if p_admin then return; end if;
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then return; end if;
  if v.hidden then raise exception 'That supplier is not available.'; end if;
  m := public._me();
  if not public._can_see(m, v.category, v.also_categories) then raise exception 'That supplier is not available.'; end if;
end $function$;

-- A supplier as one member (not Eretz Israel Tours) receives it.
create or replace function public._vendor_for(v public.vendors, m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select (public._vendor_json(v.id)::jsonb
      || case when v.prices_private then jsonb_build_object('agentPrice','','listedPrice','','agentPriceVatTreatment','','listedPriceVatTreatment','','maxPax','') else '{}'::jsonb end
      || case when x.lim then jsonb_build_object('agentPrice','','agentPriceVatTreatment','','agent_link','','agent_howto','') else '{}'::jsonb end
      || case when x.lim and v.category = 'Guide' and not m.see_guide_rates then jsonb_build_object('listedPrice','','listedPriceVatTreatment','','maxPax','') else '{}'::jsonb end
      || case when x.lim and not x.rev then jsonb_build_object('rateReliability','','rateService','','rateValue','','strengths','','weaknesses','','notes','') else '{}'::jsonb end
      || case when x.lim then jsonb_build_object(
           '_files', (select count(*) from public.vendor_files f where f.vendor_id = v.id and f.quote_id is null and public._file_visible(f, m)),
           '_notes', (select count(*) from public.vendor_notes n where n.vendor_id = v.id and public._note_visible(n, v, m))) else '{}'::jsonb end
      || jsonb_build_object('_prices', (select count(*) from public.vendor_prices p where p.vendor_id = v.id and public._price_visible(p, v, m)),
           'created_by', public._name(v.created_by), 'updated_by', public._name(v.updated_by), 'hours_verified_by', public._name(v.hours_verified_by))
    )::json
  from (select public._limited(m) as lim, public._reviews_open(m, v.category, v.also_categories) as rev) x
$function$;

CREATE OR REPLACE FUNCTION public._vendor_view(p_id text, p_admin boolean, p_email text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v public.vendors; m public.members;
begin
  select * into v from public.vendors where id = p_id;
  if v.id is null then return null; end if;
  if p_admin then
    return (public._vendor_json(p_id)::jsonb || jsonb_build_object('_prices',(select count(*) from public.vendor_prices p where p.vendor_id=p_id)))::json;
  end if;
  m := public._me();
  if m.id is null or m.email is distinct from p_email then
    select * into m from public.members mm where mm.email = p_email order by mm.created_at limit 1;
  end if;
  return public._vendor_for(v, m);
end $function$;

-- Who wrote something: name and role. An organisation shows its own name in place of a role.
CREATE OR REPLACE FUNCTION public._who(p_email text)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when p_email is null or p_email in ('','import','system') or p_email like 'import from%' then null
    else coalesce((select json_build_object('name',m.name,
          'role',case when m.org <> '' then m.org else m.role end,
          'admin',m.is_admin,'org',public._limited(m))
        from public.members m where m.email = split_part(p_email,' (',1) order by m.created_at limit 1),
                  json_build_object('name','A colleague','role','','admin',false)) end
$function$;

-- A driver with his reviews. A limited member without see_transport_reviews reads only organisations' reviews and his own.
CREATE OR REPLACE FUNCTION public._driver_json(d drivers, p_email text, p_admin boolean)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select json_build_object('id',d.id,'name',d.name,'phone',d.phone,'drives',d.drives,
    'can_edit', p_admin or d.created_by = p_email,
    'n',(select count(*) from public.driver_reviews r where r.driver_id = d.id and (x.every or r.org or r.author = p_email)),
    'avg',(select round(avg(r.rating::int)::numeric, 1) from public.driver_reviews r where r.driver_id = d.id and (x.every or r.org or r.author = p_email)),
    'some_hidden', not x.every,
    'vendors',coalesce((select json_agg(json_build_object('id',v.id,'name',v.name) order by v.name)
        from public.driver_vendors dv join public.vendors v on v.id = dv.vendor_id
        where dv.driver_id = d.id and (p_admin or (not v.hidden and public._can_see(x.m, v.category, v.also_categories)))),'[]'::json),
    'reviews',coalesce((select json_agg(json_build_object('id',r.id,'rating',r.rating,'tags',r.tags,'body',r.body,'trip_month',r.trip_month,
          'vendor_id',case when v.id is not null and (p_admin or (not v.hidden and public._can_see(x.m, v.category, v.also_categories))) then v.id end,
          'vendor_name',case when v.id is not null and (p_admin or (not v.hidden and public._can_see(x.m, v.category, v.also_categories))) then v.name end,
          'by',public._who(r.author),'mine',r.author = p_email,'org',r.org,'created_at',r.created_at) order by r.created_at desc)
        from public.driver_reviews r left join public.vendors v on v.id = r.vendor_id
        where r.driver_id = d.id and (x.every or r.org or r.author = p_email)),'[]'::json))
  from (select q.m, (p_admin or not public._limited(q.m) or coalesce((q.m).see_transport_reviews, true)) as every from (select public._me() as m) q) x
$function$;

-- A quote: also says whether an organisation added it.
CREATE OR REPLACE FUNCTION public._quote_json(q quotes, p_full boolean)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select json_build_object('id',q.id,'vendor_id',q.vendor_id,'title',case when p_full then q.title else '' end,
    'date_from',q.date_from,'date_to',q.date_to,'pax',q.pax,'units',q.units,'received_on',q.received_on,'valid_until',q.valid_until,
    'ref',case when p_full then q.ref else '' end,'status',q.status,'currency',q.currency,'vat',q.vat,'conditions',q.conditions,
    'private_note',case when p_full then q.private_note else '' end,'shared',q.shared,'org',q.org,
    'mine', q.owner = coalesce(current_setting('app.editor', true),''),
    'owner',case when p_full then q.owner else '' end,'owner_name',case when p_full then q.owner_name else '' end,
    'owner_role',case when p_full then (select mm.role from public.members mm where mm.email = q.owner limit 1) else '' end,
    'owner_admin',case when p_full then (select mm.is_admin from public.members mm where mm.email = q.owner limit 1) end,
    'can_edit',p_full,'created_at',q.created_at,'updated_at',q.updated_at,
    'files',case when p_full then (select count(*) from public.vendor_files f where f.quote_id = q.id) else 0 end,
    'options',coalesce((select json_agg(json_build_object('id',o.id,'name',o.name,'note',o.note,
        'service',o.service,'seats',o.seats,'hours_incl',o.hours_incl,'km_incl',o.km_incl,'fees',o.fees,
        'lines',coalesce((select json_agg(l order by l.sort) from public.quote_lines l where l.option_id = o.id),'[]'::json)) order by o.sort)
      from public.quote_options o where o.quote_id = q.id),'[]'::json))
$function$;

-- Booking sheets: a limited member needs the transport section and see_quotes.
create or replace function public._bookings_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select m.is_admin or (coalesce((select value from public.app_settings where key = 'bookings_for'), '') = 'all'
    and (not public._limited(m) or (m.see_quotes and 'transport' = any (string_to_array(m.sections, ',')))))
$function$;

-- Jobs between colleagues are for guides and agents: never for a limited member.
create or replace function public._jobs_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select m.is_admin or (not public._limited(m) and coalesce((select value from public.app_settings where key = 'jobs_for'), '') in ('receive','all'))
$function$;

create or replace function public._jobs_post(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select m.is_admin or (not public._limited(m) and coalesce((select value from public.app_settings where key = 'jobs_for'), '') = 'all')
$function$;

-- A limited member is never offered a job and never appears in the list of colleagues a job fits.
create or replace function public._job_fits(p_kind text, p_needs text, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select not public._limited(m) and m.job_kinds <> 'none'
    and (m.job_kinds = '' or p_kind = any (string_to_array(m.job_kinds, ',')))
    and (m.job_kinds = '' or coalesce(p_needs,'') = ''
      or string_to_array(p_needs, ',') <@ string_to_array(m.job_tags || case when m.role = 'Licensed tour guide' then ',licensed' else '' end, ','))
$function$;

-- A quote added by a limited member is an organisation's quote. Stamped when the quote is first saved, whichever
-- function saves it (quote_save, or a booking sheet both sides accepted).
create or replace function public.quotes_org_stamp()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  new.org := coalesce((select public._limited(mm) from public.members mm where mm.email = new.owner order by mm.created_at limit 1), false);
  return new;
end $function$;

create or replace trigger quotes_org_stamp before insert on public.quotes for each row execute function public.quotes_org_stamp();

-- ===== 3. RPCs =====

-- The company's page shows who sent the sheet: an organisation shows its name where a guide shows his role.
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
    'date_from',b.date_from,'date_to',b.date_to,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,'answered_by',b.answered_by,
    'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,
    'guide_ok_at',b.guide_ok_at,'company_ok_at',b.company_ok_at,'company_ok_via',b.company_ok_via,'seen',b.seen_company);
end $function$;

CREATE OR REPLACE FUNCTION public.vendors_list(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(case when m.is_admin then public._vendor_view(v.id, true, m.email) else public._vendor_for(v, m) end order by v.name)
    from public.vendors v where m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories))), '[]'::json);
end $function$;

CREATE OR REPLACE FUNCTION public.my_top(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(t.vendor_id order by t.score desc) from (
      select a.vendor_id, sum(case when a.action = 'open' then 1 else 3 end * case when a.created_at > now() - interval '30 days' then 2 else 1 end) score
      from public.action_log a join public.vendors v on v.id = a.vendor_id
      where a.member = m.email and a.vendor_id is not null and (m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories)))
      group by a.vendor_id order by score desc limit 8) t), '[]'::json);
end $function$;

CREATE OR REPLACE FUNCTION public.vendor_detail(p_token text, p_id text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; v public.vendors; pp boolean; lim boolean;
begin
  m := public._auth(p_token); lim := public._limited(m);
  select * into v from public.vendors where id = p_id;
  if not m.is_admin and (v.hidden or not public._can_see(m, v.category, v.also_categories)) then raise exception 'That supplier is not available.'; end if;
  pp := v.prices_private;
  return json_build_object(
    'prices', coalesce((select json_agg(json_build_object('id',p.id,'vendor_id',p.vendor_id,'label',p.label,'audience',p.audience,'age_from',p.age_from,'age_to',p.age_to,'pax_min',p.pax_min,'pax_max',p.pax_max,'season',p.season,'price',p.price,'currency',p.currency,'vat',p.vat,'basis',p.basis,'is_agent',p.is_agent,'source',p.source,'checked_on',p.checked_on,'note',p.note,'private',p.private,'sort',p.sort,
          'org',p.org,
          'owner',case when m.is_admin or p.owner = m.email then p.owner else '' end,'mine',(p.owner <> '' and p.owner = m.email),
          'by',case when p.org and not m.is_admin and p.owner <> m.email then json_build_object('name','an organisation','role','','admin',false,'org',true)
                    else public._who(case when p.owner <> '' then p.owner else p.created_by end) end,
          'by_date',p.updated_at)
        order by (p.owner <> '' and not p.org), p.org, p.sort, p.audience, p.created_at)
      from public.vendor_prices p where p.vendor_id = p_id and public._price_visible(p, v, m)), '[]'),
    'prices_private', coalesce(pp,false),
    'deals', coalesce((select json_agg(case when m.is_admin then to_jsonb(d) else to_jsonb(d) || jsonb_build_object('reported_by', public._name(d.reported_by)) end order by (d.valid_to <> '' and d.valid_to < to_char(now(),'YYYY-MM-DD')), d.created_at desc) from public.vendor_deals d where d.vendor_id = p_id), '[]'),
    'notes', coalesce((select json_agg(case when m.is_admin then to_jsonb(n) || jsonb_build_object('mine', n.author = m.email)
          else to_jsonb(n) || jsonb_build_object('author', public._name(n.author), 'mine', n.author = m.email) end order by n.created_at desc)
        from public.vendor_notes n where n.vendor_id = p_id and public._note_visible(n, v, m)), '[]'),
    'reviews_open', public._reviews_open(m, v.category, v.also_categories),
    'requests', coalesce((select json_agg(c order by c.created_at desc) from public.change_requests c where c.vendor_id = p_id and c.status = 'pending' and (m.is_admin or c.requested_by = m.email)), '[]'),
    'admin_note', case when m.is_admin then (select body from public.vendor_admin_notes a where a.vendor_id = p_id) else null end,
    'sites', coalesce((select json_agg(json_build_object('id',s.id,'name',s.name,'location',s.location,'reservation',s.reservation) order by s.name) from public.vendors s
        where s.parent_id = p_id and (m.is_admin or (not s.hidden and public._can_see(m, s.category, s.also_categories)))), '[]'),
    'parent', (select json_build_object('id',pv.id,'name',pv.name) from public.vendors pv
        where pv.id = v.parent_id and (m.is_admin or (not pv.hidden and public._can_see(m, pv.category, pv.also_categories)))),
    'res_reports', coalesce((select json_agg(json_build_object('checked',r.checked,'visit_date',r.visit_date,'note',r.note,'member_name',r.member_name,'created_at',r.created_at,'mine',r.member = m.email) order by r.created_at desc) from (select * from public.reservation_reports where vendor_id = p_id order by created_at desc limit 20) r), '[]'),
    'res_answered', exists (select 1 from public.reservation_reports where vendor_id = p_id and member = m.email),
    'deal_by', coalesce((select json_object_agg(d.id, public._who(d.reported_by)) from public.vendor_deals d where d.vendor_id = p_id), '{}'),
    'note_by', coalesce((select json_object_agg(n.id, public._who(n.author)) from public.vendor_notes n where n.vendor_id = p_id and public._note_visible(n, v, m)), '{}')
  );
end $function$;

CREATE OR REPLACE FUNCTION public.vendor_save(p_token text, p_data jsonb, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; r public.vendors; cv public.vendors; f text; clean jsonb := '{}'::jsonb; cur jsonb; locked_changes jsonb := '{}'::jsonb; open_vals jsonb := '{}'::jsonb; req boolean := false;
  price_fields text[] := array['agentPrice','listedPrice','agentPriceVatTreatment','listedPriceVatTreatment','maxPax'];
  agent_fields text[] := array['agentPrice','agentPriceVatTreatment','agent_link','agent_howto'];
  skip text[] := array[]::text[];
  is_rest boolean; no_cert boolean; lim boolean;
begin
  m := public._auth(p_token); lim := public._limited(m);
  foreach f in array public._all_fields() loop
    clean := clean || jsonb_build_object(f, left(coalesce(p_data->>f,''), 2000));
  end loop;
  -- Kosher rule (D-7, D-8): no non-kosher restaurants; a restaurant that is kosher without a certificate is an exception Eretz Israel Tours approves.
  is_rest := (clean->>'category') = 'Restaurant' or (clean->>'also_categories') ~* '(^|,)\s*Restaurant\s*(,|$)';
  if is_rest and (clean->>'kosher') ~* '^\s*(not kosher|non[- ]?kosher|kosher[- ]style)' then raise exception 'The list does not accept non-kosher restaurants.'; end if;
  no_cert := is_rest and (clean->>'kosher') ~* '^\s*kosher\W+(no|without)\s+(certificate|certification|teuda|teudah|hechsher)';
  if coalesce(p_data->>'id','') = '' then
    if lim then
      -- A limited member adds suppliers in his own sections, and never an agent price (D-12).
      if not public._can_see(m, clean->>'category', clean->>'also_categories') then raise exception 'You can add suppliers in the sections you have access to.'; end if;
      foreach f in array agent_fields loop clean := clean || jsonb_build_object(f, ''); end loop;
    end if;
    select * into r from jsonb_populate_record(null::public.vendors, clean);
    insert into public.vendors (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link,hours,hours_last)
    values (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link,r.hours,r.hours_last)
    returning * into r;
    return json_build_object('vendor', public._vendor_view(r.id, m.is_admin, m.email), 'request', false);
  end if;
  select * into cv from public.vendors v where v.id = p_data->>'id';
  if cv.id is null then raise exception 'That supplier no longer exists.'; end if;
  cur := to_jsonb(cv);
  -- An app version from before opening hours existed sends no "hours": keep what is stored.
  if not (p_data ? 'hours') then clean := clean || jsonb_build_object('hours', coalesce(cur->>'hours','')); end if;
  if not (p_data ? 'hours_last') then clean := clean || jsonb_build_object('hours_last', coalesce(cur->>'hours_last','')); end if;
  if m.is_admin then
    r := public._vendor_apply(p_data->>'id', clean);
    return json_build_object('vendor', public._vendor_view(r.id, true), 'request', false);
  end if;
  if cv.hidden or not public._can_see(m, cv.category, cv.also_categories) then raise exception 'That supplier is not available.'; end if;
  if lim then
    -- Fields a limited member never receives come back empty from his form: leave what is stored (D-12).
    skip := agent_fields;
    if cv.category = 'Guide' and not m.see_guide_rates then skip := skip || array['listedPrice','listedPriceVatTreatment','maxPax']; end if;
    if not public._reviews_open(m, cv.category, cv.also_categories) then skip := skip || array['rateReliability','rateService','rateValue','strengths','weaknesses','notes']; end if;
  end if;
  foreach f in array public._all_fields() loop
    if cv.prices_private and f = any(price_fields) then continue; end if;
    if f = any(skip) then continue; end if;
    if (clean->>f) is distinct from coalesce(cur->>f,'') then
      if f = any(public._locked_fields()) or (f = 'kosher' and no_cert) then locked_changes := locked_changes || jsonb_build_object(f, clean->>f);
      else open_vals := open_vals || jsonb_build_object(f, clean->>f); end if;
    end if;
  end loop;
  if open_vals <> '{}'::jsonb then perform public._vendor_apply(p_data->>'id', open_vals); end if;
  if locked_changes <> '{}'::jsonb then
    if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'Say briefly why: this change needs approval by Eretz Israel Tours.'; end if;
    insert into public.change_requests (vendor_id, kind, proposed, current, reason, requested_by, requested_name)
    select p_data->>'id', 'vendor_fields', locked_changes,
      (select jsonb_object_agg(k, coalesce(cur->>k,'')) from jsonb_object_keys(locked_changes) k), trim(p_reason), m.email, m.name;
    req := true;
  end if;
  return json_build_object('vendor', public._vendor_view(p_data->>'id', false, m.email), 'request', req);
end $function$;

-- Agent sign-up details are for guides and agents.
CREATE OR REPLACE FUNCTION public.vendor_set_agent(p_token text, p_vendor text, p_link text, p_howto text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; l text := trim(coalesce(p_link,''));
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if public._limited(m) then raise exception 'Agent sign-up details are for tour guides and agents.' using errcode = '42501'; end if;
  if l <> '' and l !~* '^https?://' then l := 'https://' || l; end if;
  if l <> '' and l !~* '^https?://[^\s/]+\.[^\s]+' then raise exception 'That link does not look right.'; end if;
  update public.vendors set agent_link = left(l,500), agent_howto = left(trim(coalesce(p_howto,'')),1000), updated_by = m.email, updated_at = now() where id = p_vendor;
  return public._vendor_view(p_vendor, m.is_admin, m.email);
end $function$;

-- A price line a limited member adds is an ORGANISATION RATE: saved straight away, never an agent rate, shown to
-- everyone without the name (owner = his email, org = true). On a private-price supplier it stays with him and
-- Eretz Israel Tours. Nobody can change or suggest changing a line he cannot see. (Taking a line off the list is
-- price_delete, which is not touched: the owner of a line and Eretz Israel Tours take it off directly, as before.)
CREATE OR REPLACE FUNCTION public.price_save(p_token text, p_vendor text, p_data jsonb, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; v public.vendors; c jsonb := public._price_clean(p_data); pid uuid := nullif(p_data->>'id','')::uuid; cur public.vendor_prices; mine boolean := coalesce((p_data->>'mine')::boolean,false); pp boolean; lim boolean;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin); lim := public._limited(m);
  if c->>'price' = '' and c->>'label' = '' then raise exception 'Add what the price is for.'; end if;
  select * into v from public.vendors where id = p_vendor; pp := v.prices_private;
  if pid is not null then select * into cur from public.vendor_prices p where p.id = pid and p.vendor_id = p_vendor;
    if cur.id is null or not public._price_visible(cur, v, m) then raise exception 'That price no longer exists.'; end if; end if;
  if m.is_admin and not (cur.id is not null and cur.owner <> '' and cur.owner <> m.email) then
    perform public._price_write(p_vendor, pid, c, m.email);
    return json_build_object('request', false);
  end if;
  if lim then
    c := c || jsonb_build_object('is_agent', false);
    if cur.id is null or cur.owner = m.email then
      c := c || jsonb_build_object('private', coalesce(pp, false));
      pid := public._price_write(p_vendor, pid, c, m.email);
      update public.vendor_prices set owner = m.email, org = true where id = pid;
      return json_build_object('request', false, 'mine', true, 'org', true);
    end if;
  end if;
  -- personal line: saved straight away, visible only to its owner and the admin
  if mine or pp or (cur.id is not null and cur.owner = m.email) then
    if cur.id is not null and cur.owner <> m.email then raise exception 'You can only change your own prices.'; end if;
    c := c || jsonb_build_object('private', true);
    pid := public._price_write(p_vendor, pid, c, m.email);
    update public.vendor_prices set owner = m.email where id = pid;
    return json_build_object('request', false, 'mine', true);
  end if;
  if cur.id is not null and cur.owner <> '' then raise exception 'You can only change your own prices.'; end if;
  c := c - 'private';
  if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'Say briefly where this price comes from or why it changed.'; end if;
  insert into public.change_requests (vendor_id, kind, target_id, proposed, current, reason, requested_by, requested_name)
  values (p_vendor, case when pid is null then 'price_add' else 'price_edit' end, pid, c, coalesce(to_jsonb(cur),'{}'::jsonb), trim(p_reason), m.email, m.name);
  return json_build_object('request', true);
end $function$;

CREATE OR REPLACE FUNCTION public.quotes_list(p_token text, p_vendor text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  return coalesce((select json_agg(public._quote_json(q, m.is_admin or q.owner = m.email)
      order by (q.status in ('Expired','Declined')), coalesce(nullif(q.date_from,''),'9999') desc, q.created_at desc)
    from public.quotes q join public.vendors v on v.id = q.vendor_id
    where q.vendor_id = p_vendor and public._quote_visible(q, v, m)), '[]'::json);
end $function$;

CREATE OR REPLACE FUNCTION public.quotes_tracker(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(public._quote_json(q, m.is_admin or q.owner = m.email) order by q.created_at desc)
    from public.quotes q join public.vendors v on v.id = q.vendor_id
    where m.is_admin or (not v.hidden and public._quote_visible(q, v, m))), '[]'::json);
end $function$;

-- Finding a driver by phone number is part of the transport section.
CREATE OR REPLACE FUNCTION public.driver_find(p_token text, p_phone text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; d public.drivers;
begin
  m := public._auth(p_token);
  if public._limited(m) and not ('transport' = any (string_to_array(m.sections, ','))) then return null; end if;
  select * into d from public.drivers where phone_norm = public._phone_norm(p_phone);
  if d.id is null then return null; end if;
  return public._driver_json(d, m.email, m.is_admin);
end $function$;

CREATE OR REPLACE FUNCTION public.driver_review_add(p_token text, p_driver uuid, p_vendor text, p_review jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; rid uuid; vid text := nullif(p_vendor,'');
begin
  m := public._auth(p_token);
  if public._limited(m) and not ('transport' = any (string_to_array(m.sections, ','))) then raise exception 'Driver reviews are not part of your access.' using errcode = '42501'; end if;
  if not exists (select 1 from public.drivers where id = p_driver) then raise exception 'That driver is no longer on the list.'; end if;
  if coalesce(p_review->>'rating','') !~ '^[1-5]$' then raise exception 'Give a rating from 1 to 5.'; end if;
  if vid is not null then
    perform public._visible(vid, m.is_admin);
    if not exists (select 1 from public.vendors where id = vid) then raise exception 'That supplier no longer exists.'; end if;
    insert into public.driver_vendors (driver_id, vendor_id, added_by) values (p_driver, vid, m.email) on conflict do nothing;
  end if;
  insert into public.driver_reviews (driver_id, vendor_id, rating, tags, body, trip_month, author, author_name, org)
  values (p_driver, vid, p_review->>'rating', left(trim(coalesce(p_review->>'tags','')),300), left(trim(coalesce(p_review->>'body','')),1500),
    case when coalesce(p_review->>'trip_month','') ~ '^\d{4}-\d{2}$' then p_review->>'trip_month' else '' end, m.email, m.name, public._limited(m))
  returning id into rid;
  return rid;
end $function$;

-- A note. From a limited member it is a review, shown to everyone (org = true).
CREATE OR REPLACE FUNCTION public.note_add(p_token text, p_vendor text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  insert into public.vendor_notes (vendor_id, body, author, author_name, org) values (p_vendor, trim(p_body), m.email, m.name, public._limited(m));
end $function$;

-- A note with an optional 1-5 rating: what the app calls a review.
create or replace function public.review_add(p_token text, p_vendor text, p_body text, p_rating text default ''::text)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  insert into public.vendor_notes (vendor_id, body, author, author_name, org, rating)
  values (p_vendor, trim(p_body), m.email, m.name, public._limited(m), case when coalesce(p_rating,'') ~ '^[1-5]$' then p_rating else '' end);
end $function$;

-- An organisation that is not in tourism asks to join: its name and, in free text, the person's credentials
-- (no license, no upload). It starts as a limited member with the standard sections, whoever approves it and from
-- whichever copy of the app. Stored with role 'Other'; members.org is what marks it as an organisation.
create or replace function public.request_access_org(p_name text, p_email text, p_phone text, p_note text, p_terms text, p_org text, p_credentials text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare t text := public._new_token(); e text := lower(trim(p_email));
  cred text := left(trim(coalesce(p_credentials,'')),1000); org_name text := left(trim(coalesce(p_org,'')),120);
begin
  if coalesce(p_terms,'') = '' then raise exception 'Please read and accept the terms to join.'; end if;
  if length(org_name) < 2 then raise exception 'Add the name of your organisation.'; end if;
  if length(cred) < 20 then raise exception 'Write a few lines about your role and how Eretz Israel Tours can check who you are.'; end if;
  if (select count(*) from public.members where status = 'pending') >= 300 then raise exception 'Too many open requests right now. Try again later.'; end if;
  if exists (select 1 from public.members where email = e and status in ('pending','approved')) then
    raise exception 'This email already has access or a request waiting. Ask Eretz Israel Tours to send you your personal link.'; end if;
  insert into public.members (name, email, phone, note, role, token_hash, terms_version, terms_accepted_at, org, credentials, member_type, sections)
  values (trim(p_name), e, left(coalesce(trim(p_phone),''),40), left(coalesce(trim(p_note),''),300), 'Other', public._hash(t), left(p_terms,20), now(),
    org_name, cred, 'limited', 'transport,guides,hotels,sites,food');
  return json_build_object('token', t, 'status', 'pending', 'alert', (select value from public.app_settings where key = 'ntfy_topic'));
end $function$;

CREATE OR REPLACE FUNCTION public.members_list(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',id,'name',name,'email',email,'phone',phone,'note',note,'role',case when org <> '' then 'Organisation, not in tourism' else role end,'license_no',license_no,'has_proof',proof_path is not null,'status',status,'is_admin',is_admin,'created_at',created_at,'last_seen_at',last_seen_at,'terms_version',terms_version,'terms_accepted_at',terms_accepted_at,
    'member_type',member_type,'sections',sections,'see_quotes',see_quotes,'see_guide_rates',see_guide_rates,'see_transport_reviews',see_transport_reviews,'see_reviews',see_reviews,'org',org,'credentials',credentials) order by (status='pending') desc, created_at desc) from public.members), '[]'::json);
end $function$;

-- Eretz Israel Tours sets what a member sees: full, or limited to chosen sections with four switches.
create or replace function public.member_set_access(p_token text, p_id uuid, p_access jsonb)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare t text := coalesce(nullif(p_access->>'member_type',''), 'full'); s text;
begin
  perform public._auth(p_token, true);
  if t not in ('full','limited') then raise exception 'Choose full or limited.'; end if;
  s := public._csv_keys(p_access->>'sections', array['transport','guides','hotels','sites','food','other']);
  if t = 'limited' and s = '' then raise exception 'Tick at least one section.'; end if;
  update public.members set member_type = t, sections = case when t = 'limited' then s else '' end,
    see_quotes = coalesce((p_access->>'see_quotes')::boolean, true),
    see_guide_rates = coalesce((p_access->>'see_guide_rates')::boolean, false),
    see_transport_reviews = coalesce((p_access->>'see_transport_reviews')::boolean, true),
    see_reviews = coalesce((p_access->>'see_reviews')::boolean, false)
  where id = p_id and not is_admin;
  if not found then raise exception 'Can''t change access for that person.'; end if;
end $function$;

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
    'member_type', case when public._limited(m) then 'limited' else 'full' end,
    'sections', case when public._limited(m) then sections else '' end,
    'see_quotes', not public._limited(m) or see_quotes,
    'see_guide_rates', not public._limited(m) or see_guide_rates,
    'see_transport_reviews', not public._limited(m) or see_transport_reviews,
    'see_reviews', not public._limited(m) or see_reviews,
    'org', org)
  from public.members m where token_hash = public._hash(p_token);
$function$;

-- ===== 4. Privileges =====
-- New helpers: never callable from outside. New and re-created RPCs: revoked from public, granted like the others.
revoke all on function public._me() from public, anon, authenticated;
revoke all on function public._section_of(text) from public, anon, authenticated;
revoke all on function public._limited(public.members) from public, anon, authenticated;
revoke all on function public._can_see(public.members,text,text) from public, anon, authenticated;
revoke all on function public._reviews_open(public.members,text,text) from public, anon, authenticated;
revoke all on function public._price_visible(public.vendor_prices,public.vendors,public.members) from public, anon, authenticated;
revoke all on function public._note_visible(public.vendor_notes,public.vendors,public.members) from public, anon, authenticated;
revoke all on function public._file_visible(public.vendor_files,public.members) from public, anon, authenticated;
revoke all on function public._file_scope(uuid,text) from public, anon, authenticated;
grant execute on function public._file_scope(uuid,text) to service_role;
revoke all on function public._quote_kind(public.quotes,public.vendors) from public, anon, authenticated;
revoke all on function public._quote_visible(public.quotes,public.vendors,public.members) from public, anon, authenticated;
revoke all on function public._vendor_for(public.vendors,public.members) from public, anon, authenticated;
revoke all on function public.quotes_org_stamp() from public, anon, authenticated;
revoke all on function public.review_add(text,text,text,text) from public; grant execute on function public.review_add(text,text,text,text) to anon, authenticated;
revoke all on function public.request_access_org(text,text,text,text,text,text,text) from public; grant execute on function public.request_access_org(text,text,text,text,text,text,text) to anon, authenticated;
revoke all on function public.member_set_access(text,uuid,jsonb) from public; grant execute on function public.member_set_access(text,uuid,jsonb) to anon, authenticated;

commit;
