-- D-57 (17 Oct 2026): a confirmed mark on each price line (S1) and a read-only door for the Cockpit (S2).
-- The owner, 17 Oct 2026: "1 yes" (a one-way connection, supplier app to Cockpit, only on his click: "The cockpit reads
-- Inner Circle prices one way, only when you click, and nothing in Inner Circle ever changes a trip") and "2 OK. But I am
-- inner circle. It's my app." (these two supplier-app pieces). Rules: D-1, F1, F2, F4, D1-D7, E1, E2, E4, G1-G12.
--
-- Adds only. No DELETE, no DROP, no table grant, no policy. Safe to run twice.
--
-- S1. Four new fields on a price line: confirmed_at, confirmed_by ('Eretz Israel Tours' or a member id), confirmed_how
--     (official_list, supplier_document, paid_invoice, supplier_conversation) and kind (tariff, negotiated).
--     Every existing line starts unconfirmed. Nothing but price_confirm can set the mark: a load, an import, a website,
--     a colleague's list or an ordinary save never does (E1, E2). Changing the amount, currency, VAT, basis, who it is
--     for, ages, group size, agent or public, or season clears the confirmation again. The "Verified" text at the start
--     of a source stays as it is and is not read as confirmed. Only Eretz Israel Tours sets or sees the mark (G2).
-- S2. cockpit_supplier_prices(token, supplier id) and cockpit_supplier_search(token, text), read only, for one reader
--     credential kept in its own table (cockpit_readers). A member's link, Eretz Israel Tours' included, cannot open
--     them, and the reader credential opens nothing else (every other function checks members through _auth).
--     The reader returns a supplier's shared lines and Eretz Israel Tours' own lines, private ones included, never
--     another member's personal or private line and never a member's email, phone or license number (D1, D4).
--     Once the reader has returned a supplier (cockpit_reads), deleting that supplier or one of its lines archives it
--     instead: nothing cascades, and the reader returns it marked archived. The app no longer shows archived lines or
--     suppliers. Before the first read nothing changes in how deleting works.
--     The credential is minted and revoked in the Supabase SQL editor only (_cockpit_reader_mint, _cockpit_reader_revoke).
--     It is not minted here.

-- ===== S1: the confirmed mark; S2: archive marks =====
alter table public.vendor_prices add column if not exists confirmed_at timestamp with time zone;
alter table public.vendor_prices add column if not exists confirmed_by text not null default '';
alter table public.vendor_prices add column if not exists confirmed_how text not null default '';
alter table public.vendor_prices add column if not exists kind text not null default '';
alter table public.vendor_prices add column if not exists archived_at timestamp with time zone;
alter table public.vendors add column if not exists archived_at timestamp with time zone;
alter table public.vendors add column if not exists merged_into text not null default '';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'vendor_prices_confirmed_check') then
    alter table public.vendor_prices add constraint vendor_prices_confirmed_check check (
      confirmed_how = any (array[''::text, 'official_list'::text, 'supplier_document'::text, 'paid_invoice'::text, 'supplier_conversation'::text])
      and kind = any (array[''::text, 'tariff'::text, 'negotiated'::text])
      and length(confirmed_by) <= 60
      and ((confirmed_at is null and confirmed_by = '' and confirmed_how = '') or (confirmed_at is not null and confirmed_by <> '' and confirmed_how <> '')));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'vendors_merged_into_check') then
    alter table public.vendors add constraint vendors_merged_into_check check (length(merged_into) <= 40);
  end if;
end $$;

-- ===== S2: the reader credential and the read note =====
create table if not exists public.cockpit_readers (
  id uuid default gen_random_uuid() not null,
  name text not null,
  token_hash text not null,
  created_at timestamp with time zone default now() not null,
  revoked_at timestamp with time zone,
  last_used_at timestamp with time zone,
  constraint cockpit_readers_pkey primary key (id),
  constraint cockpit_readers_token_hash_key unique (token_hash),
  constraint cockpit_readers_name_check check (length(trim(name)) between 1 and 60)
);
alter table public.cockpit_readers enable row level security;

create table if not exists public.cockpit_reads (
  vendor_id text not null,
  first_read_at timestamp with time zone default now() not null,
  last_read_at timestamp with time zone default now() not null,
  reads integer default 1 not null,
  constraint cockpit_reads_pkey primary key (vendor_id)
);
alter table public.cockpit_reads enable row level security;
revoke all on table public.cockpit_readers, public.cockpit_reads from public, anon, authenticated;
grant all on table public.cockpit_readers, public.cockpit_reads to service_role;

-- ===== Triggers =====
-- S1: the mark is set only through price_confirm (app.confirm = on). A changed price clears it.
-- S2: archived_at is set only by the delete triggers below (app.archive = on).
create or replace function public._price_mark_guard()
 returns trigger language plpgsql set search_path to ''
as $function$
begin
  if coalesce(current_setting('app.confirm', true), '') <> 'on' then
    if tg_op = 'INSERT' then
      new.confirmed_at := null; new.confirmed_by := ''; new.confirmed_how := ''; new.kind := '';
    else
      new.confirmed_at := old.confirmed_at; new.confirmed_by := old.confirmed_by; new.confirmed_how := old.confirmed_how; new.kind := old.kind;
      if (new.price, new.currency, new.vat, new.basis, new.audience, new.age_from, new.age_to, new.pax_min, new.pax_max, new.is_agent, new.season)
         is distinct from (old.price, old.currency, old.vat, old.basis, old.audience, old.age_from, old.age_to, old.pax_min, old.pax_max, old.is_agent, old.season) then
        new.confirmed_at := null; new.confirmed_by := ''; new.confirmed_how := '';
      end if;
    end if;
  end if;
  if coalesce(current_setting('app.archive', true), '') <> 'on' then
    new.archived_at := case when tg_op = 'INSERT' then null else old.archived_at end;
  end if;
  return new;
end $function$;

create or replace function public._price_archive()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  if not exists (select 1 from public.cockpit_reads r where r.vendor_id = old.vendor_id) then return old; end if;
  perform set_config('app.archive', 'on', true);
  update public.vendor_prices set archived_at = coalesce(archived_at, now()) where id = old.id;
  perform set_config('app.archive', 'off', true);
  return null;
end $function$;

create or replace function public._vendor_archive()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  if not exists (select 1 from public.cockpit_reads r where r.vendor_id = old.id) then return old; end if;
  update public.vendors set archived_at = coalesce(archived_at, now()), hidden = true where id = old.id;
  return null;
end $function$;

create or replace trigger vendor_prices_mark_guard before insert or update on public.vendor_prices for each row execute function public._price_mark_guard();
create or replace trigger vendor_prices_archive before delete on public.vendor_prices for each row execute function public._price_archive();
create or replace trigger vendors_archive before delete on public.vendors for each row execute function public._vendor_archive();

-- ===== Replaced: archived lines and suppliers leave the app =====
-- One price line, for one member.
--   Archived lines: nobody (the Cockpit reader returns them marked).
--   Own lines always. Private lines and private-price suppliers: owner and Eretz Israel Tours only.
--   Organisation rates (org): everyone. Another member's personal line: nobody else.
--   A limited member: no agent rates, and no prices at all on a guide unless see_guide_rates.
create or replace function public._price_visible(p public.vendor_prices, v public.vendors, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when p.archived_at is not null then false
    when coalesce(m.is_admin, false) then true
    when p.owner <> '' and p.owner = m.email then true
    when v.prices_private or p.private then false
    when p.org then true
    when p.owner <> '' then false
    when public._limited(m) then (not p.is_agent) and not (v.category = 'Guide' and not m.see_guide_rates)
    else true end
$function$;

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
    from public.vendors v where v.archived_at is null and (m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories)))), '[]'::json);
end $function$;

-- D-54: every transport price line this member may see, across all bus, van and car suppliers, for the Quotes tab.
-- The same rules as on the supplier's own page (_price_visible, _can_see, hidden suppliers); no colleague's name is sent.
-- D-57: archived lines and suppliers are left out, for Eretz Israel Tours too.
CREATE OR REPLACE FUNCTION public.transport_prices(p_token text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(json_build_object('id',p.id,'vendor_id',p.vendor_id,'label',p.label,'audience',p.audience,'pax_min',p.pax_min,'pax_max',p.pax_max,
        'season',p.season,'price',p.price,'currency',p.currency,'vat',p.vat,'basis',p.basis,'is_agent',p.is_agent,'source',p.source,'checked_on',p.checked_on,
        'note',p.note,'private',p.private,'org',p.org,'mine',(p.owner <> '' and p.owner = m.email),'transport',p.transport,'updated_at',p.updated_at)
      order by p.checked_on desc, p.created_at desc)
    from public.vendor_prices p join public.vendors v on v.id = p.vendor_id
    where (v.category = 'Transport' or ',' || replace(coalesce(v.also_categories,''), ', ', ',') || ',' like '%,Transport,%')
      and p.archived_at is null and v.archived_at is null
      and (m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories) and public._price_visible(p, v, m)))), '[]'::json);
end $function$;

-- ===== S1: setting and reading the mark (Eretz Israel Tours only) =====
-- p_how '' takes the mark off. p_kind is kept as given ('' for not said).
create or replace function public.price_confirm(p_token text, p_id uuid, p_how text, p_kind text default '')
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; p public.vendor_prices;
begin
  m := public._auth(p_token, true);
  if coalesce(p_how,'') not in ('', 'official_list', 'supplier_document', 'paid_invoice', 'supplier_conversation') then
    raise exception 'Say how the price was confirmed: official list, the supplier''s own document or email, a paid invoice, or a conversation with the supplier.';
  end if;
  if coalesce(p_kind,'') not in ('', 'tariff', 'negotiated') then raise exception 'A price is a tariff or negotiated.'; end if;
  select * into p from public.vendor_prices where id = p_id;
  if p.id is null or p.archived_at is not null then raise exception 'That price no longer exists.'; end if;
  perform set_config('app.confirm', 'on', true);
  update public.vendor_prices set
      confirmed_at = case when coalesce(p_how,'') = '' then null else now() end,
      confirmed_by = case when coalesce(p_how,'') = '' then '' else 'Eretz Israel Tours' end,
      confirmed_how = coalesce(p_how,''), kind = coalesce(p_kind,'')
    where id = p_id returning * into p;
  perform set_config('app.confirm', 'off', true);
  return json_build_object('id',p.id,'confirmed_at',p.confirmed_at,'confirmed_by',p.confirmed_by,'confirmed_how',p.confirmed_how,'kind',p.kind);
end $function$;

-- The marks on one supplier's lines, for Eretz Israel Tours' own screen: {line id: {confirmed_at, confirmed_by, confirmed_how, kind}}.
create or replace function public.price_marks(p_token text, p_vendor text)
 returns json language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  return coalesce((select json_object_agg(p.id, json_build_object('confirmed_at',p.confirmed_at,'confirmed_by',p.confirmed_by,'confirmed_how',p.confirmed_how,'kind',p.kind))
    from public.vendor_prices p where p.vendor_id = p_vendor and p.archived_at is null and (p.confirmed_at is not null or p.kind <> '')), '{}'::json);
end $function$;

-- ===== S2: the read-only door =====
create or replace function public._reader_auth(p_token text)
 returns public.cockpit_readers language plpgsql security definer set search_path to ''
as $function$
declare r public.cockpit_readers;
begin
  select * into r from public.cockpit_readers where token_hash = public._hash(p_token) and revoked_at is null;
  if r.id is null then raise exception 'This reader key is not active.' using errcode = '28000'; end if;
  update public.cockpit_readers set last_used_at = now() where id = r.id and (last_used_at is null or last_used_at < now() - interval '10 minutes');
  return r;
end $function$;

-- Which lines the Cockpit may read: Eretz Israel Tours' own (no owner, or owned by an Eretz Israel Tours member), private
-- ones included; another member's line only when it is a shared organisation rate on a supplier whose prices are not private.
create or replace function public._cockpit_price_ok(p public.vendor_prices, v public.vendors)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select case when p.owner = '' or exists (select 1 from public.members mm where mm.email = p.owner and mm.is_admin) then true
    when v.prices_private or p.private then false
    when p.org then true
    else false end
$function$;

create or replace function public._cockpit_status(v public.vendors)
 returns text language sql immutable set search_path to ''
as $function$
  select case when v.archived_at is not null then 'archived' when v.review_status = 'rejected' then 'rejected'
    when v.review_status = 'pending' then 'pending' when v.hidden then 'hidden' else 'approved' end
$function$;

-- Supplier search for the Cockpit's linking step: id, name, category, region and status only. Exact name first, then names
-- that start with the text, then names that contain it; at most 25. An id (vendor_...) finds that supplier.
create or replace function public.cockpit_supplier_search(p_token text, p_text text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare q text := trim(regexp_replace(regexp_replace(lower(coalesce(p_text,'')), '\s+', ' ', 'g'), '[.,;:!?]', '', 'g'));
  ql text;
begin
  perform public._reader_auth(p_token);
  if length(q) < 2 then return '[]'::json; end if;
  ql := replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_');
  return coalesce((select json_agg(json_build_object('id',x.id,'name',x.name,'category',x.category,'region',x.region,'status',x.status) order by x.rank, x.name)
    from (select v.id, v.name, v.category, v.region, public._cockpit_status(v) as status, case when v.id = trim(coalesce(p_text,'')) or v.name_norm = q then 0 when v.name_norm like ql || '%' then 1 else 2 end as rank
          from public.vendors v where v.id = trim(coalesce(p_text,'')) or v.name_norm like '%' || ql || '%'
          order by rank, v.name limit 25) x), '[]'::json);
end $function$;

-- One supplier's prices for the Cockpit, read only. Returns the supplier's identity, status, hours and cancellation terms
-- (no contact details) and the lines _cockpit_price_ok allows, archived ones marked. Leaves a read note (cockpit_reads),
-- after which deleting this supplier or its lines in the app archives them instead.
create or replace function public.cockpit_supplier_prices(p_token text, p_supplier_id text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare v public.vendors;
begin
  perform public._reader_auth(p_token);
  select * into v from public.vendors where id = p_supplier_id;
  if v.id is null then
    return json_build_object('supplier', null, 'status', 'gone', 'lines', '[]'::json, 'read_at', now());
  end if;
  insert into public.cockpit_reads (vendor_id) values (v.id)
    on conflict (vendor_id) do update set last_read_at = now(), reads = public.cockpit_reads.reads + 1;
  return json_build_object(
    'supplier', json_build_object('id',v.id,'name',v.name,'category',v.category,'also_categories',v.also_categories,'region',v.region,'parent_id',v.parent_id,
      'status',public._cockpit_status(v),'archived_at',v.archived_at,'merged_into',v.merged_into,'prices_private',v.prices_private,
      'hours',v.hours,'hours_last',v.hours_last,'hours_source',v.hours_source,'hours_verified_at',v.hours_verified_at,'hours_verified_how',v.hours_verified_how,
      'reservation',v.reservation,
      'cancellation',json_build_object('policy',v."cancelPolicy",'notice_amount',v."cancelNoticeAmount",'notice_unit',v."cancelNoticeUnit",
        'day_type',v."cancelDayType",'penalty',v."cancelPenalty",'verified_date',v."cancelPolicyVerifiedDate")),
    'status', public._cockpit_status(v),
    'lines', coalesce((select json_agg(json_build_object('id',p.id,'label',p.label,'audience',p.audience,'age_from',p.age_from,'age_to',p.age_to,
          'pax_min',p.pax_min,'pax_max',p.pax_max,'basis',p.basis,
          'per_job',(v.category in ('Transport','Guide','Vehicle Rental') or v.also_categories ~* '(^|,)\s*(Transport|Guide)\s*(,|$)'
                     or p.basis in ('Per vehicle','Per guide') or p.audience = 'Vehicle' or p.transport <> '{}'::jsonb),
          'transport',p.transport,'is_agent',p.is_agent,'price',p.price,'currency',p.currency,'vat',p.vat,'vat_stated',p.vat <> '',
          'season',p.season,'source',p.source,'checked_on',p.checked_on,
          'loaded',case when p.created_by like 'import%' then p.created_by else '' end,
          'confirmed',p.confirmed_at is not null,'confirmed_at',p.confirmed_at,'confirmed_by',p.confirmed_by,'confirmed_how',p.confirmed_how,'kind',p.kind,
          'private',(p.private or v.prices_private),'eit_own',(p.owner = '' or exists (select 1 from public.members mm where mm.email = p.owner and mm.is_admin)),
          'archived',p.archived_at is not null,'archived_at',p.archived_at,'updated_at',p.updated_at)
        order by (p.archived_at is not null), p.sort, p.audience, p.created_at)
      from public.vendor_prices p where p.vendor_id = v.id and public._cockpit_price_ok(p, v)), '[]'::json),
    'behaviour', 'Read only. Archived suppliers and lines come back with archived set. Once this reader has returned a supplier, deleting that supplier or any of its price lines in the supplier app archives it instead of deleting it, and nothing is cascaded.',
    'read_at', now());
end $function$;

-- ===== S2: minting and revoking the reader credential (Supabase SQL editor only; not callable from outside) =====
-- Mint:   select public._cockpit_reader_mint('Cockpit');   -- shows the key ONCE; only its hash is stored. At most one active.
-- Revoke: select public._cockpit_reader_revoke();          -- revokes every active reader key; the Cockpit is shut out at once.
create or replace function public._cockpit_reader_mint(p_name text)
 returns text language plpgsql security definer set search_path to ''
as $function$
declare t text := 'icr_' || encode(extensions.gen_random_bytes(32), 'hex');
begin
  if exists (select 1 from public.cockpit_readers where revoked_at is null) then
    raise exception 'A reader key is already active. Revoke it first: select public._cockpit_reader_revoke();';
  end if;
  insert into public.cockpit_readers (name, token_hash) values (trim(coalesce(p_name,'')), public._hash(t));
  return t;
end $function$;

create or replace function public._cockpit_reader_revoke()
 returns integer language plpgsql security definer set search_path to ''
as $function$
declare n integer;
begin
  update public.cockpit_readers set revoked_at = now() where revoked_at is null;
  get diagnostics n = row_count;
  return n;
end $function$;

-- ===== Execute grants =====
revoke all on function public._price_mark_guard() from public, anon, authenticated;
revoke all on function public._price_archive() from public, anon, authenticated;
revoke all on function public._vendor_archive() from public, anon, authenticated;
revoke all on function public._reader_auth(text) from public, anon, authenticated;
revoke all on function public._cockpit_price_ok(public.vendor_prices, public.vendors) from public, anon, authenticated;
revoke all on function public._cockpit_status(public.vendors) from public, anon, authenticated;
revoke all on function public._cockpit_reader_mint(text) from public, anon, authenticated, service_role;
revoke all on function public._cockpit_reader_revoke() from public, anon, authenticated, service_role;
revoke all on function public._price_visible(public.vendor_prices, public.vendors, public.members) from public, anon, authenticated;
revoke all on function public.vendors_list(text) from public; grant execute on function public.vendors_list(text) to anon, authenticated;
revoke all on function public.transport_prices(text) from public; grant execute on function public.transport_prices(text) to anon, authenticated;
revoke all on function public.price_confirm(text, uuid, text, text) from public; grant execute on function public.price_confirm(text, uuid, text, text) to anon, authenticated;
revoke all on function public.price_marks(text, text) from public; grant execute on function public.price_marks(text, text) to anon, authenticated;
revoke all on function public.cockpit_supplier_search(text, text) from public; grant execute on function public.cockpit_supplier_search(text, text) to anon, authenticated;
revoke all on function public.cockpit_supplier_prices(text, text) from public; grant execute on function public.cockpit_supplier_prices(text, text) to anon, authenticated;
