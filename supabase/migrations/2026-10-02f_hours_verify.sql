-- Verified opening hours, and a line for last entry and other times (decision D-9).
--   1. vendors.hours_last: free text, "Last entry and other times" (last cable car, when a trail opens...). Any member can edit.
--   2. vendors.hours_source: where unverified hours came from (set by imports; cleared when a member changes the hours).
--   3. vendors.hours_verified_at / _by / _how: a member confirms the hours by speaking to the supplier ('spoke') or
--      being there ('visited'). Changing the hours or the last-entry line clears it (in _vendor_apply).
--   4. New RPC hours_verify(p_token, p_vendor, p_how): 'spoke' | 'visited' sets it; '' undoes it (verifier or admin).
--   5. _vendor_view gives colleagues the verifier's NAME, never the email.
-- One new callable function (hours_verify): revoked from public, granted to anon and authenticated, like the other RPCs.
-- Safe to run twice.

begin;

alter table public.vendors add column if not exists hours_last text default ''::text not null;
alter table public.vendors add column if not exists hours_source text default ''::text not null;
alter table public.vendors add column if not exists hours_verified_at timestamp with time zone;
alter table public.vendors add column if not exists hours_verified_by text default ''::text not null;
alter table public.vendors add column if not exists hours_verified_how text default ''::text not null;
do $do$ begin
  if not exists (select 1 from pg_constraint where conname = 'vendors_hours_last_check' and conrelid = 'public.vendors'::regclass) then
    alter table public.vendors add constraint vendors_hours_last_check CHECK ((length(hours_last) <= 600));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'vendors_hours_source_check' and conrelid = 'public.vendors'::regclass) then
    alter table public.vendors add constraint vendors_hours_source_check CHECK ((length(hours_source) <= 200));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'vendors_hours_verified_how_check' and conrelid = 'public.vendors'::regclass) then
    alter table public.vendors add constraint vendors_hours_verified_how_check CHECK ((hours_verified_how = ANY (ARRAY[''::text, 'spoke'::text, 'visited'::text])));
  end if;
end $do$;

CREATE OR REPLACE FUNCTION public._all_fields()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select array['name','category','active','contactPerson','phone','whatsapp','email','website','location','languages','kosher','maxCap','listedPrice','listedPriceVatTreatment','agentPrice','agentPriceVatTreatment','maxPax','priceBasis','currency','payTerms','cancelPolicy','cancelNoticeAmount','cancelNoticeUnit','cancelDayType','cancelPenalty','cancelPolicyVerifiedDate','npResLink','rateReliability','rateService','rateValue','strengths','weaknesses','notes','region','tags','experience_years','agent_link','agent_howto','also_categories','maps_link','hours','hours_last']::text[]
$function$;

CREATE OR REPLACE FUNCTION public._vendor_apply(p_id text, p_vals jsonb)
 RETURNS vendors
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare r public.vendors; o public.vendors;
begin
  select * into r from public.vendors where id = p_id;
  if r.id is null then raise exception 'That supplier no longer exists.'; end if;
  o := r;
  r := jsonb_populate_record(r, p_vals);
  -- Changed hours are unverified again, and no longer "from their website".
  if r.hours is distinct from o.hours or r.hours_last is distinct from o.hours_last then
    r.hours_verified_at := null; r.hours_verified_by := ''; r.hours_verified_how := ''; r.hours_source := '';
  end if;
  update public.vendors v set (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link,hours,hours_last,hours_source,hours_verified_at,hours_verified_by,hours_verified_how)
    = (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link,r.hours,r.hours_last,r.hours_source,r.hours_verified_at,r.hours_verified_by,r.hours_verified_how)
  where v.id = p_id returning * into r;
  return r;
end $function$;

CREATE OR REPLACE FUNCTION public._vendor_view(p_id text, p_admin boolean, p_email text DEFAULT ''::text)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when p_admin then (public._vendor_json(p_id)::jsonb || jsonb_build_object('_prices',(select count(*) from public.vendor_prices p where p.vendor_id=p_id)))::json
  else (
    (public._vendor_json(p_id)::jsonb
      || case when v.prices_private then jsonb_build_object('agentPrice','','listedPrice','','agentPriceVatTreatment','','listedPriceVatTreatment','','maxPax','') else '{}'::jsonb end)
      || jsonb_build_object('_prices', (select count(*) from public.vendor_prices p where p.vendor_id=p_id and ((p.owner <> '' and p.owner = p_email) or (p.owner = '' and not v.prices_private and not p.private))),
                            'created_by', public._name(v.created_by), 'updated_by', public._name(v.updated_by), 'hours_verified_by', public._name(v.hours_verified_by))
  )::json end
  from public.vendors v where v.id = p_id
$function$;

CREATE OR REPLACE FUNCTION public.vendor_save(p_token text, p_data jsonb, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; r public.vendors; f text; clean jsonb := '{}'::jsonb; cur jsonb; locked_changes jsonb := '{}'::jsonb; open_vals jsonb := '{}'::jsonb; req boolean := false;
  price_fields text[] := array['agentPrice','listedPrice','agentPriceVatTreatment','listedPriceVatTreatment','maxPax'];
  is_rest boolean; no_cert boolean;
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
  foreach f in array public._all_fields() loop
    if (cur->>'prices_private')::boolean and f = any(price_fields) then continue; end if;
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

CREATE OR REPLACE FUNCTION public.hours_verify(p_token text, p_vendor text, p_how text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; v public.vendors;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  select * into v from public.vendors where id = p_vendor;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if coalesce(p_how,'') = '' then
    -- undo: the person who verified, or Eretz Israel Tours
    if not m.is_admin and v.hours_verified_by <> m.email then raise exception 'Only the person who verified these hours, or Eretz Israel Tours, can undo that.'; end if;
    update public.vendors set hours_verified_at = null, hours_verified_by = '', hours_verified_how = '' where id = p_vendor;
  elsif p_how in ('spoke','visited') then
    if v.hours = '' and v.hours_last = '' then raise exception 'Add the opening hours first.'; end if;
    update public.vendors set hours_verified_at = now(), hours_verified_by = m.email, hours_verified_how = p_how where id = p_vendor;
  else
    raise exception 'Say how you checked: you spoke to them, or you were there.';
  end if;
  return public._vendor_view(p_vendor, m.is_admin, m.email);
end $function$;

revoke all on function public.hours_verify(text,text,text) from public;
grant execute on function public.hours_verify(text,text,text) to anon, authenticated;

commit;
