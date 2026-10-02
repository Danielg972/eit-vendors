-- Quote tracker (2 Oct 2026). See docs/DECISIONS.md D-2.
-- Apply to Supabase project wjuqtjlrtcywjaspjpwu, then deploy supabase/functions/files/index.ts (v9).
-- supabase/schema.sql already includes everything below; this file is the step-by-step change.
-- Safe to run twice.

-- What each quoted option is, what is included, what costs extra.
alter table public.quote_options
  add column if not exists service text not null default '' check (length(service) <= 40),
  add column if not exists seats text not null default '' check (seats = '' or seats ~ '^\d{1,3}$'),
  add column if not exists hours_incl text not null default '' check (hours_incl = '' or hours_incl ~ '^\d{1,2}(\.\d)?$'),
  add column if not exists km_incl text not null default '' check (km_incl = '' or km_incl ~ '^\d{1,4}$'),
  add column if not exists fees jsonb not null default '{}'::jsonb;

-- New quotes are shared with colleagues (without the owner's name) unless switched off.
alter table public.quotes alter column shared set default true;

-- Keep only known fee keys, a known state, a numeric amount and a short note.
create or replace function public._fees_clean(p jsonb)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select coalesce(jsonb_object_agg(k, jsonb_strip_nulls(jsonb_build_object(
      's', v->>'s',
      'amt', case when v->>'s' = 'extra' and coalesce(v->>'amt','') ~ '^\d{1,7}(\.\d{1,2})?$' then v->>'amt' end,
      'note', nullif(left(trim(coalesce(v->>'note','')),80),'')))), '{}'::jsonb)
  from jsonb_each(case when jsonb_typeof(p) = 'object' then p else '{}'::jsonb end) e(k, v)
  where k = any (array['overtime','extra_km','tolls','overnight','night','shabbat','parking','fuel','vehicle','meals','cleaning','service','min_charge','equipment','instructor','other'])
    and jsonb_typeof(v) = 'object' and v->>'s' in ('incl','extra')
$function$;
revoke all on function public._fees_clean(jsonb) from public, anon, authenticated;

-- Owner and Eretz Israel Tours get the full quote. Everyone else gets prices, dates, extras and conditions only:
-- no owner, no client/title, no supplier reference, no private note, no attachment count.
create or replace function public._quote_json(q public.quotes, p_full boolean)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',q.id,'vendor_id',q.vendor_id,'title',case when p_full then q.title else '' end,
    'date_from',q.date_from,'date_to',q.date_to,'pax',q.pax,'units',q.units,'received_on',q.received_on,'valid_until',q.valid_until,
    'ref',case when p_full then q.ref else '' end,'status',q.status,'currency',q.currency,'vat',q.vat,'conditions',q.conditions,
    'private_note',case when p_full then q.private_note else '' end,'shared',q.shared,
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

create or replace function public.quote_save(p_token text, p_vendor text, p_quote jsonb)
 returns uuid language plpgsql security definer set search_path to ''
as $function$
declare m public.members; qid uuid := nullif(p_quote->>'id','')::uuid; o jsonb; l jsonb; oid uuid; oi int := 0; li int;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  if qid is not null and not exists (select 1 from public.quotes where id = qid and vendor_id = p_vendor and (owner = m.email or m.is_admin)) then
    raise exception 'Only the person who added this quote, or Eretz Israel Tours, can change it.'; end if;
  if qid is null then
    insert into public.quotes (vendor_id, owner, owner_name) values (p_vendor, m.email, m.name) returning id into qid;
  end if;
  update public.quotes set title=left(coalesce(p_quote->>'title',''),160), date_from=coalesce(p_quote->>'date_from',''), date_to=coalesce(p_quote->>'date_to',''),
    pax=left(coalesce(p_quote->>'pax',''),20), units=left(coalesce(p_quote->>'units',''),60), received_on=coalesce(p_quote->>'received_on',''),
    valid_until=coalesce(p_quote->>'valid_until',''), ref=left(coalesce(p_quote->>'ref',''),80), status=coalesce(nullif(p_quote->>'status',''),'Received'),
    currency=coalesce(nullif(p_quote->>'currency',''),'ILS'), vat=coalesce(p_quote->>'vat',''), conditions=left(coalesce(p_quote->>'conditions',''),3000),
    private_note=left(coalesce(p_quote->>'private_note',''),3000), shared=coalesce((p_quote->>'shared')::boolean,true), updated_at=now()
  where id = qid;
  delete from public.quote_options where quote_id = qid;
  for o in select * from jsonb_array_elements(coalesce(p_quote->'options','[]'::jsonb)) loop
    insert into public.quote_options (quote_id, name, note, sort, service, seats, hours_incl, km_incl, fees)
    values (qid, left(coalesce(nullif(o->>'name',''),'Option'),120), left(coalesce(o->>'note',''),1000), oi,
      case when coalesce(o->>'service','') = any (array['coach','midibus','minibus','van','car','jeep_vehicle','transfer','guide','guide_vehicle','hotel_room','apartment','rappelling','jeep_tour','atv','activity','site','meal','other']) then o->>'service' else '' end,
      case when coalesce(o->>'seats','') ~ '^\d{1,3}$' then o->>'seats' else '' end,
      case when coalesce(o->>'hours_incl','') ~ '^\d{1,2}(\.\d)?$' then o->>'hours_incl' else '' end,
      case when coalesce(o->>'km_incl','') ~ '^\d{1,4}$' then o->>'km_incl' else '' end,
      public._fees_clean(o->'fees'))
    returning id into oid;
    oi := oi + 1; li := 0;
    for l in select * from jsonb_array_elements(coalesce(o->'lines','[]'::jsonb)) loop
      if coalesce(l->>'label','') = '' and coalesce(l->>'price','') = '' then continue; end if;
      insert into public.quote_lines (option_id, label, kind, price, unit, qty, times, note, sort)
      values (oid, left(coalesce(l->>'label',''),160), coalesce(nullif(l->>'kind',''),'Base'), coalesce(l->>'price',''), coalesce(nullif(l->>'unit',''),'per person'),
        coalesce(nullif(l->>'qty',''),'1'), coalesce(nullif(l->>'times',''),'1'), left(coalesce(l->>'note',''),300), li);
      li := li + 1;
    end loop;
  end loop;
  return qid;
end $function$;

-- A supplier's page: your own quotes, plus shared ones unless the supplier's prices are private.
create or replace function public.quotes_list(p_token text, p_vendor text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token); perform public._visible(p_vendor, m.is_admin);
  return coalesce((select json_agg(public._quote_json(q, m.is_admin or q.owner = m.email)
      order by (q.status in ('Expired','Declined')), coalesce(nullif(q.date_from,''),'9999') desc, q.created_at desc)
    from public.quotes q join public.vendors v on v.id = q.vendor_id
    where q.vendor_id = p_vendor and (m.is_admin or q.owner = m.email or (q.shared and not v.prices_private))), '[]'::json);
end $function$;

-- The Quotes tab: every quote the caller may see, across suppliers.
create or replace function public.quotes_tracker(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return coalesce((select json_agg(public._quote_json(q, m.is_admin or q.owner = m.email) order by q.created_at desc)
    from public.quotes q join public.vendors v on v.id = q.vendor_id
    where m.is_admin or (not v.hidden and (q.owner = m.email or (q.shared and not v.prices_private)))), '[]'::json);
end $function$;
revoke all on function public.quotes_tracker(text) from public;
grant execute on function public.quotes_tracker(text) to anon, authenticated;

-- The one quote that existed before this change: say what it is, so it lands in the right group.
update public.quote_options set service = 'midibus', seats = '35' where name = '35-seat midibus' and service = '';
