-- 2026-10-16 · D-54 · transport prices with their details, and the Quotes tab fed from them.
-- Adds only: one column (vendor_prices.transport) and two functions; three functions replaced to carry the column.
-- Nothing is deleted or dropped. Older lines keep transport = '{}' and still read from their label.
alter table public.vendor_prices add column if not exists transport jsonb not null default '{}'::jsonb;

-- D-54: the details of a transport price, kept beside the line (what it is for, the route, the vehicle, passengers,
-- luggage, the time of day, quoted or paid, and what a day includes). Only known keys, each a short text, are kept.
CREATE OR REPLACE FUNCTION public._transport_clean(t jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select coalesce((select jsonb_object_agg(k, left(btrim(t->>k), 80))
    from unnest(array['kind','dir','city','city2','veh','pax','bags','bag_n','time','night','paid','on','hours','km','x_hour','x_km','wait','tolls','tip']) k
    where jsonb_typeof(t) = 'object' and coalesce(btrim(t->>k),'') <> ''), '{}'::jsonb)
$function$;

-- D-54: every transport price line this member may see, across all bus, van and car suppliers, for the Quotes tab.
-- The same rules as on the supplier's own page (_price_visible, _can_see, hidden suppliers); no colleague's name is sent.
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
      and (m.is_admin or (not v.hidden and public._can_see(m, v.category, v.also_categories) and public._price_visible(p, v, m)))), '[]'::json);
end $function$;

CREATE OR REPLACE FUNCTION public._price_clean(p jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select jsonb_build_object(
    'label', left(coalesce(p->>'label',''),120), 'audience', coalesce(nullif(p->>'audience',''),'Adult'),
    'age_from', left(coalesce(p->>'age_from',''),10), 'age_to', left(coalesce(p->>'age_to',''),10),
    'pax_min', left(coalesce(p->>'pax_min',''),10), 'pax_max', left(coalesce(p->>'pax_max',''),10),
    'season', left(coalesce(p->>'season',''),120), 'price', coalesce(p->>'price',''),
    'currency', coalesce(nullif(p->>'currency',''),'ILS'), 'vat', coalesce(p->>'vat',''),
    'basis', coalesce(nullif(p->>'basis',''),'Per person'), 'is_agent', coalesce((p->>'is_agent')::boolean, true),
    'source', left(coalesce(p->>'source',''),300), 'checked_on', coalesce(p->>'checked_on',''), 'note', left(coalesce(p->>'note',''),500),
    'private', coalesce((p->>'private')::boolean, false))
    -- D-54: a line saved by an older copy of the page carries no transport key, so its details are kept as they are
    || case when p ? 'transport' then jsonb_build_object('transport', public._transport_clean(p->'transport')) else '{}'::jsonb end
$function$;

CREATE OR REPLACE FUNCTION public._price_write(p_vendor text, p_id uuid, c jsonb, p_editor text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare nid uuid;
begin
  if p_id is null then
    insert into public.vendor_prices (vendor_id,label,audience,age_from,age_to,pax_min,pax_max,season,price,currency,vat,basis,is_agent,source,checked_on,note,private,transport,created_by,updated_by)
    values (p_vendor, c->>'label', c->>'audience', c->>'age_from', c->>'age_to', c->>'pax_min', c->>'pax_max', c->>'season', c->>'price', c->>'currency', c->>'vat', c->>'basis', (c->>'is_agent')::boolean, c->>'source', c->>'checked_on', c->>'note', coalesce((c->>'private')::boolean,false), coalesce(c->'transport','{}'::jsonb), p_editor, p_editor)
    returning id into nid;
    return nid;
  end if;
  update public.vendor_prices set label=c->>'label', audience=c->>'audience', age_from=c->>'age_from', age_to=c->>'age_to', pax_min=c->>'pax_min', pax_max=c->>'pax_max', season=c->>'season', price=c->>'price', currency=c->>'currency', vat=c->>'vat', basis=c->>'basis', is_agent=(c->>'is_agent')::boolean, source=c->>'source', checked_on=c->>'checked_on', note=c->>'note', private=coalesce((c->>'private')::boolean,private), transport=coalesce(c->'transport',transport), updated_by=p_editor, updated_at=now()
  where id = p_id;
  return p_id;
end $function$;

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
    'prices', coalesce((select json_agg(json_build_object('id',p.id,'vendor_id',p.vendor_id,'label',p.label,'audience',p.audience,'age_from',p.age_from,'age_to',p.age_to,'pax_min',p.pax_min,'pax_max',p.pax_max,'season',p.season,'price',p.price,'currency',p.currency,'vat',p.vat,'basis',p.basis,'is_agent',p.is_agent,'source',p.source,'checked_on',p.checked_on,'note',p.note,'private',p.private,'sort',p.sort,'transport',p.transport,
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

revoke all on function public._transport_clean(jsonb) from public, anon, authenticated;
revoke all on function public.transport_prices(text) from public;
grant execute on function public.transport_prices(text) to anon, authenticated;
