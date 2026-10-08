-- Hikes (8 Oct 2026). See docs/DECISIONS.md D-31. Run after 2026-10-05c_quote_wording.sql.
-- Paste the whole file into the Supabase SQL editor for project wjuqtjlrtcywjaspjpwu and run it once.
-- supabase/schema.sql already includes everything below; this file is the step-by-step change. Safe to run twice.
-- It only adds and replaces: three new tables, new functions, and whoami and set_setting replaced (each gains
-- the hikes switch; everything else in them is as it was).
--
-- A hike is an official marked trail a guide can take a group on: a route file (GPX), important notes, the distance
-- and how long it usually takes, where it starts and ends, and the trail markers on the way. After walking it, a
-- member adds a report: group size, ages, difficulty, cliffs, water shoes, points of interest, firing zone, water,
-- bathrooms, whether you can eat on the way. Colleagues see what was reported, with the name of who wrote it.
--
-- Who sees what:
--   * Until Eretz Israel Tours changes the setting hikes_for, only Eretz Israel Tours sees any of it:
--       'admin' = Eretz Israel Tours only (the default)      'all' = every approved member
--   * Organisations (limited members) see hikes like everyone else and can add hikes and reports (owner, 8 Oct).
--   * A hike a member adds waits for Eretz Israel Tours' approval; until then only he and Eretz Israel Tours see it.
--   * Nobody receives another member's email or phone: a name only.
--   * A hike taken from a website carries the link and the year of the page ('' = no date on the page). Pages more
--     than 3 years old are refused. The app shows such a hike as Unverified until a member has reported walking it.
--   * Group size and ages are numbers. No client's name and no trip details belong in any field here.

-- ===== tables =====
create table if not exists public.hikes (
  id uuid default gen_random_uuid() not null,
  name text not null,
  region text default ''::text not null,
  distance_km text default ''::text not null,
  hours_from text default ''::text not null,
  hours_to text default ''::text not null,
  start_place text default ''::text not null,
  end_place text default ''::text not null,
  is_loop boolean default false not null,
  markers jsonb default '[]'::jsonb not null,
  notes text default ''::text not null,
  official boolean default true not null,
  source text default 'walked'::text not null,
  source_url text default ''::text not null,
  source_year text default ''::text not null,
  review_status text default 'pending'::text not null,
  added_by text not null,
  added_by_name text default ''::text not null,
  org boolean default false not null,
  decided_by text default ''::text not null,
  decided_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint hikes_pkey primary key (id),
  constraint hikes_name_check check (length(trim(both from name)) >= 3 and length(name) <= 120),
  constraint hikes_source_check check (source = any (array['walked'::text, 'website'::text])),
  constraint hikes_status_check check (review_status = any (array['pending'::text, 'approved'::text, 'rejected'::text])),
  constraint hikes_numbers_check check ((distance_km = ''::text or distance_km ~ '^[0-9]{1,3}(\.[0-9]{1,2})?$'::text)
    and (hours_from = ''::text or hours_from ~ '^[0-9]{1,2}(\.[0-9]{1,2})?$'::text) and (hours_to = ''::text or hours_to ~ '^[0-9]{1,2}(\.[0-9]{1,2})?$'::text)
    and (source_year = ''::text or source_year ~ '^[0-9]{4}$'::text)),
  constraint hikes_lengths_check check (length(region) <= 60 and length(start_place) <= 300 and length(end_place) <= 300
    and length(notes) <= 2000 and length(source_url) <= 500 and length(markers::text) <= 1200)
);
alter table public.hikes enable row level security;
create index if not exists hikes_status_idx on public.hikes using btree (review_status, region);
create index if not exists hikes_added_idx on public.hikes using btree (added_by);

-- One row per walk a member reports. hidden = taken off by its writer or by Eretz Israel Tours; the row is kept.
create table if not exists public.hike_reports (
  id uuid default gen_random_uuid() not null,
  hike_id uuid not null,
  author text not null,
  author_name text default ''::text not null,
  org boolean default false not null,
  walked_on text not null,
  group_size text default ''::text not null,
  age_min text default ''::text not null,
  age_max text default ''::text not null,
  difficulty text default ''::text not null,
  cliffs text default ''::text not null,
  cliffs_note text default ''::text not null,
  water_shoes text default ''::text not null,
  start_place text default ''::text not null,
  end_place text default ''::text not null,
  poi text default ''::text not null,
  firing_zone text default ''::text not null,
  water_route text default ''::text not null,
  drinking_water text default ''::text not null,
  bathrooms text default ''::text not null,
  eat text default ''::text not null,
  eat_note text default ''::text not null,
  note text default ''::text not null,
  hidden boolean default false not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint hike_reports_pkey primary key (id),
  constraint hike_reports_date_check check (walked_on ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'::text),
  constraint hike_reports_numbers_check check ((group_size = ''::text or group_size ~ '^[0-9]{1,3}$'::text)
    and (age_min = ''::text or age_min ~ '^[0-9]{1,3}$'::text) and (age_max = ''::text or age_max ~ '^[0-9]{1,3}$'::text)),
  constraint hike_reports_choices_check check (difficulty = any (array[''::text, 'easy'::text, 'moderate'::text, 'hard'::text])
    and cliffs = any (array[''::text, 'yes'::text, 'no'::text])
    and water_shoes = any (array[''::text, 'needed'::text, 'useful'::text, 'not_needed'::text])
    and firing_zone = any (array[''::text, 'crosses'::text, 'no'::text, 'unsure'::text])
    and water_route = any (array[''::text, 'yes'::text, 'season'::text, 'no'::text])
    and drinking_water = any (array[''::text, 'yes'::text, 'no'::text])
    and eat = any (array[''::text, 'yes'::text, 'no'::text])
    and bathrooms ~ '^((start|end|none)(,(start|end|none))*)?$'::text),
  constraint hike_reports_lengths_check check (length(cliffs_note) <= 200 and length(start_place) <= 300 and length(end_place) <= 300
    and length(poi) <= 600 and length(eat_note) <= 200 and length(note) <= 1500)
);
alter table public.hike_reports enable row level security;
create index if not exists hike_reports_hike_idx on public.hike_reports using btree (hike_id, walked_on desc);
create index if not exists hike_reports_author_idx on public.hike_reports using btree (author);

-- A hike's route file: the GPX text itself, one per hike, holding the route only (points, heights, names of marked
-- spots): no recorder's name, email or times, and not the file's own name.
-- removed = taken off; the row is kept.
create table if not exists public.hike_gpx (
  hike_id uuid not null,
  name text default 'route.gpx'::text not null,
  body text not null,
  added_by text not null,
  added_by_name text default ''::text not null,
  removed boolean default false not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint hike_gpx_pkey primary key (hike_id),
  constraint hike_gpx_size_check check (length(body) <= 2000000 and length(name) <= 110)
);
alter table public.hike_gpx enable row level security;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'hike_reports_hike_id_fkey') then
    alter table public.hike_reports add constraint hike_reports_hike_id_fkey foreign key (hike_id) references public.hikes(id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'hike_gpx_hike_id_fkey') then
    alter table public.hike_gpx add constraint hike_gpx_hike_id_fkey foreign key (hike_id) references public.hikes(id);
  end if;
end $$;

revoke all on table public.hikes, public.hike_reports, public.hike_gpx from public, anon, authenticated;
grant all on table public.hikes, public.hike_reports, public.hike_gpx to service_role;

-- ===== helpers (not callable from outside) =====
-- Hikes are open to Eretz Israel Tours, and to every approved member once the setting hikes_for is 'all'.
create or replace function public._hikes_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(m.is_admin or coalesce((select value from public.app_settings where key = 'hikes_for'), '') = 'all', false)
$function$;
revoke all on function public._hikes_on(public.members) from public, anon, authenticated;

-- May this member see this hike? Approved hikes: everyone. Waiting or turned down: its writer and Eretz Israel Tours.
create or replace function public._hike_visible(h public.hikes, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select coalesce(h.id is not null and (h.review_status = 'approved' or m.is_admin or h.added_by = m.email), false)
$function$;
revoke all on function public._hike_visible(public.hikes,public.members) from public, anon, authenticated;

-- Trail markers: up to 8, in walking order, each a known colour and/or a trail number. Both are optional.
create or replace function public._hike_markers_clean(p jsonb)
 returns jsonb language sql immutable set search_path to ''
as $function$
  select coalesce(jsonb_agg(jsonb_build_object('color', c, 'number', n) order by i), '[]'::jsonb)
  from (select i,
          case when lower(coalesce(e->>'color','')) in ('red','blue','green','black','israel_trail','other') then lower(e->>'color') else '' end as c,
          case when trim(coalesce(e->>'number','')) ~ '^[0-9]{1,6}$' then trim(e->>'number') else '' end as n
        from jsonb_array_elements(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) with ordinality as t(e, i)
        where i <= 8) x
  where c <> '' or n <> ''
$function$;
revoke all on function public._hike_markers_clean(jsonb) from public, anon, authenticated;

-- A hike as one member receives it, with a summary of the reports. Names only: never an email.
-- Cliffs and firing zone: one report saying yes is enough for the summary to say so.
create or replace function public._hike_json(h public.hikes, m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',h.id,'name',h.name,'region',h.region,'distance_km',h.distance_km,'hours_from',h.hours_from,'hours_to',h.hours_to,
    'start_place',h.start_place,'end_place',h.end_place,'is_loop',h.is_loop,'markers',h.markers,'notes',h.notes,'official',h.official,
    'source',h.source,'source_url',h.source_url,'source_year',h.source_year,'review_status',h.review_status,
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

-- A hike with its reports, newest walk first.
create or replace function public._hike_detail_json(h public.hikes, m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('hike', public._hike_json(h, m),
    'reports', coalesce((select json_agg(json_build_object('id',r.id,'walked_on',r.walked_on,'group_size',r.group_size,'age_min',r.age_min,'age_max',r.age_max,
        'difficulty',r.difficulty,'cliffs',r.cliffs,'cliffs_note',r.cliffs_note,'water_shoes',r.water_shoes,'start_place',r.start_place,'end_place',r.end_place,
        'poi',r.poi,'firing_zone',r.firing_zone,'water_route',r.water_route,'drinking_water',r.drinking_water,'bathrooms',r.bathrooms,'eat',r.eat,'eat_note',r.eat_note,
        'note',r.note,'by',public._name(r.author),'org',r.org,'mine',r.author = m.email,'can_edit',m.is_admin or r.author = m.email,'created_at',r.created_at)
        order by r.walked_on desc, r.created_at desc)
      from public.hike_reports r where r.hike_id = h.id and not r.hidden), '[]'::json))
$function$;
revoke all on function public._hike_detail_json(public.hikes,public.members) from public, anon, authenticated;

-- Save a route file on a hike. Only the plain route the app itself writes is taken (index.html, hkCleanGpx): one
-- <gpx> element in the GPX 1.1 namespace holding marked spots (<wpt>, with an optional height and a short name),
-- routes (<rte> of <rtept>) and tracks (<trk> of <trkseg> of <trkpt>), each point with lat and lon (inside the
-- globe) and an optional height, at most 200 marked spots, and nothing else: no other element or attribute, no comment, no instruction, no loose text. So what a
-- recording app adds (the recorder's name and email, the times of the walk, the name of the recording) cannot be
-- stored, and the file's own name is not kept either: every route file is called route.gpx.
-- The check reads the text a fixed number of times, whatever is in it: each valid piece is swapped for a marker
-- character, from the points outwards, and what is left must be the bare <gpx> element around markers.
-- p_replace false = only when the hike has no route file (checked and written in one step, so two members sending
-- at the same moment cannot both win).
create or replace function public._hike_gpx_put(p_hike uuid, p_body text, m public.members, p_replace boolean)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare t text; n int;
  lat constant text := '-?([0-8]?[0-9](\.[0-9]{1,6})?|90)'; lon constant text := '-?((1[0-7][0-9]|[0-9]{1,2})(\.[0-9]{1,6})?|180)';
  ele constant text := '<ele>-?[0-9]{1,5}(\.[0-9])?</ele>';
  pos constant text := ' lat="' || lat || '" lon="' || lon || '"';
  k_trkpt constant text := chr(1); k_rtept constant text := chr(2); k_wpt constant text := chr(3); k_seg constant text := chr(4); k_line constant text := chr(5);
begin
  if p_body is null or length(p_body) > 2000000 then raise exception 'That route file is too large. Save it with fewer points and try again.'; end if;
  if p_body ~ '[\x01-\x08\x0B\x0C\x0E-\x1F]' or position('<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle">' in p_body) <> 1 then
    raise exception 'That does not look like a GPX route file.'; end if;
  if (length(p_body) - length(replace(p_body, '<wpt', ''))) / 4 > 200 then
    raise exception 'That route file holds something a GPX file should not. Save it again from your hiking app.'; end if;
  t := regexp_replace(p_body, '<trkpt' || pos || '(/>|>(' || ele || ')?</trkpt>)', k_trkpt, 'g');
  t := regexp_replace(t, '<rtept' || pos || '(/>|>(' || ele || ')?</rtept>)', k_rtept, 'g');
  n := length(t) - length(replace(replace(t, k_trkpt, ''), k_rtept, ''));
  t := regexp_replace(t, '<wpt' || pos || '(/>|>(' || ele || ')?(<name>([^<>&\x01-\x1F\uFFFE\uFFFF]|&(amp|lt|gt);){1,60}</name>)?</wpt>)', k_wpt, 'g');
  t := regexp_replace(t, '<trkseg>' || k_trkpt || '+</trkseg>', k_seg, 'g');
  t := regexp_replace(t, '<trk>' || k_seg || '+</trk>', k_line, 'g');
  t := regexp_replace(t, '<rte>' || k_rtept || '+</rte>', k_line, 'g');
  if t !~ ('^<gpx xmlns="http://www\.topografix\.com/GPX/1/1" version="1\.1" creator="The Inner Circle">' || k_wpt || '*' || k_line || '*</gpx>$') then
    raise exception 'That route file holds something a GPX file should not. Save it again from your hiking app.'; end if;
  if n < 2 then raise exception 'That route file has no route in it.'; end if;
  insert into public.hike_gpx (hike_id, name, body, added_by, added_by_name) values (p_hike, 'route.gpx', p_body, m.email, m.name)
  on conflict (hike_id) do update set name = excluded.name, body = excluded.body, added_by = excluded.added_by,
    added_by_name = excluded.added_by_name, removed = false, updated_at = now()
    where p_replace or public.hike_gpx.removed;
  get diagnostics n = row_count;
  if n = 0 then raise exception 'This hike already has a route file.'; end if;
  update public.hikes set updated_at = clock_timestamp() where id = p_hike;
end $function$;
revoke all on function public._hike_gpx_put(uuid,text,public.members,boolean) from public, anon, authenticated;

-- ===== RPCs (member token) =====
-- Every hike this member may see, by region and name. No route files and no reports: those come one hike at a time.
create or replace function public.hikes_list(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if not public._hikes_on(m) then return '[]'::json; end if;
  return coalesce((select json_agg(public._hike_json(h, m) order by h.region, lower(h.name)) from public.hikes h where public._hike_visible(h, m)), '[]'::json);
end $function$;
revoke all on function public.hikes_list(text) from public; grant execute on function public.hikes_list(text) to anon, authenticated;

create or replace function public.hike_detail(p_token text, p_id uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; h public.hikes;
begin
  m := public._auth(p_token);
  if not public._hikes_on(m) then raise exception 'Hikes are not open yet.' using errcode = '42501'; end if;
  select * into h from public.hikes where id = p_id;
  if not public._hike_visible(h, m) then raise exception 'That hike is not available.'; end if;
  return public._hike_detail_json(h, m);
end $function$;
revoke all on function public.hike_detail(text,uuid) from public; grant execute on function public.hike_detail(text,uuid) to anon, authenticated;

-- Add a hike, or change one. A member's new hike waits for approval. Once approved, only Eretz Israel Tours changes it.
-- The 3-year rule is asked when a hike is added or its page year is changed, not when an older entry is corrected.
create or replace function public.hike_save(p_token text, p_hike jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; hid uuid; h public.hikes; src text; yr text; nm text;
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

-- Eretz Israel Tours approves a hike, or takes it off the list (it is kept, and can be approved again).
-- Approving names the version that was read (p_seen = the hike's updated_at as the list or the page gave it): if the
-- writer changed the hike, its route file or his reports on it after that, the approval is refused, so nothing unread
-- goes out to colleagues.
create or replace function public.hike_decide(p_token text, p_id uuid, p_approve boolean, p_seen timestamp with time zone default null)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members; h public.hikes;
begin
  m := public._auth(p_token, true);
  if p_approve is null then raise exception 'Say whether to approve it.'; end if;
  select * into h from public.hikes where id = p_id for update;   -- waits for a save that is under way, then reads what it left
  if h.id is null then raise exception 'That hike is not available.'; end if;
  if p_approve and (p_seen is null or p_seen <> h.updated_at) then
    raise exception 'This hike was changed after you opened it. Open it again and check it before you approve.'; end if;
  update public.hikes set review_status = case when p_approve then 'approved' else 'rejected' end,
    decided_by = m.email, decided_at = now() where id = p_id;
end $function$;
revoke all on function public.hike_decide(text,uuid,boolean,timestamp with time zone) from public; grant execute on function public.hike_decide(text,uuid,boolean,timestamp with time zone) to anon, authenticated;

-- A report after walking the hike, or a change to one's own report. Returns the hike with all its reports.
create or replace function public.hike_report_save(p_token text, p_hike uuid, p_report jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; h public.hikes; rid uuid; d date;
  today date := (now() at time zone 'Asia/Jerusalem')::date;
  gs text := trim(coalesce(p_report->>'group_size','')); a1 text := trim(coalesce(p_report->>'age_min','')); a2 text := trim(coalesce(p_report->>'age_max',''));
begin
  m := public._auth(p_token);
  if not public._hikes_on(m) then raise exception 'Hikes are not open yet.' using errcode = '42501'; end if;
  if p_report is null or jsonb_typeof(p_report) <> 'object' or pg_column_size(p_report) > 2600000 then raise exception 'That is more than a report holds. Check it and try again.'; end if;
  select * into h from public.hikes where id = p_hike for update;   -- one order everywhere: the hike, then its reports, then its route file
  if not public._hike_visible(h, m) then raise exception 'That hike is not available.'; end if;
  begin
    rid := nullif(p_report->>'id','')::uuid;
  exception when others then raise exception 'Only the person who wrote this report, or Eretz Israel Tours, can change it.';
  end;
  d := public._to_date(p_report->>'walked_on');
  if d is null then raise exception 'Add the date you walked it.'; end if;
  if d > today then raise exception 'That date has not come yet.'; end if;
  if d < date '2000-01-01' then raise exception 'Check the year of the date.'; end if;
  if gs <> '' and (gs !~ '^[0-9]{1,3}$' or gs::int < 1) then raise exception 'Write the group size as a number.'; end if;
  if (a1 <> '' and (a1 !~ '^[0-9]{1,3}$' or a1::int > 110)) or (a2 <> '' and (a2 !~ '^[0-9]{1,3}$' or a2::int > 110)) then raise exception 'Write the ages as numbers.'; end if;
  if a1 <> '' and a2 <> '' and a1::int > a2::int then raise exception 'The youngest is older than the oldest.'; end if;
  if rid is not null then
    if not exists (select 1 from public.hike_reports where id = rid and hike_id = p_hike and not hidden and (author = m.email or m.is_admin)) then
      raise exception 'Only the person who wrote this report, or Eretz Israel Tours, can change it.' using errcode = '42501'; end if;
  else
    if not m.is_admin and (select count(*) from public.hike_reports where author = m.email and created_at > now() - interval '1 day') >= 30 then
      raise exception 'Too many reports in one day. Try again tomorrow.'; end if;
    insert into public.hike_reports (hike_id, author, author_name, org, walked_on)
    values (p_hike, m.email, m.name, public._limited(m), to_char(d, 'YYYY-MM-DD')) returning id into rid;
  end if;
  update public.hike_reports set
    walked_on = to_char(d, 'YYYY-MM-DD'), group_size = gs, age_min = a1, age_max = a2,
    difficulty = case when p_report->>'difficulty' in ('easy','moderate','hard') then p_report->>'difficulty' else '' end,
    cliffs = case when p_report->>'cliffs' in ('yes','no') then p_report->>'cliffs' else '' end,
    cliffs_note = left(trim(coalesce(p_report->>'cliffs_note','')),200),
    water_shoes = case when p_report->>'water_shoes' in ('needed','useful','not_needed') then p_report->>'water_shoes' else '' end,
    start_place = left(trim(coalesce(p_report->>'start_place','')),300),
    end_place = left(trim(coalesce(p_report->>'end_place','')),300),
    poi = left(trim(coalesce(p_report->>'poi','')),600),
    firing_zone = case when p_report->>'firing_zone' in ('crosses','no','unsure') then p_report->>'firing_zone' else '' end,
    water_route = case when p_report->>'water_route' in ('yes','season','no') then p_report->>'water_route' else '' end,
    drinking_water = case when p_report->>'drinking_water' in ('yes','no') then p_report->>'drinking_water' else '' end,
    bathrooms = public._csv_keys(p_report->>'bathrooms', array['start','end','none']),
    eat = case when p_report->>'eat' in ('yes','no') then p_report->>'eat' else '' end,
    eat_note = left(trim(coalesce(p_report->>'eat_note','')),200),
    note = left(trim(coalesce(p_report->>'note','')),1500),
    updated_at = now()
  where id = rid;
  update public.hikes set updated_at = clock_timestamp() where id = p_hike and review_status <> 'approved';   -- so an approval names what was read
  if coalesce(p_report->>'gpx','') <> '' then
    perform public._hike_gpx_put(p_hike, p_report->>'gpx', m, m.is_admin);
  end if;
  select * into h from public.hikes where id = p_hike;
  return public._hike_detail_json(h, m);
end $function$;
revoke all on function public.hike_report_save(text,uuid,jsonb) from public; grant execute on function public.hike_report_save(text,uuid,jsonb) to anon, authenticated;

-- Take a report off: its writer, or Eretz Israel Tours. The row is kept.
create or replace function public.hike_report_hide(p_token text, p_id uuid)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members; hid uuid;
begin
  m := public._auth(p_token);
  if not public._hikes_on(m) then raise exception 'Hikes are not open yet.' using errcode = '42501'; end if;
  select hike_id into hid from public.hike_reports where id = p_id and not hidden and (author = m.email or m.is_admin);
  if hid is null then raise exception 'Only the person who wrote this report, or Eretz Israel Tours, can take it off.' using errcode = '42501'; end if;
  perform 1 from public.hikes where id = hid for update;   -- the hike first, then its report: the same order as everywhere else
  update public.hike_reports set hidden = true, updated_at = now() where id = p_id and not hidden;
  if not found then raise exception 'Only the person who wrote this report, or Eretz Israel Tours, can take it off.' using errcode = '42501'; end if;
  update public.hikes set updated_at = clock_timestamp() where id = hid and review_status <> 'approved';
end $function$;
revoke all on function public.hike_report_hide(text,uuid) from public; grant execute on function public.hike_report_hide(text,uuid) to anon, authenticated;

-- The route file of one hike, to save or to open in a hiking app.
create or replace function public.hike_gpx(p_token text, p_id uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; h public.hikes; out json;
begin
  m := public._auth(p_token);
  if not public._hikes_on(m) then raise exception 'Hikes are not open yet.' using errcode = '42501'; end if;
  select * into h from public.hikes where id = p_id;
  if not public._hike_visible(h, m) then raise exception 'That hike is not available.'; end if;
  select json_build_object('name', g.name, 'body', g.body) into out from public.hike_gpx g where g.hike_id = p_id and not g.removed;
  if out is null then raise exception 'This hike has no route file yet.'; end if;
  return out;
end $function$;
revoke all on function public.hike_gpx(text,uuid) from public; grant execute on function public.hike_gpx(text,uuid) to anon, authenticated;

-- ===== replaced: set_setting and whoami, each with the hikes switch added =====
create or replace function public.set_setting(p_token text, p_key text, p_value text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email','bookings_for','jobs_for','hikes_for') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  if p_key = 'bookings_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'jobs_for' and lower(trim(p_value)) not in ('admin','receive','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'hikes_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  insert into public.app_settings (key, value) values (p_key, lower(trim(p_value))) on conflict (key) do update set value = excluded.value;
end $function$;
revoke all on function public.set_setting(text,text,text) from public; grant execute on function public.set_setting(text,text,text) to anon, authenticated;

-- whoami: also what kind of member this is and what he sees, so the app shows only that.
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
    'member_type', case when public._limited(m) then 'limited' else 'full' end,
    'sections', case when public._limited(m) then sections else '' end,
    'see_quotes', not public._limited(m) or see_quotes,
    'see_guide_rates', not public._limited(m) or see_guide_rates,
    'see_transport_reviews', not public._limited(m) or see_transport_reviews,
    'see_reviews', not public._limited(m) or see_reviews,
    'org', org)
  from public.members m where token_hash = public._hash(p_token);
$function$;
revoke all on function public.whoami(text) from public; grant execute on function public.whoami(text) to anon, authenticated;
