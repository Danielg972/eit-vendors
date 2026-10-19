-- D-61 (19 Oct 2026): a full member can send a supplier a details form; the answers wait in Eretz Israel Tours' review list.
-- The owner, 19 Oct, 10:13: "Can you integrate that into he app so people can send this form to venders?" About 10:16:
-- the answers go to Eretz Israel Tours' review list; all full members can send it; the form lives on the app's address.
-- 10:18, asked whether that meant a separate page on vendors.eretzisraeltours.com showing only the form: "Yes that's what
-- I meant". Built as the mock-up of 19 Oct ("Supplier Form Mock-up") shows.
--
-- Adds and replaces only. New: table supplier_forms; helpers _forms_on, _form_clean, _form_rows; member RPC
-- supplier_form_new; the supplier's two calls supplier_form_open and supplier_form_answer (link key only, no member link);
-- Eretz Israel Tours' RPCs supplier_forms_list, supplier_form_apply, supplier_form_link, supplier_form_discard.
-- Replaced: whoami (adds forms and forms_for) and set_setting (adds the key forms_for). Nothing else changes.
--
-- What the supplier's page can reach (rule B1): the business name on its own link, and nothing else from the app.
-- Nothing a supplier sends reaches an entry until Eretz Israel Tours applies it, line by line (E1, E3). Prices come in as
-- new lines, "from the supplier", not confirmed (E4); an agent rate is an agent line, so limited members never get it
-- (C3, D4). Hours come in Unverified, with the form as their source (E2).

-- ===== The table =====
create table if not exists public.supplier_forms (
  id uuid not null default gen_random_uuid(),
  key_hash text not null,                                  -- sha256 of the link key; the key itself is never stored
  vendor_id text references public.vendors(id) on delete set null,   -- empty: a supplier not on the list yet
  business_name text not null,
  sent_by text not null,                                   -- the member's email (shown to Eretz Israel Tours only)
  sent_name text not null default '',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days',
  status text not null default 'sent',
  answers jsonb not null default '{}'::jsonb,
  answered_at timestamptz,
  applied text[] not null default '{}',
  decided_by text not null default '',
  decided_at timestamptz,
  constraint supplier_forms_pkey primary key (id),
  constraint supplier_forms_key_hash_key unique (key_hash),
  constraint supplier_forms_status_check check (status = any (array['sent','answered','applied','discarded'])),
  constraint supplier_forms_name_check check (length(business_name) between 2 and 120),
  constraint supplier_forms_answers_check check (length(answers::text) <= 20000)
);
create index if not exists supplier_forms_status_idx on public.supplier_forms (status, answered_at desc);
create index if not exists supplier_forms_sent_by_idx on public.supplier_forms (sent_by, created_at desc);
alter table public.supplier_forms enable row level security;
revoke all on table public.supplier_forms from public, anon, authenticated;
grant all on table public.supplier_forms to service_role;

-- ===== Who may send a form =====
-- Eretz Israel Tours always; full members once the setting forms_for is 'all' (G2). Never a limited member.
create or replace function public._forms_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(m.is_admin or (not public._limited(m) and coalesce((select value from public.app_settings where key = 'forms_for'), '') = 'all'), false)
$function$;
revoke all on function public._forms_on(public.members) from public, anon, authenticated;

-- ===== What a supplier may send =====
-- Only known keys, each trimmed and cut to length; choices outside their lists are dropped.
create or replace function public._form_clean(a jsonb)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select coalesce((select jsonb_object_agg(k, v) from (
      select k, left(btrim(coalesce(a->>k, '')), case when k in ('about','cancel','fam','notes') then 1500
          when k in ('hours','hours_notes','payment','booking_how','parking','access') then 300 else 120 end) as v
      from unnest(array['name','name_he','types','about','website','social','address','city','region','maps','parking',
        'contact','role','phone','whatsapp','email','booking_how','hours','last_entry','shabbat','hours_notes','duration',
        'capacity','ages','languages','kosher','kosher_cert','access','p_adult','p_child','p_group','p_trade','guide_free',
        'vat','payment','cancel','fam','notes']) k) x
    where v <> ''
      and (k <> 'shabbat' or v in ('closed','open'))
      and (k <> 'kosher' or v in ('none','cert','nocert','not'))
      and (k <> 'vat' or v in ('including_vat','plus_vat','exempt'))), '{}'::jsonb)
  || jsonb_build_object('consent', coalesce(case when jsonb_typeof(a->'consent') = 'boolean' then (a->>'consent')::boolean end, false))
$function$;
revoke all on function public._form_clean(jsonb) from public, anon, authenticated;

-- ===== The answers beside the entry, one row per thing that can be applied =====
-- Each row: k (what it is), label, cur (in the app now), new (from the supplier), same, tick (ticked to start).
-- Rows appear only for what the supplier filled in. v may be empty (a supplier not on the list yet).
create or replace function public._form_rows(a jsonb, v public.vendors)
 returns jsonb language plpgsql stable set search_path to ''
as $function$
declare out jsonb := '[]'::jsonb; s text; loc text; shab boolean; num text; f text; d text[] := '{}';
  t text := coalesce(v.tags, '');
begin
  -- fields of the entry: what the app has now beside what the supplier sent
  loc := nullif(concat_ws(', ', nullif(a->>'address',''), case when coalesce(a->>'city','') <> '' and position(lower(a->>'city') in lower(coalesce(a->>'address',''))) = 0 then a->>'city' end), '');
  shab := t ~* '(^|,)\s*Shomer Shabbat\s*(,|$)';
  for f, s in select * from (values
      ('name', coalesce(nullif(a->>'name',''), a->>'name_he')),
      ('location', loc),
      ('region', a->>'region'),
      ('maps_link', a->>'maps'),
      ('contactPerson', nullif(concat_ws(' · ', nullif(a->>'contact',''), nullif(a->>'role','')), '')),
      ('phone', a->>'phone'),
      ('whatsapp', a->>'whatsapp'),
      ('email', a->>'email'),
      ('website', a->>'website'),
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
    out := out || jsonb_build_array(jsonb_build_object('k', f, 'label', case f when 'name' then 'Business name' when 'location' then 'Address'
        when 'region' then 'Region' when 'maps_link' then 'Map pin' when 'contactPerson' then 'Booking contact' when 'phone' then 'Phone'
        when 'whatsapp' then 'WhatsApp' when 'email' then 'Email' when 'website' then 'Website' when 'hours' then 'Hours'
        when 'hours_last' then 'Last entry' when 'shabbat' then 'Shomer Shabbat' when 'kosher' then 'Kosher' when 'languages' then 'Languages'
        when 'payTerms' then 'Payment terms' else 'Cancellation policy' end,
      'cur', case f when 'shabbat' then case when v.id is null then '' when shab then 'Yes, closed on Shabbat' else 'No, open on Shabbat' end
        when 'name' then coalesce(v.name, '') when 'location' then coalesce(v.location, '') when 'region' then coalesce(v.region, '')
        when 'maps_link' then coalesce(v.maps_link, '') when 'contactPerson' then coalesce(v."contactPerson", '') when 'phone' then coalesce(v.phone, '')
        when 'whatsapp' then coalesce(v.whatsapp, '') when 'email' then coalesce(v.email, '') when 'website' then coalesce(v.website, '')
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
    case when coalesce(a->>'name','') <> '' and coalesce(a->>'name_he','') <> '' then 'Name in Hebrew: ' || (a->>'name_he') end,
    case when coalesce(a->>'types','') <> '' then 'Kind of business: ' || (a->>'types') end,
    case when coalesce(a->>'about','') <> '' then 'What they offer: ' || (a->>'about') end,
    case when coalesce(a->>'social','') <> '' then 'Instagram / Facebook: ' || (a->>'social') end,
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
  -- same: already what the app has; tick: ticked to start (a changed name is left for Eretz Israel Tours to tick)
  return coalesce((select jsonb_agg(r || jsonb_build_object('same', lower(btrim(r->>'cur')) = lower(btrim(r->>'new')) and r->>'k' not like 'price%' and r->>'k' <> 'details',
      'tick', not (lower(btrim(r->>'cur')) = lower(btrim(r->>'new')) and r->>'k' not like 'price%' and r->>'k' <> 'details') and r->>'k' <> 'name' and not (r ? 'na')) order by n)
    from jsonb_array_elements(out) with ordinality e(r, n)), '[]'::jsonb);
end $function$;
revoke all on function public._form_rows(jsonb, public.vendors) from public, anon, authenticated;

-- ===== A member makes a link =====
-- One link per supplier, single use, 30 days. For a supplier on the list the name is the entry's; otherwise the member
-- types it. Returns the key once; only its hash is kept.
create or replace function public.supplier_form_new(p_token text, p_vendor text default '', p_name text default '')
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; v public.vendors; nm text; k text; f public.supplier_forms;
begin
  m := public._auth(p_token);
  if public._limited(m) then raise exception 'Supplier forms are for guides and agents.' using errcode = '42501'; end if;
  if not public._forms_on(m) then raise exception 'Only Eretz Israel Tours can do that for now.' using errcode = '42501'; end if;
  if coalesce(p_vendor, '') <> '' then
    perform public._visible(p_vendor, m.is_admin);
    select * into v from public.vendors where id = p_vendor;
    if v.id is null or v.archived_at is not null then raise exception 'That supplier is not available.'; end if;
    nm := left(btrim(v.name), 120);
  else
    nm := left(btrim(coalesce(p_name, '')), 120);
  end if;
  if length(nm) < 2 then raise exception 'Write the business name.'; end if;
  if (select count(*) from public.supplier_forms where sent_by = m.email and created_at > now() - interval '1 day') >= 30 then
    raise exception 'That is 30 forms today. Try again tomorrow.'; end if;
  k := public._new_token();
  insert into public.supplier_forms (key_hash, vendor_id, business_name, sent_by, sent_name)
  values (public._hash(k), v.id, nm, m.email, m.name) returning * into f;
  return json_build_object('key', k, 'business_name', f.business_name, 'expires_at', f.expires_at);
end $function$;
revoke all on function public.supplier_form_new(text, text, text) from public;
grant execute on function public.supplier_form_new(text, text, text) to anon, authenticated;

-- ===== The supplier's page (link key only) =====
-- Shows the business name and nothing else from the app.
create or replace function public.supplier_form_open(p_key text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare f public.supplier_forms;
begin
  if coalesce(length(p_key), 0) < 32 then raise exception 'This link is not active.' using errcode = '28000'; end if;
  select * into f from public.supplier_forms where key_hash = public._hash(p_key);
  if f.id is null then raise exception 'This link is not active.' using errcode = '28000'; end if;
  if f.status <> 'sent' then raise exception 'This form was already sent. Thank you.' using errcode = '28000'; end if;
  if f.expires_at <= now() then raise exception 'This link has expired. Ask the person who sent it for a new one.' using errcode = '28000'; end if;
  return json_build_object('business_name', f.business_name, 'expires_at', f.expires_at);
end $function$;
revoke all on function public.supplier_form_open(text) from public;
grant execute on function public.supplier_form_open(text) to anon, authenticated;

-- The supplier sends the form. Once only.
create or replace function public.supplier_form_answer(p_key text, p_answers jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare f public.supplier_forms; a jsonb := public._form_clean(case when jsonb_typeof(p_answers) = 'object' then p_answers else '{}'::jsonb end);
begin
  if coalesce(length(p_key), 0) < 32 then raise exception 'This link is not active.' using errcode = '28000'; end if;
  select * into f from public.supplier_forms where key_hash = public._hash(p_key) for update;
  if f.id is null then raise exception 'This link is not active.' using errcode = '28000'; end if;
  if f.status <> 'sent' then raise exception 'This form was already sent. Thank you.' using errcode = '28000'; end if;
  if f.expires_at <= now() then raise exception 'This link has expired. Ask the person who sent it for a new one.' using errcode = '28000'; end if;
  if coalesce(a->>'name', a->>'name_he', '') = '' then raise exception 'Please add the business name.'; end if;
  if coalesce(a->>'contact', '') = '' then raise exception 'Please add a contact name.'; end if;
  if length(regexp_replace(coalesce(a->>'phone', ''), '\D', '', 'g')) < 7 then raise exception 'Please add a phone number.'; end if;
  update public.supplier_forms set answers = a, answered_at = now(), status = 'answered' where id = f.id;
  return json_build_object('ok', true);
end $function$;
revoke all on function public.supplier_form_answer(text, jsonb) from public;
grant execute on function public.supplier_form_answer(text, jsonb) to anon, authenticated;

-- ===== Eretz Israel Tours' review list =====
create or replace function public.supplier_forms_list(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  return json_build_object(
    'waiting', (select count(*) from public.supplier_forms where status = 'sent' and expires_at > now()),
    'forms', coalesce((select json_agg(json_build_object('id', f.id, 'vendor_id', f.vendor_id, 'vendor_name', v.name, 'business_name', f.business_name,
        'sent_name', f.sent_name, 'sent_by', f.sent_by, 'sent_at', f.created_at, 'answered_at', f.answered_at,
        'consent', coalesce((f.answers->>'consent')::boolean, false), 'types', coalesce(f.answers->>'types', ''),
        'rows', public._form_rows(f.answers, v)) order by f.answered_at desc)
      from public.supplier_forms f left join public.vendors v on v.id = f.vendor_id
      where f.status = 'answered'), '[]'::json));
end $function$;
revoke all on function public.supplier_forms_list(text) from public;
grant execute on function public.supplier_forms_list(text) to anon, authenticated;

-- Apply the ticked rows to the entry. Fields go through vendor_save as Eretz Israel Tours' own edit (so the kosher,
-- guide and Eshkol rules hold); prices are new lines, not confirmed; "Other details" is a note from Eretz Israel Tours.
-- All or nothing.
create or replace function public.supplier_form_apply(p_token text, p_id uuid, p_keys text[])
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; f public.supplier_forms; v public.vendors; rows jsonb; r jsonb; vals jsonb := '{}'::jsonb;
  done text[] := '{}'; tg text; src text := 'From the supplier: details form, ' || to_char(now() at time zone 'Asia/Jerusalem', 'DD/MM/YYYY');
  vat text; np int := 0;
begin
  m := public._auth(p_token, true);
  select * into f from public.supplier_forms where id = p_id for update;
  if f.id is null or f.status <> 'answered' then raise exception 'This form is no longer waiting.'; end if;
  if f.vendor_id is null then raise exception 'Create the entry first.'; end if;
  select * into v from public.vendors where id = f.vendor_id;
  if v.id is null then raise exception 'That supplier no longer exists.'; end if;
  if coalesce(array_length(p_keys, 1), 0) = 0 then raise exception 'Tick at least one line.'; end if;
  rows := public._form_rows(f.answers, v);
  vat := case f.answers->>'vat' when 'including_vat' then 'including_vat' when 'plus_vat' then 'plus_vat' else '' end;
  for r in select x from jsonb_array_elements(rows) x where x->>'k' = any (p_keys) and not (x ? 'na') loop
    done := done || (r->>'k');
    if r->>'k' = 'shabbat' then
      tg := array_to_string(array(select btrim(t) from unnest(string_to_array(coalesce(v.tags, ''), ',')) t where btrim(t) <> '' and lower(btrim(t)) <> 'shomer shabbat'), ', ');
      if f.answers->>'shabbat' = 'closed' then tg := concat_ws(', ', nullif(tg, ''), 'Shomer Shabbat'); end if;
      vals := vals || jsonb_build_object('tags', tg);
    elsif r->>'k' like 'price%' then
      perform public._price_write(v.id, null, public._price_clean(jsonb_build_object(
        'label', case r->>'k' when 'price_agent' then 'Rate for licensed guides and agents' when 'price_adult' then 'Adult'
          when 'price_child' then 'Child' else 'Group price / minimum charge' end,
        'audience', case r->>'k' when 'price_child' then 'Child' when 'price_group' then 'Group' else 'Adult' end,
        'price', r->>'price', 'currency', 'ILS', 'vat', vat,
        'basis', case r->>'k' when 'price_group' then 'Per group' else 'Per person' end,
        'is_agent', r->>'k' = 'price_agent', 'source', src, 'checked_on', to_char(now() at time zone 'Asia/Jerusalem', 'YYYY-MM-DD'),
        'note', case when btrim(r->>'said') <> r->>'price' then 'In their words: ' || (r->>'said') else '' end)), m.email);
      np := np + 1;
    elsif r->>'k' = 'details' then
      perform public.review_post(p_token, v.id, src || E'\n' || (r->>'new'), '', false);
    else
      vals := vals || jsonb_build_object(r->>'k', r->>'new');
    end if;
  end loop;
  if coalesce(array_length(done, 1), 0) = 0 then raise exception 'Tick at least one line.'; end if;
  if vals <> '{}'::jsonb then
    perform public.vendor_save(p_token, to_jsonb(v) || vals, '');
    if vals ? 'hours' or vals ? 'hours_last' then
      update public.vendors set hours_source = 'the supplier''s details form, ' || to_char(now() at time zone 'Asia/Jerusalem', 'DD/MM/YYYY') where id = v.id;
    end if;
  end if;
  update public.supplier_forms set status = 'applied', applied = done, decided_by = m.email, decided_at = now() where id = f.id;
  return json_build_object('applied', coalesce(array_length(done, 1), 0), 'prices', np, 'vendor_id', v.id);
end $function$;
revoke all on function public.supplier_form_apply(text, uuid, text[]) from public;
grant execute on function public.supplier_form_apply(text, uuid, text[]) to anon, authenticated;

-- A supplier new to the list: Eretz Israel Tours creates the entry (the usual form, filled from the answers), then ties
-- the form to it, and the rest (prices, other details) is applied as for any entry.
create or replace function public.supplier_form_link(p_token text, p_id uuid, p_vendor text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; f public.supplier_forms;
begin
  m := public._auth(p_token, true);
  select * into f from public.supplier_forms where id = p_id for update;
  if f.id is null or f.status <> 'answered' then raise exception 'This form is no longer waiting.'; end if;
  if f.vendor_id is not null then raise exception 'This form already belongs to an entry.'; end if;
  if not exists (select 1 from public.vendors where id = p_vendor) then raise exception 'That supplier no longer exists.'; end if;
  update public.supplier_forms set vendor_id = p_vendor where id = f.id;
  return json_build_object('ok', true);
end $function$;
revoke all on function public.supplier_form_link(text, uuid, text) from public;
grant execute on function public.supplier_form_link(text, uuid, text) to anon, authenticated;

create or replace function public.supplier_form_discard(p_token text, p_id uuid)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token, true);
  update public.supplier_forms set status = 'discarded', decided_by = m.email, decided_at = now() where id = p_id and status = 'answered';
  if not found then raise exception 'This form is no longer waiting.'; end if;
end $function$;
revoke all on function public.supplier_form_discard(text, uuid) from public;
grant execute on function public.supplier_form_discard(text, uuid) to anon, authenticated;

-- ===== Replaced: the setting, and whoami telling the app whether to show the button =====
create or replace function public.set_setting(p_token text, p_key text, p_value text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email','bookings_for','jobs_for','hikes_for','rentals_for','wineries_for','forms_for') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  if p_key = 'bookings_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'jobs_for' and lower(trim(p_value)) not in ('admin','receive','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'hikes_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'rentals_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'wineries_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'forms_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  insert into public.app_settings (key, value) values (p_key, lower(trim(p_value))) on conflict (key) do update set value = excluded.value;
end $function$;

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
    'hikes', status = 'approved' and public._hikes_on(m),
    'hikes_for', case when is_admin then coalesce((select value from public.app_settings where key = 'hikes_for'),'admin') else '' end,
    'rentals', status = 'approved' and public._rentals_on(m),
    'rentals_for', case when is_admin then coalesce((select value from public.app_settings where key = 'rentals_for'),'admin') else '' end,
    'wineries', status = 'approved' and public._wineries_on(m),
    'wineries_for', case when is_admin then coalesce((select value from public.app_settings where key = 'wineries_for'),'admin') else '' end,
    'forms', status = 'approved' and public._forms_on(m),
    'forms_for', case when is_admin then coalesce((select value from public.app_settings where key = 'forms_for'),'admin') else '' end,
    'member_type', case when public._limited(m) then 'limited' else 'full' end,
    'sections', case when public._limited(m) then sections else '' end,
    'see_quotes', not public._limited(m) or see_quotes,
    'see_guide_rates', not public._limited(m) or see_guide_rates,
    'see_transport_reviews', not public._limited(m) or see_transport_reviews,
    'see_reviews', not public._limited(m) or see_reviews,
    'org', org)
  from public.members m where token_hash = public._hash(p_token);
$function$;
