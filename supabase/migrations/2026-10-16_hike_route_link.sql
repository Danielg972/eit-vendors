-- "Open in Mapeak" opens the hike's route (16 Oct 2026, D-53). Run after 2026-10-15_activity_feed.sql.
-- Adds only: one column on hike_gpx, its check and its index, and two functions (hike_route_link for the app,
-- _hike_route_public for the edge function only). Nothing is removed or changed.
-- Safe to run twice.
--
-- Mapeak opens a route from a web address (mapeak.com/url/<the file's address>): Mapeak's own server fetches the file
-- from that address, with no headers of ours. So the route file of a hike gets a public address: the "route" edge
-- function (supabase/functions/route/index.ts) answers https://<project>.supabase.co/functions/v1/route/<code>.gpx with
-- that hike's GPX and nothing else.
--
-- The code is kept on the route file's row (hike_gpx.link_code), not on the hike: the link is to the file, and the
-- row's own "removed" mark is what turns the link off. A route file that is replaced keeps its row (hike_save and
-- _hike_gpx_put update it in place), so it keeps its code: a link handed to Mapeak earlier shows the new route.
-- A route file that is removed stops the link at once (the edge function checks "removed"); if a route is later put
-- on the same hike again, the old code works again. A hike that is not approved (pending or taken off the list) has no
-- working link either: hike_route_link refuses it and the edge function checks it.
--
-- The code: 24 random bytes from pgcrypto, written in the 64 letters of web addresses (A-Z a-z 0-9 - _): 32 characters,
-- 192 bits. Made the first time a member asks for it, then the same for everyone.

alter table public.hike_gpx add column if not exists link_code text;
do $$ begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.hike_gpx'::regclass and conname = 'hike_gpx_link_code_check') then
    alter table public.hike_gpx add constraint hike_gpx_link_code_check check (link_code is null or link_code ~ '^[A-Za-z0-9_-]{32}$');
  end if;
end $$;
create unique index if not exists hike_gpx_link_code_idx on public.hike_gpx using btree (link_code) where link_code is not null;

-- The code of one hike's route file, for "Open in Mapeak". Same checks as hike_gpx (a member who has Hikes and can see
-- the hike), and the hike must be approved and have a route file that is not removed.
create or replace function public.hike_route_link(p_token text, p_id uuid)
 returns text language plpgsql security definer set search_path to ''
as $function$
declare m public.members; h public.hikes; c text;
begin
  m := public._auth(p_token);
  if not public._hikes_on(m) then raise exception 'Hikes are not open yet.' using errcode = '42501'; end if;
  select * into h from public.hikes where id = p_id;
  if not public._hike_visible(h, m) then raise exception 'That hike is not available.'; end if;
  if h.review_status <> 'approved' then raise exception 'This hike opens in Mapeak once Eretz Israel Tours has approved it.'; end if;
  select g.link_code into c from public.hike_gpx g where g.hike_id = p_id and not g.removed for update;
  if not found then raise exception 'This hike has no route file yet.'; end if;
  if c is null then
    c := translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/', '-_');
    update public.hike_gpx set link_code = c where hike_id = p_id;
  end if;
  return c;
end $function$;
revoke all on function public.hike_route_link(text,uuid) from public; grant execute on function public.hike_route_link(text,uuid) to anon, authenticated;

-- For the "route" edge function only (it calls this with the service key; nobody else can): the GPX text of the route
-- file that has this code, when the file is not removed and its hike is approved; null for anything else. Only the
-- body: never who added it, the hike's name or anything about a member.
create or replace function public._hike_route_public(p_code text)
 returns text language sql stable security definer set search_path to ''
as $function$
  select g.body from public.hike_gpx g join public.hikes h on h.id = g.hike_id
  where p_code ~ '^[A-Za-z0-9_-]{32}$' and g.link_code = p_code and not g.removed and h.review_status = 'approved'
$function$;
revoke all on function public._hike_route_public(text) from public, anon, authenticated; grant execute on function public._hike_route_public(text) to service_role;
