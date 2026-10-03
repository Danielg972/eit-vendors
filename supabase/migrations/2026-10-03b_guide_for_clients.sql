-- A guide's page gets a section written for clients (3 Oct 2026). See docs/DECISIONS.md D-12.
-- Run after 2026-10-03_jobs.sql (it does not depend on it). Paste the whole file into the Supabase SQL editor for
-- project wjuqtjlrtcywjaspjpwu and run it once. supabase/schema.sql already includes everything below.
-- Safe to run twice. No statement in this file removes anything.
--
--   1. vendors.client_bio: a short bio written to be passed on to clients (up to 1,500 characters).
--   2. vendors.retail_price: the guide's retail price, in free text (up to 200 characters). It is a price, so it
--      follows "Keep this supplier's prices private": colleagues then neither see it nor change it.
--   3. vendor_files.for_clients: marks a photo as one of the guide's pictures for clients. Four at most per guide.
--      Pictures go up through the existing "files" edge function as an ordinary Photo (no change to that function,
--      its list already returns every column) and are then marked with file_for_clients.
--   Any approved member can fill these in on a guide's page, like other open fields. Guide = main category Guide,
--   or Guide under "also offers".

-- ===== columns =====
alter table public.vendors
  add column if not exists client_bio text default ''::text not null,
  add column if not exists retail_price text default ''::text not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'vendors_client_check' and conrelid = 'public.vendors'::regclass) then
    alter table public.vendors add constraint vendors_client_check check (length(client_bio) <= 1500 and length(retail_price) <= 200);
  end if;
end $$;
alter table public.vendor_files add column if not exists for_clients boolean default false not null;

-- ===== internal helper (not an RPC) =====
create or replace function public._is_guide(v public.vendors)
 returns boolean language sql immutable set search_path to ''
as $function$
  select v.category = 'Guide' or coalesce(v.also_categories,'') ~* '(^|,)\s*Guide\s*(,|$)'
$function$;
revoke all on function public._is_guide(public.vendors) from public, anon, authenticated;

-- ===== _vendor_view: the retail price is hidden from colleagues with the other prices =====
CREATE OR REPLACE FUNCTION public._vendor_view(p_id text, p_admin boolean, p_email text DEFAULT ''::text)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when p_admin then (public._vendor_json(p_id)::jsonb || jsonb_build_object('_prices',(select count(*) from public.vendor_prices p where p.vendor_id=p_id)))::json
  else (
    (public._vendor_json(p_id)::jsonb
      || case when v.prices_private then jsonb_build_object('agentPrice','','listedPrice','','agentPriceVatTreatment','','listedPriceVatTreatment','','maxPax','','retail_price','') else '{}'::jsonb end)
      || jsonb_build_object('_prices', (select count(*) from public.vendor_prices p where p.vendor_id=p_id and ((p.owner <> '' and p.owner = p_email) or (p.owner = '' and not v.prices_private and not p.private))),
                            'created_by', public._name(v.created_by), 'updated_by', public._name(v.updated_by), 'hours_verified_by', public._name(v.hours_verified_by))
  )::json end
  from public.vendors v where v.id = p_id
$function$;

-- ===== RPCs (member token) =====
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
  if length(b) > 1500 then raise exception 'Keep the bio under 1,500 characters.'; end if;
  if length(rt) > 200 then raise exception 'Keep the retail price under 200 characters.'; end if;
  -- a colleague neither sees nor changes a price on a supplier whose prices are private
  if v.prices_private and not m.is_admin then rt := v.retail_price; end if;
  update public.vendors set client_bio = b, retail_price = rt where id = p_vendor;
  return public._vendor_view(p_vendor, m.is_admin, m.email);
end $function$;
revoke all on function public.vendor_set_client(text,text,text,text) from public; grant execute on function public.vendor_set_client(text,text,text,text) to anon, authenticated;

-- Mark a photo as one of the guide's pictures for clients, or take the mark off. Four at most per guide.
-- The file itself is not removed here; that stays with the files edge function (uploader or Eretz Israel Tours).
create or replace function public.file_for_clients(p_token text, p_file uuid, p_on boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; f public.vendor_files; v public.vendors; n int;
begin
  m := public._auth(p_token);
  select * into f from public.vendor_files where id = p_file;
  if f.id is null or (f.private and not m.is_admin and f.uploaded_by <> m.email) then raise exception 'That picture no longer exists.'; end if;
  perform public._visible(f.vendor_id, m.is_admin);
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
