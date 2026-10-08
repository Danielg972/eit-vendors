-- Hikes and parks (8 Oct 2026). See docs/DECISIONS.md D-32. Run after 2026-10-08_hikes.sql, on project wjuqtjlrtcywjaspjpwu.
-- In the go-live order (README, "Hikes and parks") the owner first runs 2026-10-08c_brochure_kind.sql himself; nothing
-- in this file needs it, and the two give the same database in either order.
-- supabase/schema.sql already includes everything below; this file is the step-by-step change. Safe to run twice.
-- It only adds and replaces: one new column on hikes with its length check and its index, one new helper, and three
-- functions replaced (_hike_json, hike_save, _file_visible). Nothing here takes anything away.
--
-- A hike can name the supplier it lies in: the national park, nature reserve or site. The hike's page then links to
-- that supplier's page (hours, booking link, brochure) and the supplier's page lists its hikes.
--
-- Who sees what:
--   * The link is the supplier's id and nothing else. A member receives it only when he can see that supplier:
--     the supplier exists, is not hidden, and (he is Eretz Israel Tours, or the supplier is in his sections).
--     To everyone else the hike reads as having no park. So a hike never shows a supplier to a member who cannot
--     open that supplier.
--   * There is no foreign key: a supplier can be taken off the list or merged into another, and the id left on the
--     hike then simply reads as no park.
--   * Brochures (the parks' own handouts) are a new kind of file on a supplier. An organisation sees them, like
--     photos and kosher certificates. The kind itself is added to the list of kinds in 2026-10-08c_brochure_kind.sql.

-- ===== the hike's park: one column =====
alter table public.hikes add column if not exists vendor_id text default ''::text not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'hikes_vendor_id_check' and conrelid = 'public.hikes'::regclass) then
    alter table public.hikes add constraint hikes_vendor_id_check check (length(vendor_id) <= 60);
  end if;
end $$;
create index if not exists hikes_vendor_idx on public.hikes using btree (vendor_id);

-- ===== helper (not callable from outside) =====
-- The hike's park as this member may know it: the supplier's id when the supplier exists, is not hidden, and the
-- member is Eretz Israel Tours or has the supplier's section. Otherwise empty.
create or replace function public._hike_park(h public.hikes, m public.members)
 returns text language sql stable security definer set search_path to ''
as $function$
  select coalesce((select v.id from public.vendors v
    where m.id is not null and h.vendor_id <> '' and v.id = h.vendor_id and not v.hidden
      and (m.is_admin or public._can_see(m, v.category, v.also_categories))), '')
$function$;
revoke all on function public._hike_park(public.hikes,public.members) from public, anon, authenticated;

-- ===== replaced: _hike_json, with the park added (one line: 'vendor_id') =====
-- A hike as one member receives it, with a summary of the reports. Names only: never an email.
-- Cliffs and firing zone: one report saying yes is enough for the summary to say so.
create or replace function public._hike_json(h public.hikes, m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',h.id,'name',h.name,'region',h.region,'distance_km',h.distance_km,'hours_from',h.hours_from,'hours_to',h.hours_to,
    'start_place',h.start_place,'end_place',h.end_place,'is_loop',h.is_loop,'markers',h.markers,'notes',h.notes,'official',h.official,
    'source',h.source,'source_url',h.source_url,'source_year',h.source_year,'review_status',h.review_status,
    'vendor_id',public._hike_park(h, m),
    'by',public._name(h.added_by),'org',h.org,'mine',h.added_by = m.email,
    'can_edit',m.is_admin or (h.added_by = m.email and h.review_status <> 'approved'),
    'created_at',h.created_at,'updated_at',h.updated_at,
    'gpx',(select json_build_object('name',g.name,'by',public._name(g.added_by),'at',g.updated_at) from public.hike_gpx g where g.hike_id = h.id and not g.removed),
    'r',(select json_build_object('n',count(*),'last',max(r.walked_on),
          'group_min',min(nullif(r.group_size,'')::int),'group_max',max(nullif(r.group_size,'')::int),
          'age_min',min(nullif(r.age_min,'')::int),'age_max',max(nullif(r.age_max,'')::int),
          'difficulty',mode() within group (order by nullif(r.difficulty,'')),
          'cliffs',case when bool_or(r.cliffs = 'yes') then 'yes' else mode() within group (order by nullif(r.cliffs,'')) end,
          'water_shoes',mode() within group (order by nullif(r.water_shoes,'')),
          'firing_zone',case when bool_or(r.firing_zone = 'crosses') then 'crosses' else mode() within group (order by nullif(r.firing_zone,'')) end,
          'water_route',mode() within group (order by nullif(r.water_route,'')),
          'drinking_water',mode() within group (order by nullif(r.drinking_water,'')),
          'bathrooms',mode() within group (order by nullif(r.bathrooms,'')),
          'eat',mode() within group (order by nullif(r.eat,'')))
        from public.hike_reports r where r.hike_id = h.id and not r.hidden))
$function$;
revoke all on function public._hike_json(public.hikes,public.members) from public, anon, authenticated;

-- ===== replaced: hike_save, with the park added =====
-- Add a hike, or change one. A member's new hike waits for approval. Once approved, only Eretz Israel Tours changes it.
-- The 3-year rule is asked when a hike is added or its page year is changed, not when an older entry is corrected.
-- New here: the key vendor_id. Sent empty, the hike has no park. Sent with a supplier's id, that supplier must be one
-- this member can see, or the save is refused. Not sent at all, the hike keeps the park it has.
create or replace function public.hike_save(p_token text, p_hike jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; hid uuid; h public.hikes; src text; yr text; nm text; vid text;
  y0 int := extract(year from now() at time zone 'Asia/Jerusalem')::int;
  km text := trim(coalesce(p_hike->>'distance_km','')); h1 text := trim(coalesce(p_hike->>'hours_from','')); h2 text := trim(coalesce(p_hike->>'hours_to',''));
  url text := trim(coalesce(p_hike->>'source_url','')); lp boolean := coalesce(p_hike->>'is_loop','') in ('true','t');
begin
  m := public._auth(p_token);
  if not public._hikes_on(m) then raise exception 'Hikes are not open yet.' using errcode = '42501'; end if;
  if p_hike is null or jsonb_typeof(p_hike) <> 'object' or pg_column_size(p_hike) > 2600000
     or (jsonb_typeof(p_hike->'markers') = 'array' and jsonb_array_length(p_hike->'markers') > 40) then raise exception 'That is more than a hike holds. Check it and try again.'; end if;
  begin
    hid := nullif(p_hike->>'id','')::uuid;
  exception when others then raise exception 'That hike is not available.';
  end;
  if hid is not null then
    select * into h from public.hikes where id = hid for update;   -- waits for an approval that is under way, then reads what it left
    if not public._hike_visible(h, m) then raise exception 'That hike is not available.'; end if;
    if not (m.is_admin or (h.added_by = m.email and h.review_status <> 'approved')) then
      raise exception 'This hike is approved. Suggest a change and Eretz Israel Tours will update it.' using errcode = '42501'; end if;
  end if;
  -- the name: invisible fillers taken out, spaces of every kind made one plain space, then cut to 120
  nm := regexp_replace(coalesce(p_hike->>'name',''), '[' || chr(8203) || chr(8288) || chr(65279) || chr(12644) || chr(4447) || chr(4448) || chr(65440) || ']', '', 'g');
  nm := trim(left(trim(regexp_replace(nm, '[\s[:cntrl:]' || chr(160) || ']+', ' ', 'g')), 120));
  if length(nm) < 3 or length(regexp_replace(nm, '[\s[:punct:]]', '', 'g')) < 2 then raise exception 'Add the name of the hike.'; end if;
  if trim(coalesce(p_hike->>'region','')) = '' then raise exception 'Choose the region.'; end if;
  if coalesce(p_hike->>'official','') not in ('true','t') then raise exception 'Only official marked trails are listed. Tick the box if this is one.'; end if;
  if not (m.is_admin and km = '') and (km !~ '^[0-9]{1,3}(\.[0-9]{1,2})?$' or km::numeric <= 0) then raise exception 'Add the distance in kilometres, as a number.'; end if;
  if (not (m.is_admin and h1 = '' and h2 = '')) and (h1 !~ '^[0-9]{1,2}(\.[0-9]{1,2})?$' or h1::numeric <= 0) then raise exception 'Add how long it usually takes, in hours.'; end if;
  if h2 <> '' and (h2 !~ '^[0-9]{1,2}(\.[0-9]{1,2})?$' or h2::numeric < h1::numeric) then raise exception 'The longer time is less than the shorter one.'; end if;
  src := case when p_hike->>'source' = 'website' then 'website' else 'walked' end;
  yr := trim(coalesce(p_hike->>'source_year',''));
  if src = 'website' then
    if url !~* '^https?://[^\s]+\.[^\s]+$' then raise exception 'Add the link to the page the hike is from.'; end if;
    if yr <> '' and yr !~ '^[0-9]{4}$' then raise exception 'Write the year the page is dated, or leave it empty.'; end if;
    if yr <> '' and yr::int > y0 then raise exception 'That year has not come yet.'; end if;
    if yr <> '' and yr::int < y0 - 3 and (h.id is null or h.source <> 'website' or h.source_year <> yr) then raise exception 'Pages older than 3 years are not taken.'; end if;
  else
    url := ''; yr := '';
  end if;
  -- the park or site the hike lies in: only when the page sent it (an older copy of the page leaves it as it is).
  -- Empty clears it. Otherwise it must be a supplier this member can see: the same test as _hike_park.
  if p_hike ? 'vendor_id' then
    vid := trim(coalesce(p_hike->>'vendor_id',''));
    if vid <> '' and (length(vid) > 60 or not exists (select 1 from public.vendors v where v.id = vid and not v.hidden
        and (m.is_admin or public._can_see(m, v.category, v.also_categories)))) then
      raise exception 'Choose the place from the list.'; end if;
  end if;
  if hid is null then
    if not m.is_admin and (select count(*) from public.hikes where added_by = m.email and created_at > now() - interval '1 day') >= 20 then
      raise exception 'Too many hikes in one day. Try again tomorrow.'; end if;
    insert into public.hikes (name, added_by, added_by_name, org, review_status, decided_by, decided_at)
    values (nm, m.email, m.name, public._limited(m),
            case when m.is_admin then 'approved' else 'pending' end, case when m.is_admin then m.email else '' end, case when m.is_admin then now() end)
    returning id into hid;
  end if;
  update public.hikes set
    name = nm,
    region = left(trim(p_hike->>'region'),60),
    distance_km = km, hours_from = h1, hours_to = case when h2 = h1 then '' else h2 end,
    start_place = left(trim(coalesce(p_hike->>'start_place','')),300),
    end_place = case when lp then '' else left(trim(coalesce(p_hike->>'end_place','')),300) end,
    is_loop = lp,
    markers = public._hike_markers_clean(p_hike->'markers'),
    notes = left(trim(coalesce(p_hike->>'notes','')),2000),
    official = true, source = src, source_url = left(url,500), source_year = yr,
    vendor_id = case when p_hike ? 'vendor_id' then vid else vendor_id end,
    review_status = case when not m.is_admin and review_status = 'rejected' then 'pending' else review_status end,
    updated_at = clock_timestamp()   -- the clock, not the start of the call: each change is its own version (see hike_decide)
  where id = hid returning * into h;
  if coalesce(p_hike->>'gpx','') <> '' then
    perform public._hike_gpx_put(hid, p_hike->>'gpx', m, true);
  elsif coalesce(p_hike->>'gpx_remove','') in ('true','t') then
    update public.hike_gpx set removed = true, updated_at = now() where hike_id = hid;
  end if;
  select * into h from public.hikes where id = hid;
  return public._hike_json(h, m);
end $function$;
revoke all on function public.hike_save(text,jsonb) from public; grant execute on function public.hike_save(text,jsonb) to anon, authenticated;

-- ===== replaced: _file_visible, with brochures open to organisations =====
-- A file on a supplier, for a limited member: his own, another organisation's, or a photo, kosher certificate or brochure.
-- Price lists, receipts, contracts, booking confirmations and quotes from guides and agents can carry agent rates.
create or replace function public._file_visible(f public.vendor_files, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when coalesce(m.is_admin, false) or f.uploaded_by = m.email then true
    when f.private then false
    when public._limited(m) then f.org or f.kind in ('Photo','Kosher certificate','Brochure')
    else true end
$function$;
revoke all on function public._file_visible(public.vendor_files,public.members) from public, anon, authenticated;
