-- Wineries under Restaurant and under Attraction / Site (12 Oct 2026). See docs/DECISIONS.md D-43.
-- Run after 2026-10-12_rentals.sql (it replaces _can_see, set_setting and whoami again, keeping what that file added).
-- supabase/schema.sql already includes everything below; this file is the step-by-step change. Safe to run twice.
-- It only adds and replaces: one new function, and _can_see, set_setting and whoami replaced. It removes nothing and
-- changes no supplier: the stored category stays Winery on every winery.
--
-- The owner, 12 Oct 2026, 09:30: "move winery and put it under sites"; 10:21, of the mock-up: "Looks good. But put
-- wineries under restaurants and under sites". On the page, Winery leaves the top row of categories; Restaurant and
-- Attraction / Site each get a Wineries button in their second row, and either one alone includes the wineries.
--
-- What changes in the database is only who-sees-what for organisations (limited members): a winery is visible to an
-- organisation that sees EITHER the restaurants section (food, as today) OR the sites section. No organisation loses a
-- winery it sees today. Like every new feature (G2) it waits for a switch:
--     wineries_for = 'admin' (the default): organisations see wineries with restaurants only, as before;
--                  = 'all': organisations that see sites see wineries too, and colleagues get the new buttons.
-- The Builder's Cockpit is not touched (rule F4 still maps wineries to Restaurant for any future Cockpit copy).

-- Wineries sit under sites as well as restaurants for everyone once the setting wineries_for is 'all'.
create or replace function public._wineries_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(m.is_admin or coalesce((select value from public.app_settings where key = 'wineries_for'), '') = 'all', false)
$function$;
revoke all on function public._wineries_on(public.members) from public, anon, authenticated;

-- May this member see a supplier of this category (main, or one of its "also offers")?
-- A supplier whose main category is Vehicle Rental is seen only where rentals are open (D-42); "also offers Vehicle
-- Rental" counts towards an organisation's sections only where rentals are open. A winery counts for the sites
-- section as well as for restaurants (food) once wineries are under both (D-43).
create or replace function public._can_see(m public.members, p_category text, p_also text)
 returns boolean language sql stable set search_path to ''
as $function$
  select case when coalesce(p_category,'') = 'Vehicle Rental' and not public._rentals_on(m) then false
    when not public._limited(m) then true
    else exists (select 1 from unnest(array[coalesce(p_category,'')] || string_to_array(coalesce(p_also,''), ',')) c
                 where trim(c) <> '' and (trim(c) <> 'Vehicle Rental' or public._rentals_on(m))
                   and (public._section_of(trim(c)) = any (string_to_array(m.sections, ','))
                        or (trim(c) = 'Winery' and 'sites' = any (string_to_array(m.sections, ',')) and public._wineries_on(m)))) end
$function$;
revoke all on function public._can_see(public.members,text,text) from public, anon, authenticated;

-- ===== the switch in the Team tab, and what the app is told =====
create or replace function public.set_setting(p_token text, p_key text, p_value text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email','bookings_for','jobs_for','hikes_for','rentals_for','wineries_for') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  if p_key = 'bookings_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'jobs_for' and lower(trim(p_value)) not in ('admin','receive','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'hikes_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'rentals_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'wineries_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
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
    'rentals', status = 'approved' and public._rentals_on(m),
    'rentals_for', case when is_admin then coalesce((select value from public.app_settings where key = 'rentals_for'),'admin') else '' end,
    'wineries', status = 'approved' and public._wineries_on(m),
    'wineries_for', case when is_admin then coalesce((select value from public.app_settings where key = 'wineries_for'),'admin') else '' end,
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
