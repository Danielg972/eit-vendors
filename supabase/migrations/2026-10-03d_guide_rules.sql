-- Guide rules (3 Oct 2026). See docs/DECISIONS.md D-15. Run after 2026-10-03c_claims.sql.
-- supabase/schema.sql already includes it. Safe to run twice. No statement here removes anything.
--
-- vendor_save now also holds two rules of the list:
--   1. Only licensed tour guides are listed. A guide's entry carries the tag "Licensed tour guide", or, for a specialty
--      such as shuk tours or graffiti tours, "Specialty guide". A new guide entry without either is refused. A colleague
--      who marks an existing entry as a specialty guide does not change it directly: it goes to Eretz Israel Tours as a
--      change request. (A new entry from a colleague is pending review anyway.)
--   2. Only a driver with a D1 license is listed as an Eshkol driver or guide: an entry that gains an Eshkol tag must
--      also carry "D1 license".
-- Entries that were on the list before this change are not blocked from other edits.

CREATE OR REPLACE FUNCTION public.vendor_save(p_token text, p_data jsonb, p_reason text DEFAULT ''::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.members; r public.vendors; f text; clean jsonb := '{}'::jsonb; cur jsonb; locked_changes jsonb := '{}'::jsonb; open_vals jsonb := '{}'::jsonb; req boolean := false;
  price_fields text[] := array['agentPrice','listedPrice','agentPriceVatTreatment','listedPriceVatTreatment','maxPax'];
  is_rest boolean; no_cert boolean; own boolean := false; gog boolean := false; curv public.vendors;
  is_gd boolean; lic boolean; spec boolean; esh boolean; d1 boolean; was_gd boolean := false; was_spec boolean := false; was_esh boolean := false;
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
  -- Guides (D-15): only licensed tour guides are listed, except a specialty (shuk tours, graffiti tours and the like),
  -- which Eretz Israel Tours approves as an exception. An Eshkol driver or guide needs a D1 license.
  -- Both are stated with tags, and asked for when an entry is new, becomes a guide, or gains Eshkol.
  is_gd := (clean->>'category') = 'Guide' or (clean->>'also_categories') ~* '(^|,)\s*Guide\s*(,|$)';
  lic := (clean->>'tags') ~* '(^|,)\s*Licensed tour guide\s*(,|$)';
  spec := (clean->>'tags') ~* '(^|,)\s*Specialty guide\s*(,|$)';
  esh := (clean->>'tags') ~* 'eshkol (license|driver|guide)';
  d1 := (clean->>'tags') ~* '(^|,)\s*D1 license\s*(,|$)';
  if coalesce(p_data->>'id','') <> '' then
    select v.category = 'Guide' or coalesce(v.also_categories,'') ~* '(^|,)\s*Guide\s*(,|$)', coalesce(v.tags,'') ~* '(^|,)\s*Specialty guide\s*(,|$)', coalesce(v.tags,'') ~* 'eshkol (license|driver|guide)'
      into was_gd, was_spec, was_esh from public.vendors v where v.id = p_data->>'id';
  end if;
  if is_gd and lic and spec then raise exception 'Choose one: licensed tour guide, or specialty guide.'; end if;
  if is_gd and not coalesce(was_gd, false) and not (lic or spec) then
    raise exception 'Say whether this guide is licensed. Only licensed tour guides are listed, except specialties such as shuk tours or graffiti tours.'; end if;
  if esh and not coalesce(was_esh, false) and not d1 then
    raise exception 'Only a driver with a D1 license can be listed as an Eshkol driver or guide. Add the tag "D1 license" to confirm it, or take Eshkol off.'; end if;
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
