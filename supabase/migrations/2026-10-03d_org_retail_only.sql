-- D-18 (3 Oct 2026): organisations (limited members) see retail prices only.
-- The owner, 3 Oct 2026, 22:23: "yeshivas and outside organizers ONLY see retail pricing NEVER pricing thats agent
-- or pricing history of any guides or others users, the only exception is transportation. they can contribute to all"
--
-- Before this, an organisation whose "guide rates" switch was on also saw what guides and agents had been quoted
-- for a guide (an implementation choice under D-15). Now the only quotes from guides and agents that an
-- organisation sees are bus and van quotes. The switch still shows a guide's listed price and retail price.
-- Nothing else changes: agent prices and other members' own price lines were never sent; what organisations
-- add themselves (rates, quotes, reviews) is still shown to everyone.
--
-- Replaces one internal helper. No table, column or grant changes; no DELETE, no DROP. Safe to run twice.

create or replace function public._quote_visible(q public.quotes, v public.vendors, m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select case when coalesce(m.is_admin, false) then true
    when public._limited(m) and not public._can_see(m, v.category, v.also_categories) then false
    when q.owner = m.email then true
    when not q.shared or v.prices_private then false
    when not public._limited(m) then true
    when q.org then true
    when public._quote_kind(q, v) = 'transport' then m.see_quotes and 'transport' = any (string_to_array(m.sections, ','))
    else false end   -- D-18: an organisation never sees what a guide or an agent was quoted, except for transport
$function$;
