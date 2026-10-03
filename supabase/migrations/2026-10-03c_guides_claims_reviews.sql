-- Guide pages for clients, claimed pages, reviews, and the guide rules (3 Oct 2026).
-- See docs/DECISIONS.md D-12, D-14, D-16. Run after 2026-10-03b_limited_members.sql: every function below is written
-- on top of the limited-members version (D-15) and keeps its rules.
-- supabase/schema.sql already includes everything here. Safe to run twice. No statement in this file removes anything.
--
-- D-12  A guide's page has a section written for clients: a bio, a retail price in free text, up to four pictures.
-- D-14  A member can claim the page that is his own; Eretz Israel Tours approves, or links it directly.
--       Unclaimed, any full member can write a guide's client section; claimed, only that guide and Eretz Israel Tours.
--       What colleagues wrote ABOUT a page (ratings, strengths, weaknesses, notes, the notes thread, driver reviews) is
--       not sent to the member whose page it is; it stays visible to everyone else. "His page" is one he claimed, or one
--       that carries his own phone number or email. He can dispute anything on it.
--       A guide's review of another guide waits for approval by Eretz Israel Tours. A note or a driver review can be
--       kept private: only its author and Eretz Israel Tours see it.
-- D-16  Only licensed tour guides are listed, except a specialty (shuk tours, graffiti tours) that Eretz Israel Tours
--       approves. An Eshkol driver or guide needs a D1 license. Both are stated with tags and checked in vendor_save.
-- With D-15: a limited member (an organisation) does not get a guide's retail price unless he sees guide rates, does not
--       write the client section, does not claim a page, and his reviews never wait for approval.

-- ===== 1. columns and one table =====
alter table public.vendors
  add column if not exists client_bio text default ''::text not null,
  add column if not exists retail_price text default ''::text not null,
  add column if not exists claimed_by text default ''::text not null,
  add column if not exists claimed_at timestamp with time zone;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'vendors_client_check' and conrelid = 'public.vendors'::regclass) then
    alter table public.vendors add constraint vendors_client_check check (length(client_bio) <= 1500 and length(retail_price) <= 200);
  end if;
end $$;
create index if not exists vendors_claimed_by_idx on public.vendors using btree (claimed_by) where (claimed_by <> ''::text);
alter table public.vendor_files add column if not exists for_clients boolean default false not null;
alter table public.vendor_reports add column if not exists by_owner boolean default false not null;
alter table public.vendor_notes
  add column if not exists private boolean default false not null,
  add column if not exists status text default 'approved'::text not null,
  add column if not exists decided_by text,
  add column if not exists decided_at timestamp with time zone;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'vendor_notes_status_check' and conrelid = 'public.vendor_notes'::regclass) then
    alter table public.vendor_notes add constraint vendor_notes_status_check check (status = any (array['pending'::text, 'approved'::text, 'rejected'::text]));
  end if;
end $$;
alter table public.driver_reviews add column if not exists private boolean default false not null;

create table if not exists public.vendor_claims (
  id uuid default gen_random_uuid() not null,
  vendor_id text not null,
  member text not null,
  member_name text default ''::text not null,
  note text default ''::text not null,
  status text default 'pending'::text not null,
  decided_by text,
  decided_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  constraint vendor_claims_pkey primary key (id),
  constraint vendor_claims_vendor_id_fkey foreign key (vendor_id) references public.vendors(id) on delete cascade,
  constraint vendor_claims_note_check check (length(note) <= 500),
  constraint vendor_claims_status_check check (status = any (array['pending'::text, 'approved'::text, 'rejected'::text]))
);
alter table public.vendor_claims enable row level security;
create unique index if not exists vendor_claims_one_pending on public.vendor_claims using btree (vendor_id, member) where (status = 'pending'::text);
revoke all on table public.vendor_claims from public, anon, authenticated;
grant all on table public.vendor_claims to service_role;

-- ===== 2. internal helpers (not RPCs) =====
-- Is this supplier a guide? Main category Guide, or Guide under "also offers".
create or replace function public._is_guide(v public.vendors)
 returns boolean language sql immutable set search_path to ''
as $function$
  select v.category = 'Guide' or coalesce(v.also_categories,'') ~* '(^|,)\s*Guide\s*(,|$)'
$function$;
revoke all on function public._is_guide(public.vendors) from public, anon, authenticated;

-- Is this supplier page the member's own? He claimed it, or his own phone number or email is on it.
-- Never true for Eretz Israel Tours, who sees everything.
create or replace function public._is_own(v public.vendors, m public.members)
 returns boolean language sql immutable set search_path to ''
as $function$
  select coalesce(m.id is not null and not m.is_admin and (
       (v.claimed_by <> '' and v.claimed_by = m.email)
    or (length(public._phone_norm(m.phone)) >= 9 and (
            position(right(public._phone_norm(m.phone), 9) in regexp_replace(coalesce(v.phone,''), '\D', '', 'g')) > 0
         or position(right(public._phone_norm(m.phone), 9) in regexp_replace(coalesce(v.whatsapp,''), '\D', '', 'g')) > 0))
    or (m.email <> '' and position(m.email in lower(coalesce(v.email,''))) > 0)), false)
$function$;
revoke all on function public._is_own(public.vendors,public.members) from public, anon, authenticated;

-- Is this driver the member himself (same phone number), or a driver of a company page that is the member's own?
create or replace function public._driver_own(d public.drivers, m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(m.id is not null and not m.is_admin and (
       (length(public._phone_norm(m.phone)) >= 9 and right(public._phone_norm(m.phone), 9) = right(d.phone_norm, 9))
    or exists (select 1 from public.driver_vendors dv join public.vendors v on v.id = dv.vendor_id where dv.driver_id = d.id and public._is_own(v, m))), false)
$function$;
revoke all on function public._driver_own(public.drivers,public.members) from public, anon, authenticated;

-- Is this member a guide? His role says so, or he has claimed a guide's page.
create or replace function public._is_guide_member(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(m.id is not null and not m.is_admin and (m.role = 'Licensed tour guide'
    or exists (select 1 from public.vendors v where v.claimed_by = m.email and public._is_guide(v))), false)
$function$;
revoke all on function public._is_guide_member(public.members) from public, anon, authenticated;

-- ===== 3. what a member receives (helpers that already existed, D-15) =====
-- One note, for one member. Added to the limited-member rule: nothing on the member's own page; a private note, or one
-- waiting for approval or turned down, only for its author and Eretz Israel Tours.
create or replace function public._note_visible(n public.vendor_notes, v public.vendors, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select coalesce(m.is_admin, false) or (
        not public._is_own(v, m)
    and (n.author = m.email or (n.status = 'approved' and not n.private))
    and (not public._limited(m) or n.org or n.author = m.email or n.author like 'import from websites%'
         or public._reviews_open(m, v.category, v.also_categories)))
$function$;

-- A supplier as one member receives it. Added: no ratings or remarks on his own page; the retail price goes with the
-- other prices; the note count is what he can read; whether the page is claimed, and by whom (a name, never an email).
create or replace function public._vendor_for(v public.vendors, m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select (public._vendor_json(v.id)::jsonb
      || case when v.prices_private then jsonb_build_object('agentPrice','','listedPrice','','agentPriceVatTreatment','','listedPriceVatTreatment','','maxPax','','retail_price','') else '{}'::jsonb end
      || case when x.lim then jsonb_build_object('agentPrice','','agentPriceVatTreatment','','agent_link','','agent_howto','') else '{}'::jsonb end
      || case when x.lim and v.category = 'Guide' and not m.see_guide_rates then jsonb_build_object('listedPrice','','listedPriceVatTreatment','','maxPax','','retail_price','') else '{}'::jsonb end
      || case when (x.lim and not x.rev) or x.own then jsonb_build_object('rateReliability','','rateService','','rateValue','','strengths','','weaknesses','','notes','') else '{}'::jsonb end
      || case when x.lim then jsonb_build_object(
           '_files', (select count(*) from public.vendor_files f where f.vendor_id = v.id and f.quote_id is null and public._file_visible(f, m))) else '{}'::jsonb end
      || jsonb_build_object('_prices', (select count(*) from public.vendor_prices p where p.vendor_id = v.id and public._price_visible(p, v, m)),
           '_notes', (select count(*) from public.vendor_notes n where n.vendor_id = v.id and public._note_visible(n, v, m)),
           'created_by', public._name(v.created_by), 'updated_by', public._name(v.updated_by), 'hours_verified_by', public._name(v.hours_verified_by),
           'claimed_by', '', '_claimed', v.claimed_by <> '', 'claimed_name', public._name(v.claimed_by),
           '_mine', coalesce(v.claimed_by <> '' and v.claimed_by = m.email, false), '_own', x.own)
    )::json
  from (select public._limited(m) as lim, public._reviews_open(m, v.category, v.also_categories) as rev, public._is_own(v, m) as own) x
$function$;

-- Eretz Israel Tours' view also says whether the page is claimed.
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
    return (public._vendor_json(p_id)::jsonb || jsonb_build_object('_prices',(select count(*) from public.vendor_prices p where p.vendor_id=p_id),
      '_claimed', v.claimed_by <> '', 'claimed_name', public._name(v.claimed_by), '_mine', false, '_own', false))::json;
  end if;
  m := public._me();
  if m.id is null or m.email is distinct from p_email then
    select * into m from public.members mm where mm.email = p_email order by mm.created_at limit 1;
  end if;
  return public._vendor_for(v, m);
end $function$;

-- A driver with his reviews. Added: none of them for the driver himself or the member whose company it is; a private
-- review only for its author and Eretz Israel Tours, and not in the average others see.
CREATE OR REPLACE FUNCTION public._driver_json(d drivers, p_email text, p_admin boolean)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select json_build_object('id',d.id,'name',d.name,'phone',d.phone,'drives',d.drives,
    'can_edit', p_admin or d.created_by = p_email,
    'n',case when x.hide then 0 else (select count(*) from public.driver_reviews r where r.driver_id = d.id and (x.every or r.org or r.author = p_email) and (p_admin or not r.private or r.author = p_email)) end,
    'avg',case when x.hide then null else (select round(avg(r.rating::int)::numeric, 1) from public.driver_reviews r where r.driver_id = d.id and (x.every or r.org or r.author = p_email) and (p_admin or not r.private or r.author = p_email)) end,
    'some_hidden', not x.every, 'reviews_hidden', x.hide,
    'vendors',coalesce((select json_agg(json_build_object('id',v.id,'name',v.name) order by v.name)
        from public.driver_vendors dv join public.vendors v on v.id = dv.vendor_id
        where dv.driver_id = d.id and (p_admin or (not v.hidden and public._can_see(x.m, v.category, v.also_categories)))),'[]'::json),
    'reviews',case when x.hide then '[]'::json else coalesce((select json_agg(json_build_object('id',r.id,'rating',r.rating,'tags',r.tags,'body',r.body,'trip_month',r.trip_month,
          'vendor_id',case when v.id is not null and (p_admin or (not v.hidden and public._can_see(x.m, v.category, v.also_categories))) then v.id end,
          'vendor_name',case when v.id is not null and (p_admin or (not v.hidden and public._can_see(x.m, v.category, v.also_categories))) then v.name end,
          'by',public._who(r.author),'mine',r.author = p_email,'org',r.org,'private',r.private,'created_at',r.created_at) order by r.created_at desc)
        from public.driver_reviews r left join public.vendors v on v.id = r.vendor_id
        where r.driver_id = d.id and (x.every or r.org or r.author = p_email) and (p_admin or not r.private or r.author = p_email)),'[]'::json) end)
  from (select q.m, (p_admin or not public._limited(q.m) or coalesce((q.m).see_transport_reviews, true)) as every,
               (not p_admin) and public._driver_own(d, q.m) as hide from (select public._me() as m) q) x
$function$;

-- ===== 4. existing RPCs, changed =====
-- vendor_detail: whether the page is the caller's own, whether his claim is waiting; for Eretz Israel Tours, who
-- claimed it and which members' phone or email is on it.
CREATE OR REPLACE FUNCTION public.vendor_detail(p_token text, p_id text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; v public.vendors; pp boolean; lim boolean; own boolean;
begin
  m := public._auth(p_token); lim := public._limited(m);
  select * into v from public.vendors where id = p_id;
  if not m.is_admin and (v.hidden or not public._can_see(m, v.category, v.also_categories)) then raise exception 'That supplier is not available.'; end if;
  pp := v.prices_private; own := public._is_own(v, m);
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
          else to_jsonb(n) || jsonb_build_object('author', public._name(n.author), 'decided_by', '', 'mine', n.author = m.email) end order by n.created_at desc)
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
    'note_by', coalesce((select json_object_agg(n.id, public._who(n.author)) from public.vendor_notes n where n.vendor_id = p_id and public._note_visible(n, v, m)), '{}'),
    'own', coalesce(own, false),
    'my_claim', exists (select 1 from public.vendor_claims c where c.vendor_id = p_id and c.member = m.email and c.status = 'pending'),
    'claimer', case when m.is_admin then (select json_build_object('id',mm.id,'name',mm.name,'role',case when mm.org <> '' then mm.org else mm.role end) from public.members mm where mm.email = v.claimed_by and v.claimed_by <> '' order by mm.created_at limit 1) end,
    'matches', case when m.is_admin then coalesce((select json_agg(json_build_object('id',mm.id,'name',mm.name,'role',case when mm.org <> '' then mm.org else mm.role end) order by mm.name)
        from public.members mm where mm.status = 'approved' and v.claimed_by <> mm.email and public._is_own(v, mm)), '[]'::json) end
  );
end $function$;

-- vendor_save: the guide rules (D-16); a member's save of his own page leaves the ratings and remarks alone; a guide's
-- change to another guide's ratings or remarks, or marking a guide as a specialty, becomes a change request (D-14, D-16).
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
  is_rest boolean; no_cert boolean; lim boolean; own boolean := false; gog boolean := false;
  review_fields text[] := array['rateReliability','rateService','rateValue','strengths','weaknesses','notes'];
  is_gd boolean; lic boolean; spec boolean; esh boolean; d1 boolean; was_gd boolean := false; was_spec boolean := false; was_esh boolean := false;
begin
  m := public._auth(p_token); lim := public._limited(m);
  foreach f in array public._all_fields() loop
    clean := clean || jsonb_build_object(f, left(coalesce(p_data->>f,''), 2000));
  end loop;
  -- Kosher rule (D-7, D-8): no non-kosher restaurants; a restaurant that is kosher without a certificate is an exception Eretz Israel Tours approves.
  is_rest := (clean->>'category') = 'Restaurant' or (clean->>'also_categories') ~* '(^|,)\s*Restaurant\s*(,|$)';
  if is_rest and (clean->>'kosher') ~* '^\s*(not kosher|non[- ]?kosher|kosher[- ]style)' then raise exception 'The list does not accept non-kosher restaurants.'; end if;
  no_cert := is_rest and (clean->>'kosher') ~* '^\s*kosher\W+(no|without)\s+(certificate|certification|teuda|teudah|hechsher)';
  -- Guides (D-16): only licensed tour guides are listed, except a specialty (shuk tours, graffiti tours and the like),
  -- which Eretz Israel Tours approves as an exception. An Eshkol driver or guide needs a D1 license.
  -- Both are stated with tags, and asked for when an entry is new, becomes a guide, or gains Eshkol.
  is_gd := (clean->>'category') = 'Guide' or (clean->>'also_categories') ~* '(^|,)\s*Guide\s*(,|$)';
  lic := (clean->>'tags') ~* '(^|,)\s*Licensed tour guide\s*(,|$)';
  spec := (clean->>'tags') ~* '(^|,)\s*Specialty guide\s*(,|$)';
  esh := (clean->>'tags') ~* 'eshkol (license|driver|guide)';
  d1 := (clean->>'tags') ~* '(^|,)\s*D1 license\s*(,|$)';
  if coalesce(p_data->>'id','') <> '' then
    select public._is_guide(x), coalesce(x.tags,'') ~* '(^|,)\s*Specialty guide\s*(,|$)', coalesce(x.tags,'') ~* 'eshkol (license|driver|guide)'
      into was_gd, was_spec, was_esh from public.vendors x where x.id = p_data->>'id';
  end if;
  if is_gd and lic and spec then raise exception 'Choose one: licensed tour guide, or specialty guide.'; end if;
  if is_gd and not coalesce(was_gd, false) and not (lic or spec) then
    raise exception 'Say whether this guide is licensed. Only licensed tour guides are listed, except specialties such as shuk tours or graffiti tours.'; end if;
  if esh and not coalesce(was_esh, false) and not d1 then
    raise exception 'Only a driver with a D1 license can be listed as an Eshkol driver or guide. Add the tag "D1 license" to confirm it, or take Eshkol off.'; end if;
  if coalesce(p_data->>'id','') = '' then
    if lim then
      -- A limited member adds suppliers in his own sections, and never an agent price (D-15).
      if not public._can_see(m, clean->>'category', clean->>'also_categories') then raise exception 'You can add suppliers in the sections you have access to.'; end if;
      foreach f in array agent_fields loop clean := clean || jsonb_build_object(f, ''); end loop;
    end if;
    select * into r from jsonb_populate_record(null::public.vendors, clean);
    insert into public.vendors (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link,hours,hours_last)
    values (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link,r.hours,r.hours_last)
    returning * into r;
    -- a member who adds his own business does not rate it (D-14)
    if public._is_own(r, m) then update public.vendors set "rateReliability" = '', "rateService" = '', "rateValue" = '', strengths = '', weaknesses = '' where id = r.id; end if;
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
    -- Fields a limited member never receives come back empty from his form: leave what is stored (D-15).
    skip := agent_fields;
    if cv.category = 'Guide' and not m.see_guide_rates then skip := skip || array['listedPrice','listedPriceVatTreatment','maxPax']; end if;
    if not public._reviews_open(m, cv.category, cv.also_categories) then skip := skip || array['rateReliability','rateService','rateValue','strengths','weaknesses','notes']; end if;
  end if;
  -- D-14: ratings and remarks on a member's own page are hidden from him, so his save leaves them as they are;
  -- a guide's change to another guide's ratings or remarks is a review, and Eretz Israel Tours approves it first.
  own := public._is_own(cv, m);
  if own then skip := skip || review_fields; end if;
  gog := public._is_guide(cv) and public._is_guide_member(m);
  foreach f in array public._all_fields() loop
    if cv.prices_private and f = any(price_fields) then continue; end if;
    if f = any(skip) then continue; end if;
    if (clean->>f) is distinct from coalesce(cur->>f,'') then
      if f = any(public._locked_fields()) or (f = 'kosher' and no_cert) or (gog and f = any(review_fields))
         or (f = 'tags' and is_gd and spec and not coalesce(was_spec, false)) then locked_changes := locked_changes || jsonb_build_object(f, clean->>f);
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

-- review_post: every note and review goes through here. Nobody writes on his own page. A guide's note on another
-- guide's page waits for approval unless it is private. An organisation's review is live at once, private or not.
create or replace function public.review_post(p_token text, p_vendor text, p_body text, p_rating text, p_private boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors; st text := 'approved'; pr boolean;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if public._is_own(v, m) then raise exception 'You cannot add a note to your own page.'; end if;
  pr := coalesce(p_private, false);   -- an organisation may keep a review private too; otherwise its review is for everyone, at once (D-15)
  if not m.is_admin and not pr and public._is_guide(v) and public._is_guide_member(m) then st := 'pending'; end if;
  insert into public.vendor_notes (vendor_id, body, author, author_name, org, rating, private, status)
  values (p_vendor, trim(p_body), m.email, m.name, public._limited(m), case when coalesce(p_rating,'') ~ '^[1-5]$' then p_rating else '' end, pr, st);
  return json_build_object('status', st, 'private', pr);
end $function$;
revoke all on function public.review_post(text,text,text,text,boolean) from public; grant execute on function public.review_post(text,text,text,text,boolean) to anon, authenticated;

-- note_add and review_add stay for copies of the app that are already open; they follow the same rules.
CREATE OR REPLACE FUNCTION public.note_add(p_token text, p_vendor text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public.review_post(p_token, p_vendor, p_body, '', false);
end $function$;

create or replace function public.review_add(p_token text, p_vendor text, p_body text, p_rating text default ''::text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public.review_post(p_token, p_vendor, p_body, p_rating, false);
end $function$;

-- driver_review_add: nobody reviews himself or his own company's drivers; a review can be kept private.
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
  if exists (select 1 from public.drivers d where d.id = p_driver and public._driver_own(d, m)) then raise exception 'You cannot review yourself or your own company''s drivers.'; end if;
  if coalesce(p_review->>'rating','') !~ '^[1-5]$' then raise exception 'Give a rating from 1 to 5.'; end if;
  if vid is not null then
    perform public._visible(vid, m.is_admin);
    if not exists (select 1 from public.vendors where id = vid) then raise exception 'That supplier no longer exists.'; end if;
    insert into public.driver_vendors (driver_id, vendor_id, added_by) values (p_driver, vid, m.email) on conflict do nothing;
  end if;
  insert into public.driver_reviews (driver_id, vendor_id, rating, tags, body, trip_month, author, author_name, org, private)
  values (p_driver, vid, p_review->>'rating', left(trim(coalesce(p_review->>'tags','')),300), left(trim(coalesce(p_review->>'body','')),1500),
    case when coalesce(p_review->>'trip_month','') ~ '^\d{4}-\d{2}$' then p_review->>'trip_month' else '' end, m.email, m.name, public._limited(m),
    coalesce(p_review->>'private','') in ('true','t'))
  returning id into rid;
  return rid;
end $function$;

-- vendor_reports_list: says when a report is a dispute from the member whose page it is.
CREATE OR REPLACE FUNCTION public.vendor_reports_list(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',r.id,'vendor_id',r.vendor_id,'vendor_name',v.name,'kind',r.kind,'message',r.message,'anonymous',r.anonymous,
    'author_name',case when r.anonymous then '' else r.author_name end,'author',case when r.anonymous then '' else r.author end,'status',r.status,'by_owner',r.by_owner,'created_at',r.created_at) order by (r.status='New') desc, r.created_at desc)
    from public.vendor_reports r join public.vendors v on v.id = r.vendor_id where r.status = 'New' or r.created_at > now() - interval '30 days'), '[]'::json);
end $function$;

-- ===== 5. new RPCs (member token) =====
-- Save the bio and the retail price on a guide's page.
create or replace function public.vendor_set_client(p_token text, p_vendor text, p_bio text, p_retail text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors; b text := trim(coalesce(p_bio,'')); rt text := trim(coalesce(p_retail,''));
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if not public._is_guide(v) then raise exception 'Only a guide''s page has a section for clients.'; end if;
  if public._limited(m) then raise exception 'This section is written by guides, agents and Eretz Israel Tours.' using errcode = '42501'; end if;
  -- once a guide has claimed his page, only he and Eretz Israel Tours write what clients see
  if v.claimed_by <> '' and not m.is_admin and v.claimed_by <> m.email then raise exception 'This guide has claimed the page, so only they can change what clients see.'; end if;
  if length(b) > 1500 then raise exception 'Keep the bio under 1,500 characters.'; end if;
  if length(rt) > 200 then raise exception 'Keep the retail price under 200 characters.'; end if;
  -- a colleague neither sees nor changes a price on a supplier whose prices are private
  if v.prices_private and not m.is_admin then rt := v.retail_price; end if;
  update public.vendors set client_bio = b, retail_price = rt where id = p_vendor;
  return public._vendor_view(p_vendor, m.is_admin, m.email);
end $function$;
revoke all on function public.vendor_set_client(text,text,text,text) from public; grant execute on function public.vendor_set_client(text,text,text,text) to anon, authenticated;

-- Mark a photo as one of the guide's pictures for clients, or take the mark off. Four at most per guide.
create or replace function public.file_for_clients(p_token text, p_file uuid, p_on boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; f public.vendor_files; v public.vendors; n int;
begin
  m := public._auth(p_token);
  select * into f from public.vendor_files where id = p_file;
  if f.id is null or (f.private and not m.is_admin and f.uploaded_by <> m.email) then raise exception 'That picture no longer exists.'; end if;
  perform public._visible(f.vendor_id, m.is_admin);
  if public._limited(m) then raise exception 'This section is written by guides, agents and Eretz Israel Tours.' using errcode = '42501'; end if;
  if exists (select 1 from public.vendors x where x.id = f.vendor_id and x.claimed_by <> '' and not m.is_admin and x.claimed_by <> m.email) then
    raise exception 'This guide has claimed the page, so only they can change what clients see.'; end if;
  if coalesce(p_on, false) then
    -- one at a time per guide, so two people adding at once cannot pass four
    select * into v from public.vendors where id = f.vendor_id for update;
    if not public._is_guide(v) then raise exception 'Only a guide''s page has pictures for clients.'; end if;
    if f.quote_id is not null then raise exception 'A file attached to a quote cannot be a picture for clients.'; end if;
    if f.private then raise exception 'A file marked "only me" cannot be a picture for clients.'; end if;
    if f.mime_type !~ '^image/(jpeg|png|webp)$' then raise exception 'Use a JPEG, PNG or WebP picture.'; end if;
    if (select count(*) from public.vendor_files x where x.vendor_id = f.vendor_id and x.for_clients and x.id <> f.id) >= 4 then
      raise exception 'Four pictures at most. Remove one first.'; end if;
  end if;
  update public.vendor_files set for_clients = coalesce(p_on, false) where id = p_file;
  select count(*) into n from public.vendor_files x where x.vendor_id = f.vendor_id and x.for_clients;
  return json_build_object('ok', true, 'for_clients', coalesce(p_on, false), 'n', n);
end $function$;
revoke all on function public.file_for_clients(text,uuid,boolean) from public; grant execute on function public.file_for_clients(text,uuid,boolean) to anon, authenticated;

-- A member says "this page is me, or my business". Eretz Israel Tours decides.
create or replace function public.vendor_claim(p_token text, p_vendor text, p_note text default ''::text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if m.is_admin then raise exception 'Eretz Israel Tours links a page to a member from the page itself.'; end if;
  -- an organisation is not a supplier on the list (D-15); if a school should own a page, Eretz Israel Tours links it
  if public._limited(m) then raise exception 'Claiming a page is for the guides, agents and suppliers on the list.' using errcode = '42501'; end if;
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if v.claimed_by = m.email then raise exception 'This page is already yours.'; end if;
  if v.claimed_by <> '' then raise exception 'Someone has already claimed this page. If that is wrong, tell Eretz Israel Tours through Feedback.'; end if;
  if (select count(*) from public.vendor_claims c where c.member = m.email and c.status = 'pending' and c.vendor_id <> p_vendor) >= 5 then
    raise exception 'You already have several claims waiting.'; end if;
  insert into public.vendor_claims (vendor_id, member, member_name, note) values (p_vendor, m.email, m.name, left(trim(coalesce(p_note,'')), 500))
    on conflict (vendor_id, member) where (status = 'pending'::text) do update set note = excluded.note;
  return json_build_object('ok', true, 'status', 'pending');
end $function$;
revoke all on function public.vendor_claim(text,text,text) from public; grant execute on function public.vendor_claim(text,text,text) to anon, authenticated;

-- For Eretz Israel Tours: the claims waiting. match = the member's own phone or email is on that page.
create or replace function public.claims_list(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',c.id,'vendor_id',c.vendor_id,'vendor_name',v.name,'category',v.category,
      'member_id',mm.id,'member_name',coalesce(mm.name, c.member_name),'role',case when mm.org <> '' then mm.org else coalesce(mm.role,'') end,'note',c.note,
      'match',coalesce(public._is_own(v, mm), false),'created_at',c.created_at) order by c.created_at)
    from public.vendor_claims c join public.vendors v on v.id = c.vendor_id
      left join public.members mm on mm.email = c.member and mm.status = 'approved'
    where c.status = 'pending'), '[]'::json);
end $function$;
revoke all on function public.claims_list(text) from public; grant execute on function public.claims_list(text) to anon, authenticated;

create or replace function public.claim_decide(p_token text, p_id uuid, p_approve boolean)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members; c public.vendor_claims;
begin
  m := public._auth(p_token, true);
  select * into c from public.vendor_claims where id = p_id and status = 'pending' for update;
  if c.id is null then raise exception 'That claim was already handled.'; end if;
  if coalesce(p_approve, false) then
    if not exists (select 1 from public.members where email = c.member and status = 'approved') then raise exception 'That member is no longer active.'; end if;
    update public.vendors set claimed_by = c.member, claimed_at = now() where id = c.vendor_id;
    update public.vendor_claims set status = 'rejected', decided_by = m.email, decided_at = now() where vendor_id = c.vendor_id and status = 'pending' and id <> p_id;
  end if;
  update public.vendor_claims set status = case when coalesce(p_approve, false) then 'approved' else 'rejected' end, decided_by = m.email, decided_at = now() where id = p_id;
end $function$;
revoke all on function public.claim_decide(text,uuid,boolean) from public; grant execute on function public.claim_decide(text,uuid,boolean) to anon, authenticated;

-- Eretz Israel Tours links a page to a member directly, or takes the link off (p_member null).
create or replace function public.vendor_set_claim(p_token text, p_vendor text, p_member uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; t public.members;
begin
  m := public._auth(p_token, true);
  if not exists (select 1 from public.vendors where id = p_vendor) then raise exception 'That supplier no longer exists.'; end if;
  if p_member is null then
    update public.vendors set claimed_by = '', claimed_at = null where id = p_vendor;
  else
    select * into t from public.members where id = p_member and status = 'approved' and not is_admin;
    if t.id is null then raise exception 'Choose an approved member.'; end if;
    update public.vendors set claimed_by = t.email, claimed_at = now() where id = p_vendor;
    update public.vendor_claims set status = case when member = t.email then 'approved' else 'rejected' end, decided_by = m.email, decided_at = now()
      where vendor_id = p_vendor and status = 'pending';
  end if;
  return public._vendor_view(p_vendor, true);
end $function$;
revoke all on function public.vendor_set_claim(text,text,uuid) from public; grant execute on function public.vendor_set_claim(text,text,uuid) to anon, authenticated;

-- The member whose page it is disputes something on it. It lands with the supplier updates in Review.
create or replace function public.vendor_dispute(p_token text, p_vendor text, p_message text)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null or not public._is_own(v, m) then raise exception 'Only the person whose page this is can dispute it. Use "Update this supplier" instead.'; end if;
  if length(trim(coalesce(p_message,''))) < 5 then raise exception 'Say what is wrong, and what it should be.'; end if;
  if (select count(*) from public.vendor_reports where author = m.email and created_at > now() - interval '1 hour') > 20 then raise exception 'Too many reports in a short time. Try again later.'; end if;
  insert into public.vendor_reports (vendor_id, kind, message, anonymous, author, author_name, by_owner)
    values (p_vendor, 'Mistake', left(trim(p_message), 2000), false, m.email, m.name, true);
end $function$;
revoke all on function public.vendor_dispute(text,text,text) from public; grant execute on function public.vendor_dispute(text,text,text) to anon, authenticated;

-- Eretz Israel Tours approves or turns down a guide's note about another guide.
create or replace function public.note_decide(p_token text, p_id uuid, p_approve boolean)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token, true);
  update public.vendor_notes set status = case when coalesce(p_approve, false) then 'approved' else 'rejected' end, decided_by = m.email, decided_at = now()
    where id = p_id and status = 'pending';
  if not found then raise exception 'That note was already handled.'; end if;
end $function$;
revoke all on function public.note_decide(text,uuid,boolean) from public; grant execute on function public.note_decide(text,uuid,boolean) to anon, authenticated;

-- For Eretz Israel Tours: the notes waiting for approval.
create or replace function public.notes_pending(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('id',n.id,'vendor_id',n.vendor_id,'vendor_name',v.name,'body',n.body,
      'author_name',n.author_name,'by',public._who(n.author),'created_at',n.created_at) order by n.created_at)
    from public.vendor_notes n join public.vendors v on v.id = n.vendor_id where n.status = 'pending'), '[]'::json);
end $function$;
revoke all on function public.notes_pending(text) from public; grant execute on function public.notes_pending(text) to anon, authenticated;
