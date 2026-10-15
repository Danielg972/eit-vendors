-- Recent activity for Eretz Israel Tours (15 Oct 2026, D-49). Run after 2026-10-12c_vehicle_rental_category.sql.
-- One new function, activity_feed, for Eretz Israel Tours only (_auth with admin true): what colleagues did in the
-- last p_days days (1 to 60), newest first, at most 800 events. Adds only; nothing is removed or changed.
--
-- Each event: at, who (email), who_name, kind, what (plain words), vendor_id, vendor_name, detail.
-- Left out: Eretz Israel Tours' own actions, and rows written by imports or by Claude (their author is not a member's
-- email). Members' private notes and quotes are included: only Eretz Israel Tours can call this.
-- A member's "last opened the app" is the one time the database keeps (members.last_seen_at); earlier visits are
-- not stored, so they cannot be shown.

create or replace function public.activity_feed(p_token text, p_days integer default 7)
returns json
language plpgsql
security definer
set search_path to ''
as $function$
declare
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 7), 1), 60));
  me text;
begin
  me := lower((public._auth(p_token, true)).email);
  return coalesce((select json_agg(e order by e.at desc) from (
    select * from (
      -- joined, and last opened
      select m.created_at as at, m.email as who, 'joined' as kind, 'asked to join' as what, null::text as vendor_id, coalesce(nullif(m.role,''),'') as detail
        from public.members m where m.created_at > since
      union all select m.last_seen_at, m.email, 'seen', 'last opened the app', null, '' from public.members m where m.last_seen_at > since
      -- taps and filters
      union all select a.created_at, a.member, 'tap',
          case a.action when 'open' then 'opened' when 'call' then 'tapped Call on' when 'whatsapp' then 'tapped WhatsApp on'
            when 'email' then 'tapped Email on' when 'website' then 'opened the website of' when 'waze' then 'tapped Waze for'
            when 'maps' then 'tapped Google Maps for' when 'booking' then 'opened the booking link of' when 'deal' then 'opened a deal of'
            when 'file' then 'opened a file of' when 'agent' then 'opened the agent link of' when 'agent_ask' then 'asked for the agent rate of'
            else a.action end, a.vendor_id, ''
        from public.action_log a where a.created_at > since
      union all select f.created_at, f.member, 'filter', 'filtered by ' || f.kind, null, f.value from public.filter_log f where f.created_at > since
      -- additions and changes
      union all select v.created_at, v.created_by, 'add', 'added the supplier', v.id, v.category || case when v.review_status = 'pending' then ' · waiting for your review' else '' end
        from public.vendors v where v.created_at > since
      union all select v.updated_at, v.updated_by, 'edit', 'edited', v.id, 'last change only'
        from public.vendors v where v.updated_at > since and v.updated_at > v.created_at + interval '5 seconds'
      union all select p.created_at, p.created_by, 'add', 'added a price on', p.vendor_id,
          p.label || case when p.price <> '' then ' · ' || p.price || ' ' || p.currency else '' end || case when p.private then ' · private' else '' end
        from public.vendor_prices p where p.created_at > since
      union all select n.created_at, n.author, 'note', case when n.private then 'wrote a private note on' else 'wrote a note on' end, n.vendor_id,
          left(n.body, 300) || case when n.status = 'pending' then ' · waiting for your approval' else '' end
        from public.vendor_notes n where n.created_at > since
      union all select q.created_at, q.owner, 'add', 'added a quote on', q.vendor_id, q.status from public.quotes q where q.created_at > since
      union all select r.created_at, r.member, 'add', 'answered the reservation question at', r.vendor_id,
          case r.checked when 'yes' then 'they checked' when 'no' then 'not checked' else 'not sure' end
        from public.reservation_reports r where r.created_at > since
      union all select r.created_at, r.author, 'report', 'reported a problem with', r.vendor_id, r.kind || coalesce(nullif(': ' || left(r.message, 200), ': '), '')
        from public.vendor_reports r where r.created_at > since
      union all select f.created_at, f.uploaded_by, 'add', 'uploaded a file to', f.vendor_id, f.kind from public.vendor_files f where f.created_at > since
      union all select c.created_at, c.member, 'claim', 'asked to claim', c.vendor_id, c.status from public.vendor_claims c where c.created_at > since
      union all select c.created_at, c.requested_by, 'claim', 'suggested a change to', c.vendor_id, c.status from public.change_requests c where c.created_at > since
      union all select d.created_at, d.reported_by, 'add', 'added a deal on', d.vendor_id, d.title from public.vendor_deals d where d.created_at > since
      union all select f.created_at, f.author, 'add', 'added food nearby to', f.vendor_id, f.name from public.vendor_food f where f.created_at > since
      union all select r.created_at, r.author, 'note', 'reviewed a driver of', r.vendor_id, r.rating || '/5' from public.driver_reviews r where r.created_at > since
      union all select b.created_at, b.owner, 'add', 'started a booking sheet with', b.vendor_id, b.status from public.bookings b where b.created_at > since
      union all select j.created_at, j.owner, 'add', 'posted a job', null, j.title from public.jobs j where j.created_at > since
      union all select o.answered_at, o.member, 'add', 'answered a job offer', null, o.answer from public.job_offers o where o.answered_at > since
      union all select min(d.created_at), d.member, 'add', 'marked available days', null, string_agg(to_char(d.day, 'DD/MM'), ', ' order by d.day)
        from public.member_days d where d.created_at > since and d.source = 'tap' group by d.member, date_trunc('minute', d.created_at)
      union all select h.created_at, h.added_by, 'add', 'added a hike', null, h.name from public.hikes h where h.created_at > since
      union all select h.created_at, h.author, 'add', 'wrote a hike report', null, '' from public.hike_reports h where h.created_at > since
      union all select f.created_at, f.author, 'report', 'sent feedback', null, f.kind || ': ' || left(f.message, 200) from public.feedback f where f.created_at > since
    ) raw
    where raw.at is not null and lower(coalesce(raw.who, '')) <> me and raw.who ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    order by raw.at desc limit 800
  ) r0
  cross join lateral (select r0.at as at, lower(r0.who) as who, coalesce((select mm.name from public.members mm where mm.email = lower(r0.who)), r0.who) as who_name,
      r0.kind, r0.what, r0.vendor_id, (select vv.name from public.vendors vv where vv.id = r0.vendor_id) as vendor_name, r0.detail as detail) e), '[]'::json);
end $function$;

revoke all on function public.activity_feed(text, integer) from public;
grant execute on function public.activity_feed(text, integer) to anon, authenticated;
