-- Claimed pages (3 Oct 2026). See docs/DECISIONS.md D-14. Run after 2026-10-03b_guide_for_clients.sql.
-- supabase/schema.sql already includes everything below. Safe to run twice. No statement here removes anything.
--
--   1. A member can claim the supplier page that is his own (himself as a guide or driver, or his business).
--      Eretz Israel Tours approves the claim, or links a page to a member directly.
--   2. Until a guide's page is claimed, any member can fill in its section for clients. Once claimed, only that
--      member and Eretz Israel Tours can.
--   3. What colleagues wrote ABOUT a supplier is hidden from the member whose page it is, and stays visible to
--      everyone else: the ratings, strengths, weaknesses and notes on the page, the notes thread, and the reviews of
--      his drivers or of himself as a driver. This holds for a claimed page, and also for an unclaimed page that
--      carries the member's own phone number or email, so that not claiming is not a way round it.
--   4. The member whose page it is can dispute anything on it: the dispute goes to Eretz Israel Tours in Review.
--   5. A guide's review of another guide waits for approval by Eretz Israel Tours before colleagues see it: a note in
--      the notes thread of a guide's page, or a change to its ratings, strengths, weaknesses or notes.
--      "A guide" is a member whose role is Licensed tour guide, or who has claimed a guide's page.
--   6. A note or a driver review can be kept private: only its author and Eretz Israel Tours see it.

-- ===== columns and table =====
alter table public.vendors
  add column if not exists claimed_by text default ''::text not null,
  add column if not exists claimed_at timestamp with time zone;
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
create index if not exists vendors_claimed_by_idx on public.vendors using btree (claimed_by) where (claimed_by <> ''::text);
revoke all on table public.vendor_claims from public, anon, authenticated;
grant all on table public.vendor_claims to service_role;

-- ===== internal helpers (not RPCs) =====
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

-- ===== _vendor_view: what a colleague receives of a supplier =====
-- New: on his own page a member gets no ratings, strengths, weaknesses, notes or note count; nobody but
-- Eretz Israel Tours gets the claimer's email; everyone gets whether the page is claimed and by whom (a name).
-- The note count a colleague gets leaves out private notes and notes waiting for approval, unless they are his.
CREATE OR REPLACE FUNCTION public._vendor_view(p_id text, p_admin boolean, p_email text DEFAULT ''::text)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when p_admin then (public._vendor_json(p_id)::jsonb || jsonb_build_object('_prices',(select count(*) from public.vendor_prices p where p.vendor_id=p_id),
      '_claimed', v.claimed_by <> '', 'claimed_name', public._name(v.claimed_by), '_mine', false, '_own', false))::json
  else (
    (public._vendor_json(p_id)::jsonb
      || case when v.prices_private then jsonb_build_object('agentPrice','','listedPrice','','agentPriceVatTreatment','','listedPriceVatTreatment','','maxPax','','retail_price','') else '{}'::jsonb end
      || case when o.own then jsonb_build_object('rateReliability','','rateService','','rateValue','','strengths','','weaknesses','','notes','') else '{}'::jsonb end)
      || jsonb_build_object('_prices', (select count(*) from public.vendor_prices p where p.vendor_id=p_id and ((p.owner <> '' and p.owner = p_email) or (p.owner = '' and not v.prices_private and not p.private))),
                            'created_by', public._name(v.created_by), 'updated_by', public._name(v.updated_by), 'hours_verified_by', public._name(v.hours_verified_by),
                            'claimed_by', '', '_claimed', v.claimed_by <> '', 'claimed_name', public._name(v.claimed_by),
                            '_mine', v.claimed_by <> '' and v.claimed_by = p_email, '_own', o.own,
                            '_notes', case when o.own then 0 else (select count(*) from public.vendor_notes n where n.vendor_id = p_id and (n.author = p_email or (n.status = 'approved' and not n.private))) end)
  )::json end
  from public.vendors v
  left join lateral (select coalesce((select public._is_own(v, mm) from public.members mm where mm.email = p_email and mm.status = 'approved' order by mm.created_at limit 1), false) as own) o on true
  where v.id = p_id
$function$;

-- ===== _driver_json: reviews of a driver are not shown to the driver himself or to the member whose company it is;
-- a private review is shown only to its author and Eretz Israel Tours, and does not count in the average others see =====
CREATE OR REPLACE FUNCTION public._driver_json(d drivers, p_email text, p_admin boolean)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select json_build_object('id',d.id,'name',d.name,'phone',d.phone,'drives',d.drives,
    'can_edit', p_admin or d.created_by = p_email,
    'n',case when h.hide then 0 else (select count(*) from public.driver_reviews r where r.driver_id = d.id and (p_admin or not r.private or r.author = p_email)) end,
    'avg',case when h.hide then null else (select round(avg(r.rating::int)::numeric, 1) from public.driver_reviews r where r.driver_id = d.id and (p_admin or not r.private or r.author = p_email)) end,
    'vendors',coalesce((select json_agg(json_build_object('id',v.id,'name',v.name) order by v.name)
        from public.driver_vendors dv join public.vendors v on v.id = dv.vendor_id where dv.driver_id = d.id and (p_admin or not v.hidden)),'[]'::json),
    'reviews',case when h.hide then '[]'::json else coalesce((select json_agg(json_build_object('id',r.id,'rating',r.rating,'tags',r.tags,'body',r.body,'trip_month',r.trip_month,
          'vendor_id',case when v.id is not null and (p_admin or not v.hidden) then v.id end,
          'vendor_name',case when v.id is not null and (p_admin or not v.hidden) then v.name end,
          'by',public._who(r.author),'mine',r.author = p_email,'private',r.private,'created_at',r.created_at) order by r.created_at desc)
        from public.driver_reviews r left join public.vendors v on v.id = r.vendor_id where r.driver_id = d.id and (p_admin or not r.private or r.author = p_email)),'[]'::json) end,
    'reviews_hidden', h.hide)
  from (select (not p_admin) and exists (select 1 from public.members mm where mm.email = p_email and mm.status = 'approved' and public._driver_own(d, mm)) as hide) h
$function$;

-- ===== existing RPCs, changed =====
-- vendor_detail: no notes thread on a member's own page; a private note, or one waiting for approval, goes only to
-- its author and Eretz Israel Tours; whether the page is his (own), whether his claim is
-- waiting (my_claim); for Eretz Israel Tours, who claimed it and which members' phone or email is on it.
CREATE OR REPLACE FUNCTION public.vendor_detail(p_token text, p_id text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; pp boolean; own boolean;
begin
  m := public._auth(p_token);
  if not m.is_admin and exists (select 1 from public.vendors where id = p_id and hidden) then raise exception 'That supplier is not available.'; end if;
  select prices_private into pp from public.vendors where id = p_id;
  -- colleagues' notes about a member's own page are not shown to that member
  select coalesce(public._is_own(v, m), false) into own from public.vendors v where v.id = p_id;
  return json_build_object(
    'prices', coalesce((select json_agg(json_build_object('id',p.id,'vendor_id',p.vendor_id,'label',p.label,'audience',p.audience,'age_from',p.age_from,'age_to',p.age_to,'pax_min',p.pax_min,'pax_max',p.pax_max,'season',p.season,'price',p.price,'currency',p.currency,'vat',p.vat,'basis',p.basis,'is_agent',p.is_agent,'source',p.source,'checked_on',p.checked_on,'note',p.note,'private',p.private,'sort',p.sort,
          'owner',p.owner,'mine',(p.owner <> '' and p.owner = m.email),
          'by',public._who(case when p.owner <> '' then p.owner else p.created_by end),'by_date',p.updated_at)
        order by (p.owner <> ''), p.sort, p.audience, p.created_at)
      from public.vendor_prices p where p.vendor_id = p_id
        and (m.is_admin or (p.owner <> '' and p.owner = m.email) or (p.owner = '' and not pp and not p.private))), '[]'),
    'prices_private', coalesce(pp,false),
    'deals', coalesce((select json_agg(case when m.is_admin then to_jsonb(d) else to_jsonb(d) || jsonb_build_object('reported_by', public._name(d.reported_by)) end order by (d.valid_to <> '' and d.valid_to < to_char(now(),'YYYY-MM-DD')), d.created_at desc) from public.vendor_deals d where d.vendor_id = p_id), '[]'),
    'notes', case when own then '[]'::json else coalesce((select json_agg(case when m.is_admin then to_jsonb(n) || jsonb_build_object('mine', n.author = m.email)
          else to_jsonb(n) || jsonb_build_object('author', public._name(n.author), 'decided_by', '', 'mine', n.author = m.email) end order by n.created_at desc)
        from public.vendor_notes n where n.vendor_id = p_id and (m.is_admin or n.author = m.email or (n.status = 'approved' and not n.private))), '[]') end,
    'requests', coalesce((select json_agg(c order by c.created_at desc) from public.change_requests c where c.vendor_id = p_id and c.status = 'pending' and (m.is_admin or c.requested_by = m.email)), '[]'),
    'admin_note', case when m.is_admin then (select body from public.vendor_admin_notes a where a.vendor_id = p_id) else null end,
    'sites', coalesce((select json_agg(json_build_object('id',s.id,'name',s.name,'location',s.location,'reservation',s.reservation) order by s.name) from public.vendors s where s.parent_id = p_id and (m.is_admin or not s.hidden)), '[]'),
    'parent', (select json_build_object('id',pv.id,'name',pv.name) from public.vendors v join public.vendors pv on pv.id = v.parent_id where v.id = p_id and (m.is_admin or not pv.hidden)),
    'res_reports', coalesce((select json_agg(json_build_object('checked',r.checked,'visit_date',r.visit_date,'note',r.note,'member_name',r.member_name,'created_at',r.created_at,'mine',r.member = m.email) order by r.created_at desc) from (select * from public.reservation_reports where vendor_id = p_id order by created_at desc limit 20) r), '[]'),
    'res_answered', exists (select 1 from public.reservation_reports where vendor_id = p_id and member = m.email),
    'deal_by', coalesce((select json_object_agg(d.id, public._who(d.reported_by)) from public.vendor_deals d where d.vendor_id = p_id), '{}'),
    'note_by', case when own then '{}'::json else coalesce((select json_object_agg(n.id, public._who(n.author)) from public.vendor_notes n where n.vendor_id = p_id and (m.is_admin or n.author = m.email or (n.status = 'approved' and not n.private))), '{}') end,
    'own', coalesce(own, false),
    'my_claim', exists (select 1 from public.vendor_claims c where c.vendor_id = p_id and c.member = m.email and c.status = 'pending'),
    'claimer', case when m.is_admin then (select json_build_object('id',mm.id,'name',mm.name,'role',mm.role) from public.members mm join public.vendors v on v.claimed_by = mm.email where v.id = p_id order by mm.created_at limit 1) end,
    'matches', case when m.is_admin then coalesce((select json_agg(json_build_object('id',mm.id,'name',mm.name,'role',mm.role) order by mm.name)
        from public.members mm, public.vendors v where v.id = p_id and mm.status = 'approved' and v.claimed_by <> mm.email and public._is_own(v, mm)), '[]'::json) end
  );
end $function$;

-- vendor_save: a member's save of his own page leaves the ratings and remarks as they are; a guide's change to
-- another guide's ratings or remarks becomes a change request.
CREATE OR REPLACE FUNCTION public.vendor_save(p_token text, p_data jsonb, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; r public.vendors; f text; clean jsonb := '{}'::jsonb; cur jsonb; locked_changes jsonb := '{}'::jsonb; open_vals jsonb := '{}'::jsonb; req boolean := false;
  price_fields text[] := array['agentPrice','listedPrice','agentPriceVatTreatment','listedPriceVatTreatment','maxPax'];
  is_rest boolean; no_cert boolean; own boolean := false; gog boolean := false; curv public.vendors;
  review_fields text[] := array['rateReliability','rateService','rateValue','strengths','weaknesses','notes'];
begin
  m := public._auth(p_token);
  foreach f in array public._all_fields() loop
    clean := clean || jsonb_build_object(f, left(coalesce(p_data->>f,''), 2000));
  end loop;
  -- Kosher rule (D-7, D-8): no non-kosher restaurants; a restaurant that is kosher without a certificate is an exception Eretz Israel Tours approves.
  is_rest := (clean->>'category') = 'Restaurant' or (clean->>'also_categories') ~* '(^|,)\s*Restaurant\s*(,|$)';
  if is_rest and (clean->>'kosher') ~* '^\s*(not kosher|non[- ]?kosher|kosher[- ]style)' then raise exception 'The list does not accept non-kosher restaurants.'; end if;
  no_cert := is_rest and (clean->>'kosher') ~* '^\s*kosher\W+(no|without)\s+(certificate|certification|teuda|teudah|hechsher)';
  if coalesce(p_data->>'id','') = '' then
    select * into r from jsonb_populate_record(null::public.vendors, clean);
    insert into public.vendors (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link,hours,hours_last)
    values (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link,r.hours,r.hours_last)
    returning * into r;
    -- a member who adds his own business does not rate it
    if public._is_own(r, m) then update public.vendors set "rateReliability" = '', "rateService" = '', "rateValue" = '', strengths = '', weaknesses = '' where id = r.id; end if;
    return json_build_object('vendor', public._vendor_view(r.id, m.is_admin, m.email), 'request', false);
  end if;
  select to_jsonb(v) into cur from public.vendors v where v.id = p_data->>'id';
  if cur is null then raise exception 'That supplier no longer exists.'; end if;
  -- An app version from before opening hours existed sends no "hours": keep what is stored.
  if not (p_data ? 'hours') then clean := clean || jsonb_build_object('hours', coalesce(cur->>'hours','')); end if;
  if not (p_data ? 'hours_last') then clean := clean || jsonb_build_object('hours_last', coalesce(cur->>'hours_last','')); end if;
  if m.is_admin then
    r := public._vendor_apply(p_data->>'id', clean);
    return json_build_object('vendor', public._vendor_view(r.id, true), 'request', false);
  end if;
  if (cur->>'hidden')::boolean then raise exception 'That supplier is not available.'; end if;
  -- ratings and colleagues' remarks on a member's own page are hidden from him, so his save leaves them as they are
  curv := jsonb_populate_record(null::public.vendors, cur);
  own := coalesce(public._is_own(curv, m), false);
  -- a guide's change to another guide's ratings or remarks is a review: Eretz Israel Tours approves it first
  gog := public._is_guide(curv) and public._is_guide_member(m);
  foreach f in array public._all_fields() loop
    if (cur->>'prices_private')::boolean and f = any(price_fields) then continue; end if;
    if own and f = any(review_fields) then continue; end if;
    if (clean->>f) is distinct from coalesce(cur->>f,'') then
      if f = any(public._locked_fields()) or (f = 'kosher' and no_cert) or (gog and f = any(review_fields)) then locked_changes := locked_changes || jsonb_build_object(f, clean->>f);
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

-- note_post: add a note, private or not. Nobody adds a note to his own page. A guide's note on another guide's
-- page waits for approval unless it is private.
create or replace function public.note_post(p_token text, p_vendor text, p_body text, p_private boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors; st text := 'approved'; pr boolean := coalesce(p_private, false);
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if public._is_own(v, m) then raise exception 'You cannot add a note to your own page.'; end if;
  if not m.is_admin and not pr and public._is_guide(v) and public._is_guide_member(m) then st := 'pending'; end if;
  insert into public.vendor_notes (vendor_id, body, author, author_name, private, status) values (p_vendor, trim(p_body), m.email, m.name, pr, st);
  return json_build_object('status', st, 'private', pr);
end $function$;
revoke all on function public.note_post(text,text,text,boolean) from public; grant execute on function public.note_post(text,text,text,boolean) to anon, authenticated;

-- note_add (older copies of the app): the same rules, never private.
CREATE OR REPLACE FUNCTION public.note_add(p_token text, p_vendor text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  perform public.note_post(p_token, p_vendor, p_body, false);
end $function$;

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
  if not exists (select 1 from public.drivers where id = p_driver) then raise exception 'That driver is no longer on the list.'; end if;
  if exists (select 1 from public.drivers d where d.id = p_driver and public._driver_own(d, m)) then raise exception 'You cannot review yourself or your own company''s drivers.'; end if;
  if coalesce(p_review->>'rating','') !~ '^[1-5]$' then raise exception 'Give a rating from 1 to 5.'; end if;
  if vid is not null then
    perform public._visible(vid, m.is_admin);
    if not exists (select 1 from public.vendors where id = vid) then raise exception 'That supplier no longer exists.'; end if;
    insert into public.driver_vendors (driver_id, vendor_id, added_by) values (p_driver, vid, m.email) on conflict do nothing;
  end if;
  insert into public.driver_reviews (driver_id, vendor_id, rating, tags, body, trip_month, author, author_name, private)
  values (p_driver, vid, p_review->>'rating', left(trim(coalesce(p_review->>'tags','')),300), left(trim(coalesce(p_review->>'body','')),1500),
    case when coalesce(p_review->>'trip_month','') ~ '^\d{4}-\d{2}$' then p_review->>'trip_month' else '' end, m.email, m.name,
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

-- vendor_set_client, file_for_clients: once a guide has claimed his page, only he and Eretz Israel Tours write it.
create or replace function public.vendor_set_client(p_token text, p_vendor text, p_bio text, p_retail text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors; b text := trim(coalesce(p_bio,'')); rt text := trim(coalesce(p_retail,''));
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if not public._is_guide(v) then raise exception 'Only a guide''s page has a section for clients.'; end if;
  -- once a guide has claimed his page, only he and Eretz Israel Tours write what clients see
  if v.claimed_by <> '' and not m.is_admin and v.claimed_by <> m.email then raise exception 'This guide has claimed the page, so only they can change what clients see.'; end if;
  if length(b) > 1500 then raise exception 'Keep the bio under 1,500 characters.'; end if;
  if length(rt) > 200 then raise exception 'Keep the retail price under 200 characters.'; end if;
  -- a colleague neither sees nor changes a price on a supplier whose prices are private
  if v.prices_private and not m.is_admin then rt := v.retail_price; end if;
  update public.vendors set client_bio = b, retail_price = rt where id = p_vendor;
  return public._vendor_view(p_vendor, m.is_admin, m.email);
end $function$;

create or replace function public.file_for_clients(p_token text, p_file uuid, p_on boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; f public.vendor_files; v public.vendors; n int;
begin
  m := public._auth(p_token);
  select * into f from public.vendor_files where id = p_file;
  if f.id is null or (f.private and not m.is_admin and f.uploaded_by <> m.email) then raise exception 'That picture no longer exists.'; end if;
  perform public._visible(f.vendor_id, m.is_admin);
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

-- ===== new RPCs (member token) =====
-- A member says "this page is me, or my business". Eretz Israel Tours decides.
create or replace function public.vendor_claim(p_token text, p_vendor text, p_note text default ''::text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if m.is_admin then raise exception 'Eretz Israel Tours links a page to a member from the page itself.'; end if;
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
      'member_id',mm.id,'member_name',coalesce(mm.name, c.member_name),'role',coalesce(mm.role,''),'note',c.note,
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
