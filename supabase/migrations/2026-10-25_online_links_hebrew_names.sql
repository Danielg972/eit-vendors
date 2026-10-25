-- D-62 and D-63 (25 Oct 2026): online links on a supplier's page; Hebrew fields for the business name and the contact.
-- D-62, the owner, 25 Oct 2026: "Make a link for social media", then "Also tripadvisor and Google business page", then,
-- after seeing a mock-up: "Build it".
-- D-63, the owner, 25 Oct 2026: "I want to start having Hebrew fields for the names of the business and [a Hebrew] option
-- for contact people".
-- Rules: D2 (token-checked functions only, no table grants, no policies), C3/D4 (nothing loosened for organisations),
-- E3 (the name and the contact are locked: a colleague suggests, Eretz Israel Tours approves), D7 (no real client), G3.
--
-- Adds and replaces only. No DELETE, no DROP, no table grant, no policy. Safe to run twice. No function changes its
-- return type, so every one is a plain create or replace.
--
-- Columns (vendors): links (one http or https link per line, at most 10, each at most 500 characters), name_he (the
--   business name in Hebrew) and "contactPerson_he" (the contact person in Hebrew), both at most 200 characters.
--   Every existing supplier starts with all three empty. Live data is not rewritten.
-- New helper: _links_clean(text, strict) keeps http and https links only (a bare "instagram.com/x" gets https://),
--   drops repeats, and refuses (strict) or drops (not strict) anything else: javascript:, data:, a word that is not a
--   link, an 11th link. Closed to anon and authenticated, like the other helpers.
-- Replaced: _all_fields (the three fields), _locked_fields (name_he and "contactPerson_he", locked like name and
--   "contactPerson"; links stay open to any member, as the opening hours are), _vendor_apply and vendor_save (the
--   columns round-trip; links cleaned strictly on every save; an older copy of the page that sends none of the three
--   keeps what is stored), _form_clean and _form_rows (D-61: the supplier's form may send links and the contact's name
--   in Hebrew; the Hebrew business name, the Hebrew contact and the links become rows Eretz Israel Tours ticks, instead
--   of lines in the note), _booking_json and booking_open (D-5: the company's Hebrew name, when the entry has one, for
--   the Hebrew side of the booking sheet).
-- Read functions are unchanged: vendors_list, vendor_detail and the views send the whole supplier row (_vendor_json),
--   so the three columns reach every member who can see the supplier, organisations included. They are public
--   business details, not prices. The Cockpit's reader (D-57) is not changed: it returns no contact or link fields.

-- ===== Columns =====
alter table public.vendors add column if not exists links text not null default '';
alter table public.vendors add column if not exists name_he text not null default '';
alter table public.vendors add column if not exists "contactPerson_he" text not null default '';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'vendors_links_check' and conrelid = 'public.vendors'::regclass) then
    alter table public.vendors add constraint vendors_links_check check ((length(links) <= 6000) and ((links = ''::text) or (links ~* '^https?://\S+(\nhttps?://\S+)*$'::text)));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'vendors_hebrew_check' and conrelid = 'public.vendors'::regclass) then
    alter table public.vendors add constraint vendors_hebrew_check check (((length(name_he) <= 200) and (length("contactPerson_he") <= 200)));
  end if;
end $$;

-- ===== New helper: online links, cleaned =====
create or replace function public._links_clean(p text, p_strict boolean default false)
 returns text language plpgsql immutable set search_path to ''
as $function$
declare t text; u text; out text[] := '{}'; seen text[] := '{}';
begin
  foreach t in array regexp_split_to_array(btrim(coalesce(p, '')), '\s+') loop
    continue when t = '';
    u := t;
    if u !~* '^https?://' then
      if u ~* '^[a-z0-9-]+(\.[a-z0-9-]+)+(:[0-9]{1,5})?([/?#]|$)' then u := 'https://' || u;
      elsif p_strict then raise exception 'Only web links can be saved (https://…). This is not one: %', left(t, 60);
      else continue; end if;
    end if;
    if length(u) > 500 or u !~* '^https?://[a-z0-9-]+(\.[a-z0-9-]+)+(:[0-9]{1,5})?([/?#][^<>"''`\\[:cntrl:]]*)?$' then
      if p_strict then raise exception 'That link does not look right: %', left(t, 60); end if;
      continue;
    end if;
    continue when lower(u) = any (seen);
    seen := seen || lower(u); out := out || u;
  end loop;
  if coalesce(array_length(out, 1), 0) > 10 then
    if p_strict then raise exception 'At most 10 online links.'; end if;
    out := out[1:10];
  end if;
  return array_to_string(out, E'\n');
end $function$;
revoke all on function public._links_clean(text, boolean) from public, anon, authenticated;

-- ===== Replaced: the field lists (D-63: the Hebrew name and contact are locked like their English twins) =====
CREATE OR REPLACE FUNCTION public._all_fields()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select array['name','category','active','contactPerson','phone','whatsapp','email','website','location','languages','kosher','maxCap','listedPrice','listedPriceVatTreatment','agentPrice','agentPriceVatTreatment','maxPax','priceBasis','currency','payTerms','cancelPolicy','cancelNoticeAmount','cancelNoticeUnit','cancelDayType','cancelPenalty','cancelPolicyVerifiedDate','npResLink','rateReliability','rateService','rateValue','strengths','weaknesses','notes','region','tags','experience_years','agent_link','agent_howto','also_categories','maps_link','hours','hours_last','name_he','contactPerson_he','links']::text[]
$function$
;

CREATE OR REPLACE FUNCTION public._locked_fields()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select array['name','name_he','category','active','contactPerson','contactPerson_he','phone','whatsapp','email','website','npResLink','listedPrice','listedPriceVatTreatment','agentPrice','agentPriceVatTreatment','maxPax','priceBasis','currency','payTerms','cancelPolicy','cancelNoticeAmount','cancelNoticeUnit','cancelDayType','cancelPenalty','cancelPolicyVerifiedDate']::text[]
$function$
;

-- ===== Replaced: saving a supplier =====
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
  update public.vendors v set (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link,hours,hours_last,hours_source,hours_verified_at,hours_verified_by,hours_verified_how,name_he,"contactPerson_he",links)
    = (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link,r.hours,r.hours_last,r.hours_source,r.hours_verified_at,r.hours_verified_by,r.hours_verified_how,r.name_he,r."contactPerson_he",r.links)
  where v.id = p_id returning * into r;
  return r;
end $function$
;

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
  -- D-62: online links, http and https only, one per line, at most 10 (a bad one is refused). D-63: the Hebrew name and contact.
  clean := clean || jsonb_build_object('links', public._links_clean(left(coalesce(p_data->>'links',''), 6000), true),
    'name_he', left(coalesce(p_data->>'name_he',''), 200), 'contactPerson_he', left(coalesce(p_data->>'contactPerson_he',''), 200));
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
    insert into public.vendors (name,category,active,"contactPerson",phone,whatsapp,email,website,location,languages,kosher,"maxCap","listedPrice","listedPriceVatTreatment","agentPrice","agentPriceVatTreatment","maxPax","priceBasis",currency,"payTerms","cancelPolicy","cancelNoticeAmount","cancelNoticeUnit","cancelDayType","cancelPenalty","cancelPolicyVerifiedDate","npResLink","rateReliability","rateService","rateValue",strengths,weaknesses,notes,region,tags,experience_years,agent_link,agent_howto,also_categories,maps_link,hours,hours_last,name_he,"contactPerson_he",links)
    values (r.name,r.category,r.active,r."contactPerson",r.phone,r.whatsapp,r.email,r.website,r.location,r.languages,r.kosher,r."maxCap",r."listedPrice",r."listedPriceVatTreatment",r."agentPrice",r."agentPriceVatTreatment",r."maxPax",r."priceBasis",r.currency,r."payTerms",r."cancelPolicy",r."cancelNoticeAmount",r."cancelNoticeUnit",r."cancelDayType",r."cancelPenalty",r."cancelPolicyVerifiedDate",r."npResLink",r."rateReliability",r."rateService",r."rateValue",r.strengths,r.weaknesses,r.notes,r.region,r.tags,r.experience_years,r.agent_link,r.agent_howto,r.also_categories,r.maps_link,r.hours,r.hours_last,r.name_he,r."contactPerson_he",r.links)
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
  -- An app version from before D-62 / D-63 sends no links and no Hebrew fields: keep what is stored.
  if not (p_data ? 'links') then clean := clean || jsonb_build_object('links', coalesce(cur->>'links','')); end if;
  if not (p_data ? 'name_he') then clean := clean || jsonb_build_object('name_he', coalesce(cur->>'name_he','')); end if;
  if not (p_data ? 'contactPerson_he') then clean := clean || jsonb_build_object('contactPerson_he', coalesce(cur->>'contactPerson_he','')); end if;
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

-- ===== Replaced: the supplier details form (D-61) =====
create or replace function public._form_clean(a jsonb)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select coalesce((select jsonb_object_agg(k, v) from (
      select k, left(btrim(coalesce(a->>k, '')), case when k in ('about','cancel','fam','notes','links') then 1500
          when k in ('hours','hours_notes','payment','booking_how','parking','access') then 300 else 120 end) as v
      from unnest(array['name','name_he','types','about','website','social','address','city','region','maps','parking',
        'contact','contact_he','links','role','phone','whatsapp','email','booking_how','hours','last_entry','shabbat','hours_notes','duration',
        'capacity','ages','languages','kosher','kosher_cert','access','p_adult','p_child','p_group','p_trade','guide_free',
        'vat','payment','cancel','fam','notes']) k) x
    where v <> ''
      and (k <> 'shabbat' or v in ('closed','open'))
      and (k <> 'kosher' or v in ('none','cert','nocert','not'))
      and (k <> 'vat' or v in ('including_vat','plus_vat','exempt'))), '{}'::jsonb)
  || jsonb_build_object('consent', coalesce(case when jsonb_typeof(a->'consent') = 'boolean' then (a->>'consent')::boolean end, false))
$function$;

create or replace function public._form_rows(a jsonb, v public.vendors)
 returns jsonb language plpgsql stable set search_path to ''
as $function$
declare out jsonb := '[]'::jsonb; s text; loc text; shab boolean; num text; f text; d text[] := '{}'; sup text; lk text;
  t text := coalesce(v.tags, '');
begin
  -- fields of the entry: what the app has now beside what the supplier sent
  loc := nullif(concat_ws(', ', nullif(a->>'address',''), case when coalesce(a->>'city','') <> '' and position(lower(a->>'city') in lower(coalesce(a->>'address',''))) = 0 then a->>'city' end), '');
  shab := t ~* '(^|,)\s*Shomer Shabbat\s*(,|$)';
  -- D-62: the supplier's links (the links box, or the older single Instagram / Facebook box), added to the ones the entry has
  sup := public._links_clean(concat_ws(E'\n', nullif(a->>'links',''), nullif(a->>'social','')), false);
  lk := case when sup <> '' then public._links_clean(concat_ws(E'\n', nullif(coalesce(v.links, ''), ''), sup), false) end;
  for f, s in select * from (values
      ('name', coalesce(nullif(a->>'name',''), a->>'name_he')),
      ('name_he', a->>'name_he'),
      ('location', loc),
      ('region', a->>'region'),
      ('maps_link', a->>'maps'),
      ('contactPerson', nullif(concat_ws(' · ', nullif(a->>'contact',''), nullif(a->>'role','')), '')),
      ('contactPerson_he', a->>'contact_he'),
      ('phone', a->>'phone'),
      ('whatsapp', a->>'whatsapp'),
      ('email', a->>'email'),
      ('website', a->>'website'),
      ('links', lk),
      ('hours', a->>'hours'),
      ('hours_last', a->>'last_entry'),
      ('shabbat', case a->>'shabbat' when 'closed' then 'Yes, closed on Shabbat' when 'open' then 'No, open on Shabbat' end),
      ('kosher', case a->>'kosher' when 'cert' then coalesce(nullif(a->>'kosher_cert',''), 'Kosher, certificate not named')
          when 'nocert' then 'Kosher no certificate' when 'not' then 'Not kosher' when 'none' then 'Not relevant' end),
      ('languages', a->>'languages'),
      ('payTerms', a->>'payment'),
      ('cancelPolicy', a->>'cancel')) x(k, n)
  loop
    continue when coalesce(s, '') = '';
    out := out || jsonb_build_array(jsonb_build_object('k', f, 'label', case f when 'name' then 'Business name' when 'name_he' then 'Name in Hebrew' when 'location' then 'Address'
        when 'region' then 'Region' when 'maps_link' then 'Map pin' when 'contactPerson' then 'Booking contact' when 'contactPerson_he' then 'Booking contact in Hebrew' when 'phone' then 'Phone'
        when 'whatsapp' then 'WhatsApp' when 'email' then 'Email' when 'website' then 'Website' when 'links' then 'Online links' when 'hours' then 'Hours'
        when 'hours_last' then 'Last entry' when 'shabbat' then 'Shomer Shabbat' when 'kosher' then 'Kosher' when 'languages' then 'Languages'
        when 'payTerms' then 'Payment terms' else 'Cancellation policy' end,
      'cur', case f when 'shabbat' then case when v.id is null then '' when shab then 'Yes, closed on Shabbat' else 'No, open on Shabbat' end
        when 'name' then coalesce(v.name, '') when 'name_he' then coalesce(v.name_he, '') when 'location' then coalesce(v.location, '') when 'region' then coalesce(v.region, '')
        when 'maps_link' then coalesce(v.maps_link, '') when 'contactPerson' then coalesce(v."contactPerson", '') when 'contactPerson_he' then coalesce(v."contactPerson_he", '') when 'phone' then coalesce(v.phone, '')
        when 'whatsapp' then coalesce(v.whatsapp, '') when 'email' then coalesce(v.email, '') when 'website' then coalesce(v.website, '') when 'links' then coalesce(v.links, '')
        when 'hours' then coalesce(v.hours, '') when 'hours_last' then coalesce(v.hours_last, '') when 'kosher' then coalesce(v.kosher, '')
        when 'languages' then coalesce(v.languages, '') when 'payTerms' then coalesce(v."payTerms", '') else coalesce(v."cancelPolicy", '') end,
      'new', s));
  end loop;
  -- prices: a number is needed; the supplier's own words stay with the line as its note
  for f, s in select * from (values ('price_agent', a->>'p_trade'), ('price_adult', a->>'p_adult'), ('price_child', a->>'p_child'), ('price_group', a->>'p_group')) x(k, n) loop
    continue when coalesce(s, '') = '';
    num := replace(substring(s from '[0-9][0-9,]*(?:\.[0-9]+)?'), ',', '');
    if num is null then
      -- an agent rate without a number is shown to Eretz Israel Tours only, never put in a note (organisations read notes; C3)
      if f = 'price_agent' then out := out || jsonb_build_array(jsonb_build_object('k', f, 'label', 'Agent price', 'cur', '', 'new', s || ' · no number, not added', 'na', true)); continue; end if;
      d := d || (case f when 'price_adult' then 'Adult price' when 'price_child' then 'Child price' else 'Group price / minimum' end || ': ' || s); continue; end if;
    out := out || jsonb_build_array(jsonb_build_object('k', f, 'price', num, 'said', s,
      'label', case f when 'price_agent' then 'Agent price' when 'price_adult' then 'Adult price' when 'price_child' then 'Child price' else 'Group price / minimum' end,
      'cur', case when v.id is null then '' when f = 'price_agent' and coalesce(v."agentPrice", '') <> '' then '₪' || v."agentPrice"
        when f = 'price_adult' and coalesce(v."listedPrice", '') <> '' then '₪' || v."listedPrice" else '' end,
      'new', '₪' || num || ' · from the supplier' || case when regexp_replace(s, '[₪,\s]', '', 'g') <> num then E'\n“' || s || '”' else '' end));
  end loop;
  -- everything else, as one note on the entry
  d := d || array_remove(array[
    case when coalesce(a->>'types','') <> '' then 'Kind of business: ' || (a->>'types') end,
    case when coalesce(a->>'about','') <> '' then 'What they offer: ' || (a->>'about') end,
    case when sup = '' and coalesce(a->>'links', a->>'social', '') <> '' then 'Online (not a link): ' || left(concat_ws(' ', a->>'links', a->>'social'), 300) end,
    case when coalesce(a->>'parking','') <> '' then 'Bus parking / drop-off: ' || (a->>'parking') end,
    case when coalesce(a->>'booking_how','') <> '' then 'How to book: ' || (a->>'booking_how') end,
    case when coalesce(a->>'hours_notes','') <> '' then 'Holidays and seasons: ' || (a->>'hours_notes') end,
    case when coalesce(a->>'duration','') <> '' then 'Visit length: ' || (a->>'duration') end,
    case when coalesce(a->>'capacity','') <> '' then 'Group size: ' || (a->>'capacity') end,
    case when coalesce(a->>'ages','') <> '' then 'Ages: ' || (a->>'ages') end,
    case when coalesce(a->>'access','') <> '' then 'Accessibility: ' || (a->>'access') end,
    case when coalesce(a->>'guide_free','') <> '' then 'Guide / driver free: ' || (a->>'guide_free') end,
    case a->>'vat' when 'including_vat' then 'Prices include VAT' when 'plus_vat' then 'Prices plus VAT' when 'exempt' then 'Exempt business (עוסק פטור), no VAT added' end,
    case when coalesce(a->>'fam','') <> '' then 'Visit for guides: ' || (a->>'fam') end,
    case when coalesce(a->>'notes','') <> '' then 'Anything else: ' || (a->>'notes') end], null);
  if array_length(d, 1) > 0 then
    out := out || jsonb_build_array(jsonb_build_object('k', 'details', 'label', 'Other details', 'cur', '', 'new', left(array_to_string(d, E'\n'), 3000)));
  end if;
  -- same: already what the app has; tick: ticked to start (a changed name, English or Hebrew, is left for Eretz Israel Tours to tick)
  return coalesce((select jsonb_agg(r || jsonb_build_object('same', lower(btrim(r->>'cur')) = lower(btrim(r->>'new')) and r->>'k' not like 'price%' and r->>'k' <> 'details',
      'tick', not (lower(btrim(r->>'cur')) = lower(btrim(r->>'new')) and r->>'k' not like 'price%' and r->>'k' <> 'details') and r->>'k' not in ('name', 'name_he') and not (r ? 'na')) order by n)
    from jsonb_array_elements(out) with ordinality e(r, n)), '[]'::jsonb);
end $function$;

-- ===== Replaced: booking sheets (D-5), the company's Hebrew name =====
create or replace function public._booking_json(b public.bookings)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',b.id,'vendor_id',b.vendor_id,'vendor_name',(select v.name from public.vendors v where v.id = b.vendor_id),'vendor_name_he',(select v.name_he from public.vendors v where v.id = b.vendor_id),
    'key',b.link_key,'status',b.status,'client_ref',b.client_ref,'booker_name',b.booker_name,'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'days',b.days,'day_plan',b.day_plan,'terms_off',b.terms_off,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'private_note',b.private_note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,
    'answered_by',b.answered_by,'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,'shared',b.shared,'in_tracker',b.quote_id is not null,
    'guide_ok_at',b.guide_ok_at,'company_ok_at',b.company_ok_at,'company_ok_via',b.company_ok_via,'seen',b.seen_guide,
    'mine', b.owner = coalesce(current_setting('app.editor', true),''),
    'owner_name',b.owner_name,
    'owner_role',(select mm.role from public.members mm where mm.email = b.owner limit 1),
    'owner_admin',(select mm.is_admin from public.members mm where mm.email = b.owner limit 1),
    'created_at',b.created_at,'updated_at',b.updated_at)
$function$;

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
    'company_he',(select v.name_he from public.vendors v where v.id = b.vendor_id),
    'booker_name',b.booker_name,
    'booker_role',(select case when mm.org <> '' then mm.org else mm.role end from public.members mm where mm.email = b.owner limit 1),
    'booker_phone',b.booker_phone,
    'date_from',b.date_from,'date_to',b.date_to,'days',b.days,'day_plan',b.day_plan,'terms_off',b.terms_off,'pax',b.pax,'service',b.service,'seats',b.seats,'tourists',b.tourists,
    'pickup_time',b.pickup_time,'pickup_place',b.pickup_place,'route',b.route,'dropoff_time',b.dropoff_time,'dropoff_place',b.dropoff_place,
    'note',b.note,'proposed',b.proposed,'terms',b.terms,'terms_by',b.terms_by,'answered_by',b.answered_by,
    'answered_at',b.answered_at,'confirmed_at',b.confirmed_at,
    'guide_ok_at',b.guide_ok_at,'company_ok_at',b.company_ok_at,'company_ok_via',b.company_ok_via,'seen',b.seen_company);
end $function$;

-- ===== Execute rights (create or replace keeps them; stated again so a first run on a fresh copy is closed too) =====
revoke execute on function public._all_fields() from public, anon, authenticated;
revoke execute on function public._locked_fields() from public, anon, authenticated;
revoke execute on function public._vendor_apply(text,jsonb) from public, anon, authenticated;
revoke all on function public._form_clean(jsonb) from public, anon, authenticated;
revoke all on function public._form_rows(jsonb, public.vendors) from public, anon, authenticated;
revoke all on function public._booking_json(public.bookings) from public, anon, authenticated;
revoke all on function public.vendor_save(text,jsonb,text) from public; grant execute on function public.vendor_save(text,jsonb,text) to anon, authenticated;
revoke all on function public.booking_open(text) from public; grant execute on function public.booking_open(text) to anon, authenticated;
