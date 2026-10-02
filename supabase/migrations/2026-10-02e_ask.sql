-- "Ask the list" (2 Oct 2026). See docs/DECISIONS.md D-6. Run after 2026-10-02d_bookings_accept.sql.
-- supabase/schema.sql already includes everything below; this file is the step-by-step change. Safe to run twice.
-- Then: add the secret ANTHROPIC_API_KEY to the project's edge functions and deploy supabase/functions/ask/index.ts.
-- The assistant stays OFF until Eretz Israel Tours switches it on in the Team tab (setting ask_for: off / admin / all).

-- One row per answered question: who, when, how many tokens, what it cost. The question itself is NOT stored.
create table if not exists public.ask_log (
  id uuid default gen_random_uuid() not null,
  member text not null,
  member_name text default ''::text not null,
  model text default ''::text not null,
  input_tokens integer default 0 not null,
  cache_write_tokens integer default 0 not null,
  cache_read_tokens integer default 0 not null,
  output_tokens integer default 0 not null,
  cost_usd numeric(10,5) default 0 not null,
  created_at timestamp with time zone default now() not null,
  constraint ask_log_pkey primary key (id),
  constraint ask_log_model_check check (length(model) <= 80)
);
alter table public.ask_log enable row level security;
create index if not exists ask_log_created_idx on public.ask_log using btree (created_at);
revoke all on table public.ask_log from public, anon, authenticated;
grant all on table public.ask_log to service_role;

-- A setting, or its default when it was never saved.
create or replace function public._ask_setting(p_key text)
 returns text language sql stable security definer set search_path to ''
as $function$
  select coalesce(nullif((select value from public.app_settings where key = p_key), ''),
    case p_key when 'ask_for' then 'off' when 'ask_daily' then '15' when 'ask_cap_usd' then '15' else '' end)
$function$;
revoke all on function public._ask_setting(text) from public, anon, authenticated;

-- Price lines of one supplier as text. p_mode: 'shared' = what every colleague sees; 'mine' = this member's own
-- personal lines; 'private' = everything colleagues don't see (Eretz Israel Tours only).
create or replace function public._ask_prices(v public.vendors, p_mode text, p_email text)
 returns text language sql stable security definer set search_path to ''
as $function$
  select string_agg('- Price: ' || concat_ws(' | ', nullif(p.label,''),
      p.audience || coalesce(' ages ' || nullif(p.age_from,'') || '-' || p.age_to, ''),
      'group of ' || nullif(p.pax_min,'') || '-' || p.pax_max,
      case when p.price = '' then 'price not given' when p.price::numeric = 0 then 'free' else p.price || ' ' || p.currency || ' ' || lower(p.basis) end,
      nullif(replace(p.vat,'_',' '),''),
      case when p.is_agent then 'agent price' else 'public price' end,
      'season ' || nullif(p.season,''), 'source ' || nullif(p.source,''), 'checked ' || nullif(p.checked_on,''), nullif(p.note,'')),
    E'\n' order by p.sort, p.created_at)
  from public.vendor_prices p
  where p.vendor_id = v.id and case p_mode
    when 'shared' then p.owner = '' and not v.prices_private and not p.private
    when 'mine' then p.owner <> '' and p.owner = p_email
    when 'private' then p.owner <> '' or v.prices_private or p.private
    else false end
$function$;
revoke all on function public._ask_prices(public.vendors, text, text) from public, anon, authenticated;

-- Quotes of one supplier as text: dates, options, rates, what is included and what costs extra, conditions.
-- Never the client/title, the supplier's reference, the private note or who got the quote.
create or replace function public._ask_quotes(v public.vendors, p_mode text, p_email text)
 returns text language sql stable security definer set search_path to ''
as $function$
  select string_agg('- Quote' || coalesce(' for ' || nullif(q.date_from,'') || coalesce(' to ' || nullif(q.date_to,''), ''), ' (dates not given)')
      || coalesce(', received ' || nullif(q.received_on,''), '') || ', status ' || q.status
      || coalesce(', ' || nullif(replace(q.vat,'_',' '),''), ', VAT not stated') || coalesce(', ' || nullif(q.pax,'') || ' people', '') || E'\n'
      || coalesce((select string_agg('    option: ' || o.name || coalesce(' [' || nullif(o.service,'') || coalesce(', ' || nullif(o.seats,'') || ' seats', '') || ']', '') || ': '
            || coalesce((select string_agg(l.label || ' ' || case when l.price = '' then 'price to confirm' when l.unit = '% of subtotal' then l.price || '% of subtotal' else l.price || ' ' || q.currency || ' ' || l.unit end
                  || case when l.kind <> 'Base' then ' (' || lower(l.kind) || ')' else '' end, '; ' order by l.sort)
                from public.quote_lines l where l.option_id = o.id), 'no price lines')
            || coalesce('; ' || nullif(o.hours_incl,'') || ' hours a day included', '') || coalesce('; ' || nullif(o.km_incl,'') || ' km a day included', '')
            || coalesce('; ' || (select string_agg(k || case f->>'s' when 'incl' then ' included' else ' extra' || coalesce(' ' || (f->>'amt') || ' ' || q.currency, '') end
                  || coalesce(' (' || (f->>'note') || ')', ''), ', ' order by k) from jsonb_each(o.fees) e(k, f)), ''),
          E'\n' order by o.sort)
        from public.quote_options o where o.quote_id = q.id), '    no options')
      || coalesce(E'\n    conditions: ' || nullif(q.conditions,''), ''),
    E'\n' order by q.created_at desc)
  from public.quotes q
  where q.vendor_id = v.id and case p_mode
    when 'shared' then q.shared and not v.prices_private
    when 'mine' then q.owner = p_email and (not q.shared or v.prices_private)
    when 'private' then not q.shared or v.prices_private
    else false end
$function$;
revoke all on function public._ask_quotes(public.vendors, text, text) from public, anon, authenticated;

-- One supplier as a block of text. p_all = false: what every colleague sees. p_all = true: everything (Eretz Israel Tours only).
-- Left out on purpose: members' names, emails and phones (reviews and notes say "a colleague"), drivers' phone numbers,
-- booking sheets, attachments, and Eretz Israel Tours' private notes.
create or replace function public._ask_vendor(v public.vendors, p_all boolean)
 returns text language sql stable security definer set search_path to ''
as $function$
  select concat_ws(E'\n',
    'SUPPLIER: ' || v.name,
    'Category: ' || v.category || case when v.also_categories <> '' then ', also ' || v.also_categories else '' end,
    'Area: ' || nullif(concat_ws(', ', nullif(v.region,''), nullif(v.location,'')), ''),
    'Type: ' || nullif(v.tags,''),
    case when v.active = 'Inactive' then 'Status: inactive' end,
    case when v.review_status <> 'approved' then 'Not yet verified by Eretz Israel Tours.' end,
    case when v.hidden then 'Hidden from colleagues.' end,
    'Contact: ' || nullif(concat_ws(' | ', nullif(v."contactPerson",''), 'phone ' || nullif(v.phone,''), 'WhatsApp ' || nullif(v.whatsapp,''), nullif(v.email,''), nullif(v.website,'')), ''),
    'Languages: ' || nullif(v.languages,''),
    'Kosher: ' || nullif(v.kosher,''),
    'Capacity: ' || nullif(v."maxCap",''),
    case when p_all or not v.prices_private then
      'Main price: ' || nullif(concat_ws('; ',
        'agent ' || nullif(v."agentPrice",'') || ' ' || v.currency || ' ' || lower(v."priceBasis") || coalesce(' (' || nullif(replace(v."agentPriceVatTreatment",'_',' '),'') || ')', ''),
        'listed ' || nullif(v."listedPrice",'') || ' ' || v.currency || coalesce(' (' || nullif(replace(v."listedPriceVatTreatment",'_',' '),'') || ')', ''),
        'up to ' || nullif(v."maxPax",'') || ' people'), '')
      else 'Prices: kept private by Eretz Israel Tours.' end,
    'Payment terms: ' || nullif(v."payTerms",''),
    'Cancellation: ' || nullif(concat_ws('; ', nullif(v."cancelPolicy",''), 'notice ' || nullif(v."cancelNoticeAmount",'') || ' ' || lower(v."cancelNoticeUnit"),
      'penalty ' || nullif(v."cancelPenalty",''), 'checked ' || nullif(v."cancelPolicyVerifiedDate",'')), ''),
    'Reservation: ' || nullif(replace(v.reservation,'_',' '),''),
    'Ratings out of 5: ' || nullif(concat_ws(', ', 'reliability ' || nullif(v."rateReliability",''), 'service ' || nullif(v."rateService",''), 'value ' || nullif(v."rateValue",'')), ''),
    'Strengths: ' || nullif(v.strengths,''),
    'Weaknesses: ' || nullif(v.weaknesses,''),
    'Summary: ' || nullif(v.notes,''),
    'How to get agent prices: ' || nullif(concat_ws(' ', nullif(v.agent_howto,''), nullif(v.agent_link,'')), ''),
    'Years guiding: ' || nullif(v.experience_years,''),
    public._ask_prices(v, 'shared', ''),
    case when p_all then public._ask_prices(v, 'private', '') end,
    (select string_agg('- Deal: ' || concat_ws(' | ', d.kind, nullif(d.provider,''), d.title, nullif(d.details,''), 'code ' || nullif(d.code,''), 'valid until ' || nullif(d.valid_to,'')), E'\n' order by d.created_at desc)
      from public.vendor_deals d where d.vendor_id = v.id and (d.valid_to = '' or d.valid_to >= to_char(now(),'YYYY-MM-DD'))),
    (select string_agg('- Note from a colleague (' || to_char(n.created_at,'Mon YYYY') || '): ' || n.body, E'\n' order by n.created_at desc)
      from public.vendor_notes n where n.vendor_id = v.id),
    (select string_agg('- Food nearby: ' || concat_ws(' | ', f.name, nullif(f.kosher,''), nullif(f.note,'')), E'\n' order by f.created_at desc)
      from public.vendor_food f where f.vendor_id = v.id),
    (select string_agg('- Driver: ' || d.name || coalesce(', drives ' || nullif(d.drives,''), '')
          || coalesce((select ', average ' || round(avg(r.rating::int), 1)::text || ' out of 5 from ' || count(*)::text || ' review(s)' from public.driver_reviews r where r.driver_id = d.id having count(*) > 0), ', no reviews yet')
          || coalesce(E'\n' || (select string_agg('    review: ' || r.rating || ' out of 5' || coalesce(', trip in ' || nullif(r.trip_month,''), '')
                || coalesce(', ' || nullif(replace(r.tags,'!','problem: '),''), '') || coalesce('. ' || nullif(r.body,''), ''), E'\n' order by r.created_at desc)
              from public.driver_reviews r where r.driver_id = d.id), ''),
        E'\n' order by d.name)
      from public.drivers d join public.driver_vendors dv on dv.driver_id = d.id where dv.vendor_id = v.id),
    public._ask_quotes(v, 'shared', ''),
    case when p_all then public._ask_quotes(v, 'private', '') end)
$function$;
revoke all on function public._ask_vendor(public.vendors, boolean) from public, anon, authenticated;

-- Called by the "ask" edge function only (service key). Checks the member's link, the on/off switch and the two caps,
-- then returns the text the assistant may read: "shared" is identical for every colleague (so it can be cached),
-- "personal" is what only this member sees (own private prices and quotes; for Eretz Israel Tours, everything hidden).
create or replace function public.ask_begin(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; af text := public._ask_setting('ask_for'); per_day int := public._ask_setting('ask_daily')::int; cap numeric := public._ask_setting('ask_cap_usd')::numeric;
  today date := (now() at time zone 'Asia/Jerusalem')::date; used int; spent numeric; personal text;
begin
  m := public._auth(p_token);
  if af = 'off' or (af = 'admin' and not m.is_admin) then return json_build_object('ok', false, 'why', 'off', 'reason', 'The assistant is switched off.'); end if;
  select count(*) into used from public.ask_log where member = m.email and (created_at at time zone 'Asia/Jerusalem')::date = today;
  if not m.is_admin and used >= per_day then
    return json_build_object('ok', false, 'why', 'daily', 'reason', format('You have used today''s %s questions. More tomorrow.', per_day)); end if;
  select coalesce(sum(cost_usd), 0) into spent from public.ask_log where date_trunc('month', created_at at time zone 'Asia/Jerusalem') = date_trunc('month', now() at time zone 'Asia/Jerusalem');
  if spent >= cap then return json_build_object('ok', false, 'why', 'budget', 'reason', 'The assistant has used this month''s budget. It is back on the 1st.'); end if;
  if m.is_admin then
    select concat_ws(E'\n\n',
      (select string_agg(public._ask_vendor(v, true), E'\n\n' order by v.name) from public.vendors v where v.hidden),
      (select string_agg('PRIVATE, for supplier ' || v.name || E':\n' || x.t, E'\n\n' order by v.name)
        from public.vendors v cross join lateral (select concat_ws(E'\n',
            case when v.prices_private then 'Main price: ' || nullif(concat_ws('; ', 'agent ' || nullif(v."agentPrice",'') || ' ' || v.currency || ' ' || lower(v."priceBasis"), 'listed ' || nullif(v."listedPrice",'') || ' ' || v.currency), '') end,
            public._ask_prices(v, 'private', ''), public._ask_quotes(v, 'private', '')) t) x
        where not v.hidden and x.t <> '')) into personal;
  else
    select string_agg('YOUR OWN, for supplier ' || v.name || E':\n' || x.t, E'\n\n' order by v.name) into personal
    from public.vendors v cross join lateral (select concat_ws(E'\n', public._ask_prices(v, 'mine', m.email), public._ask_quotes(v, 'mine', m.email)) t) x
    where not v.hidden and x.t <> '';
  end if;
  return json_build_object('ok', true, 'admin', m.is_admin, 'left', case when m.is_admin then null else per_day - used - 1 end,
    'shared', coalesce((select string_agg(public._ask_vendor(v, false), E'\n\n' order by v.name) from public.vendors v where not v.hidden), ''),
    'personal', coalesce(personal, ''));
end $function$;
revoke all on function public.ask_begin(text) from public, anon, authenticated;
grant execute on function public.ask_begin(text) to service_role;

-- Called by the "ask" edge function after an answer: records the cost. The question text is never passed in.
create or replace function public.ask_finish(p_token text, p_model text, p_in integer, p_cache_write integer, p_cache_read integer, p_out integer, p_cost numeric)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  insert into public.ask_log (member, member_name, model, input_tokens, cache_write_tokens, cache_read_tokens, output_tokens, cost_usd)
  values (m.email, m.name, left(coalesce(p_model,''),80), greatest(coalesce(p_in,0),0), greatest(coalesce(p_cache_write,0),0), greatest(coalesce(p_cache_read,0),0), greatest(coalesce(p_out,0),0), greatest(coalesce(p_cost,0),0));
end $function$;
revoke all on function public.ask_finish(text,text,integer,integer,integer,integer,numeric) from public, anon, authenticated;
grant execute on function public.ask_finish(text,text,integer,integer,integer,integer,numeric) to service_role;

-- What the app needs to draw the Ask tab: is it on for this member, and how many questions are left today.
-- Eretz Israel Tours also gets the settings, this month's spend and the count per person (never the questions).
create or replace function public.ask_status(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; af text := public._ask_setting('ask_for'); per_day int := public._ask_setting('ask_daily')::int; cap numeric := public._ask_setting('ask_cap_usd')::numeric;
  used int; mon timestamp := date_trunc('month', now() at time zone 'Asia/Jerusalem');
begin
  m := public._auth(p_token);
  select count(*) into used from public.ask_log where member = m.email and (created_at at time zone 'Asia/Jerusalem')::date = (now() at time zone 'Asia/Jerusalem')::date;
  return json_build_object('on', af = 'all' or (af = 'admin' and m.is_admin), 'per_day', per_day,
    'left', case when m.is_admin then null else greatest(per_day - used, 0) end)::jsonb
    || case when m.is_admin then jsonb_build_object('for', af, 'cap_usd', cap,
        'spent_usd', (select coalesce(sum(cost_usd),0) from public.ask_log where date_trunc('month', created_at at time zone 'Asia/Jerusalem') = mon),
        'asked', (select count(*) from public.ask_log where date_trunc('month', created_at at time zone 'Asia/Jerusalem') = mon),
        'by_person', coalesce((select jsonb_agg(jsonb_build_object('name', t.nm, 'n', t.n, 'usd', t.usd) order by t.n desc)
          from (select max(member_name) nm, count(*) n, sum(cost_usd) usd from public.ask_log where date_trunc('month', created_at at time zone 'Asia/Jerusalem') = mon group by member) t), '[]'::jsonb))
      else '{}'::jsonb end;
end $function$;
revoke all on function public.ask_status(text) from public; grant execute on function public.ask_status(text) to anon, authenticated;

-- set_setting: also the three assistant settings (who may use it, questions per person per day, monthly budget in US dollars).
create or replace function public.set_setting(p_token text, p_key text, p_value text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email','bookings_for','ask_for','ask_daily','ask_cap_usd') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  if p_key = 'bookings_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'ask_for' and lower(trim(p_value)) not in ('off','admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'ask_daily' and (trim(p_value) !~ '^\d{1,3}$' or trim(p_value)::int not between 1 and 200) then raise exception 'Questions a day: a number from 1 to 200.'; end if;
  if p_key = 'ask_cap_usd' and (trim(p_value) !~ '^\d{1,4}(\.\d{1,2})?$' or trim(p_value)::numeric not between 1 and 1000) then raise exception 'Monthly budget: a dollar amount from 1 to 1000.'; end if;
  insert into public.app_settings (key, value) values (p_key, lower(trim(p_value))) on conflict (key) do update set value = excluded.value;
end $function$;
