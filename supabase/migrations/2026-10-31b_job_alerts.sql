-- D-69 (31 Oct 2026): job alerts by phone notification and email, the jobs WhatsApp group link, and colleagues' jobs
-- offered to Eretz Israel Tours for that group. See docs/DECISIONS.md D-69. Run after 2026-10-31_job_days.sql.
-- Only adds and replaces. Nothing is deleted. No table grant to anon or authenticated, no policy. Safe to run twice.
-- Not replaced: job_save, job_set_status, job_delete, my_days_set (their bodies hold DELETE) and whoami.
-- Replaced: set_setting (three more keys) and _job_json (two fields for Eretz Israel Tours only). Neither holds DELETE.
--
-- How it works
--   Triggers on public.jobs and public.job_offers put rows in public.alert_queue: one per member, event and channel
--   (push or email). The Edge Function job-alerts (supabase/functions/job-alerts) reads the waiting rows with the
--   service key, holds everything over Shabbat and Yom Tov and from 23:00 to 07:00 Israel time, sends, and marks each
--   row sent, skipped or failed. Rows are never deleted.
--   Events:
--     job_new        a job was posted (job_save: title '' -> not empty). To the colleagues it fits (see _alert_recipients).
--     group_review   a colleague (not Eretz Israel Tours) posted a job. To Eretz Israel Tours: share it to the jobs group?
--     job_given      status -> 'filled'. To the colleague it was given to.
--     job_closed     status -> 'closed'. To everyone who said "I'm available".
--     job_available  job_offers.answer -> 'yes'. To the poster.
--   No alert on edits. Nothing in an alert names the poster or anyone else.
--   Who gets alerts at all: setting alerts_for. 'admin' (the default) = only Eretz Israel Tours, to try it first (G2);
--   'all' = every approved full member. Organisations (limited members) never (C4).

-- ===== members: the email switch, and the key for the one-tap unsubscribe link in each email =====
alter table public.members
  add column if not exists alerts_email boolean default true not null,
  add column if not exists alerts_key text default encode(extensions.gen_random_bytes(18), 'hex') not null;
create unique index if not exists members_alerts_key_idx on public.members using btree (alerts_key);

-- ===== jobs: Eretz Israel Tours' answer on a colleague's job for the jobs WhatsApp group =====
alter table public.jobs
  add column if not exists group_status text default ''::text not null,
  add column if not exists group_at timestamp with time zone,
  add column if not exists group_by text default ''::text not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'jobs_group_status_check') then
    alter table public.jobs add constraint jobs_group_status_check check (group_status = any (array[''::text, 'shared'::text, 'skipped'::text]));
  end if;
end $$;

-- ===== the phones a member turned alerts on for (web push subscriptions) =====
create table if not exists public.push_subs (
  id uuid default gen_random_uuid() not null,
  member text not null,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  device text default ''::text not null,
  dead boolean default false not null,
  fails integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  last_ok_at timestamp with time zone,
  constraint push_subs_pkey primary key (id),
  constraint push_subs_endpoint_key unique (endpoint),
  constraint push_subs_check check (endpoint ~ '^https://' and length(endpoint) <= 1000 and length(p256dh) between 60 and 120
    and length(auth) between 10 and 40 and length(device) <= 120)
);
alter table public.push_subs enable row level security;
create index if not exists push_subs_member_idx on public.push_subs using btree (member) where not dead;

-- ===== the queue =====
create table if not exists public.alert_queue (
  id uuid default gen_random_uuid() not null,
  member text not null,
  event text not null,
  job_id uuid,
  about text default ''::text not null,
  channel text not null,
  status text default 'waiting'::text not null,
  created_at timestamp with time zone default now() not null,
  claimed_at timestamp with time zone,
  tries integer default 0 not null,
  sent_at timestamp with time zone,
  error text default ''::text not null,
  constraint alert_queue_pkey primary key (id),
  constraint alert_queue_event_check check (event = any (array['job_new'::text, 'group_review'::text, 'job_given'::text, 'job_closed'::text, 'job_available'::text])),
  constraint alert_queue_channel_check check (channel = any (array['push'::text, 'email'::text])),
  constraint alert_queue_status_check check (status = any (array['waiting'::text, 'sent'::text, 'skipped'::text, 'failed'::text])),
  constraint alert_queue_error_check check (length(error) <= 500)
);
alter table public.alert_queue enable row level security;
create unique index if not exists alert_queue_once_idx on public.alert_queue using btree (member, event, job_id, channel, about);
create index if not exists alert_queue_waiting_idx on public.alert_queue using btree (created_at) where status = 'waiting';
create index if not exists alert_queue_job_idx on public.alert_queue using btree (job_id);

revoke all on table public.push_subs, public.alert_queue from public, anon, authenticated;
grant all on table public.push_subs, public.alert_queue to service_role;

-- ===== internal helpers (not RPCs) =====
create or replace function public._setting(p_key text)
 returns text language sql stable security definer set search_path to ''
as $function$
  select coalesce((select value from public.app_settings where key = p_key), '')
$function$;
revoke all on function public._setting(text) from public, anon, authenticated;

-- Does this member get alerts at all? Eretz Israel Tours always; colleagues once alerts_for is 'all'. Never an organisation.
create or replace function public._alerts_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select coalesce(m.status = 'approved' and not public._limited(m) and public._jobs_on(m) and (m.is_admin or public._setting('alerts_for') = 'all'), false)
$function$;
revoke all on function public._alerts_on(public.members) from public, anon, authenticated;

-- The owner, 31 Oct 2026: "(b) Guide jobs alert only guides, but a driver job alerts drivers".
-- guide / guide_vehicle: a licensed tour guide, unless he said he takes no jobs or set what he takes without this kind.
-- van_driver / jeep_driver / other: only a member who ticked that kind in "Jobs I take".
-- Must-haves as on the Jobs tab (_job_fits). The Jobs tab itself is unchanged.
create or replace function public._alert_kind_fits(p_kind text, p_needs text, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select public._job_fits(p_kind, p_needs, m)
    and case when p_kind in ('guide','guide_vehicle') then m.role = 'Licensed tour guide' else m.job_kinds <> '' end
$function$;
revoke all on function public._alert_kind_fits(text,text,public.members) from public, anon, authenticated;

-- Who a new job alerts: approved full members, never the poster, never an organisation, nobody busy on its dates.
-- 'picked': only the colleagues picked. 'all': as _alert_kind_fits; Eretz Israel Tours is left out here, because it gets
-- the group_review alert for a colleague's job instead.
create or replace function public._alert_recipients(j public.jobs)
 returns setof text language sql stable security definer set search_path to ''
as $function$
  select distinct m.email from public.members m
  where m.status = 'approved' and not public._limited(m) and m.email <> j.owner
    and case when j.audience = 'picked'
      then exists (select 1 from public.job_offers f where f.job_id = j.id and f.member = m.email and f.picked)
      else not m.is_admin and public._alert_kind_fits(j.kind, j.needs, m) end
    and public._day_state(m.email, j.date_from, j.date_to, true) <> 'busy'
$function$;
revoke all on function public._alert_recipients(public.jobs) from public, anon, authenticated;

-- One queue row per channel the member has: push if a phone is on, email if his email switch is on. Each alert once.
create or replace function public._alert_add(p_member text, p_event text, p_job uuid, p_about text default '')
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  select * into m from public.members where email = p_member and status = 'approved' order by created_at limit 1;
  if m.id is null or not public._alerts_on(m) then return; end if;
  if exists (select 1 from public.push_subs s where s.member = m.email and not s.dead) then
    insert into public.alert_queue (member, event, job_id, about, channel) values (m.email, p_event, p_job, coalesce(p_about,''), 'push')
      on conflict (member, event, job_id, channel, about) do nothing;
  end if;
  if m.alerts_email then
    insert into public.alert_queue (member, event, job_id, about, channel) values (m.email, p_event, p_job, coalesce(p_about,''), 'email')
      on conflict (member, event, job_id, channel, about) do nothing;
  end if;
end $function$;
revoke all on function public._alert_add(text,text,uuid,text) from public, anon, authenticated;

-- ===== triggers =====
-- A new job. job_save inserts an empty row and then fills it, so creation is the title going from '' to something.
-- Deferred to the end of the transaction, so the picked colleagues (written after the update) are there.
create or replace function public._jobs_alert_new()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare j public.jobs; r text;
begin
  select * into j from public.jobs where id = new.id;
  if j.id is null or j.status <> 'open' then return null; end if;
  for r in select * from public._alert_recipients(j) loop
    perform public._alert_add(r, 'job_new', j.id, '');
  end loop;
  if not exists (select 1 from public.members o where o.email = j.owner and o.is_admin) then
    for r in select distinct a.email from public.members a where a.is_admin and a.status = 'approved' loop
      perform public._alert_add(r, 'group_review', j.id, '');
    end loop;
  end if;
  return null;
end $function$;
revoke all on function public._jobs_alert_new() from public, anon, authenticated;

-- Given (status -> filled): the colleague it was given to. Closed (status -> closed): everyone who said available.
create or replace function public._jobs_alert_status()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare r text;
begin
  if new.status = 'filled' and old.status <> 'filled' and new.taken_by <> '' then
    perform public._alert_add(new.taken_by, 'job_given', new.id, '');
  elsif new.status = 'closed' and old.status <> 'closed' then
    for r in select distinct f.member from public.job_offers f where f.job_id = new.id and f.answer = 'yes' and f.member <> new.owner loop
      perform public._alert_add(r, 'job_closed', new.id, case when old.status = 'filled' and r = old.taken_by then 'taker' else '' end);
    end loop;
  end if;
  return null;
end $function$;
revoke all on function public._jobs_alert_status() from public, anon, authenticated;

-- "I'm available": the poster. 'about' is the colleague's member id, so a second colleague is a second alert.
create or replace function public._job_offers_alert()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare j public.jobs; aid text;
begin
  if new.answer = 'yes' and (tg_op = 'INSERT' or old.answer is distinct from 'yes') then
    select * into j from public.jobs where id = new.job_id;
    if j.id is not null and j.status = 'open' and j.owner <> new.member then
      select id::text into aid from public.members where email = new.member order by created_at limit 1;
      perform public._alert_add(j.owner, 'job_available', j.id, coalesce(aid, ''));
    end if;
  end if;
  return null;
end $function$;
revoke all on function public._job_offers_alert() from public, anon, authenticated;

-- Created only if missing (no DROP in this file). To change one later, replace its function; the trigger stays.
do $$ begin
  if not exists (select 1 from pg_trigger where tgname = 'jobs_alert_new' and tgrelid = 'public.jobs'::regclass) then
    create constraint trigger jobs_alert_new after update on public.jobs deferrable initially deferred
      for each row when (old.title = '' and new.title <> '') execute function public._jobs_alert_new();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'jobs_alert_status' and tgrelid = 'public.jobs'::regclass) then
    create trigger jobs_alert_status after update of status on public.jobs
      for each row when (old.status is distinct from new.status) execute function public._jobs_alert_status();
  end if;
  if not exists (select 1 from pg_trigger where tgname = 'job_offers_alert' and tgrelid = 'public.job_offers'::regclass) then
    create trigger job_offers_alert after insert or update of answer on public.job_offers
      for each row execute function public._job_offers_alert();
  end if;
end $$;

-- ===== RPCs (member token) =====
-- What this member has: alerts on or not, his email switch, how many phones, and the two WhatsApp settings.
-- group_link (the "Inner Circle – Jobs" group): only to approved licensed tour guides (full members) and Eretz Israel Tours.
-- admin_whatsapp (Eretz Israel Tours' business WhatsApp, digits): only to approved full members.
create or replace function public._alerts_json(m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object(
    'on', public._alerts_on(m),
    'email', m.alerts_email,
    'phones', (select count(*) from public.push_subs s where s.member = m.email and not s.dead),
    'group_link', case when m.status = 'approved' and not public._limited(m) and (m.is_admin or m.role = 'Licensed tour guide')
      then nullif(public._setting('jobs_group_link'), '') end,
    'admin_whatsapp', case when m.status = 'approved' and not public._limited(m) then nullif(public._setting('admin_whatsapp'), '') end,
    'alerts_for', case when m.is_admin then coalesce(nullif(public._setting('alerts_for'), ''), 'admin') end)
$function$;
revoke all on function public._alerts_json(public.members) from public, anon, authenticated;

create or replace function public.alerts_state(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return public._alerts_json(m);
end $function$;
revoke all on function public.alerts_state(text) from public; grant execute on function public.alerts_state(text) to anon, authenticated;

-- The email switch in My days.
create or replace function public.alerts_set(p_token text, p_email boolean)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  update public.members set alerts_email = coalesce(p_email, true) where id = m.id returning * into m;
  return public._alerts_json(m);
end $function$;
revoke all on function public.alerts_set(text,boolean) from public; grant execute on function public.alerts_set(text,boolean) to anon, authenticated;

-- This phone: the browser's push subscription ({endpoint, keys:{p256dh, auth}}). A phone moves to whoever signs in on it.
-- At most 10 phones a member; the oldest is switched off.
create or replace function public.push_subscribe(p_token text, p_sub jsonb, p_device text default '')
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; ep text := trim(coalesce(p_sub->>'endpoint','')); k1 text := coalesce(p_sub->'keys'->>'p256dh',''); k2 text := coalesce(p_sub->'keys'->>'auth','');
begin
  m := public._auth(p_token);
  if public._limited(m) then raise exception 'Job alerts are for colleagues with the Jobs tab.' using errcode = '42501'; end if;
  if ep !~ '^https://[^\s]+$' or length(ep) > 1000 or k1 !~ '^[A-Za-z0-9_=-]{60,120}$' or k2 !~ '^[A-Za-z0-9_=-]{10,40}$' then
    raise exception 'This phone sent something the app does not understand. Try again.'; end if;
  insert into public.push_subs (member, endpoint, p256dh, auth, device)
    values (m.email, ep, k1, k2, left(coalesce(p_device,''), 120))
    on conflict (endpoint) do update set member = excluded.member, p256dh = excluded.p256dh, auth = excluded.auth,
      device = excluded.device, dead = false, fails = 0, updated_at = now();
  update public.push_subs set dead = true, updated_at = now()
    where member = m.email and not dead and id not in (select s.id from public.push_subs s where s.member = m.email and not s.dead order by s.updated_at desc limit 10);
  return public._alerts_json(m);
end $function$;
revoke all on function public.push_subscribe(text,jsonb,text) from public; grant execute on function public.push_subscribe(text,jsonb,text) to anon, authenticated;

create or replace function public.push_unsubscribe(p_token text, p_endpoint text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  update public.push_subs set dead = true, updated_at = now() where member = m.email and endpoint = coalesce(p_endpoint,'');
  return public._alerts_json(m);
end $function$;
revoke all on function public.push_unsubscribe(text,text) from public; grant execute on function public.push_unsubscribe(text,text) to anon, authenticated;

-- The link in every email: no sign-in, the member's own random key. Says only whether it worked.
create or replace function public.alerts_unsubscribe(p_key text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare n int;
begin
  if coalesce(p_key,'') !~ '^[0-9a-f]{36}$' then return json_build_object('ok', false); end if;
  update public.members set alerts_email = false where alerts_key = p_key;
  get diagnostics n = row_count;
  return json_build_object('ok', n > 0);
end $function$;
revoke all on function public.alerts_unsubscribe(text) from public; grant execute on function public.alerts_unsubscribe(text) to anon, authenticated;

-- Eretz Israel Tours: which alerts a job queued, by name (never an email), and what became of each.
create or replace function public.job_alerts_list(p_token text, p_id uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token, true);
  return coalesce((select json_agg(json_build_object('name', coalesce((select case when x.is_admin then 'Eretz Israel Tours' else x.name end
        from public.members x where x.email = q.member order by x.created_at limit 1), 'A former member'),
      'event', q.event, 'channel', q.channel, 'status', q.status, 'error', q.error, 'created_at', q.created_at, 'sent_at', q.sent_at)
    order by q.event, q.created_at) from public.alert_queue q where q.job_id = p_id), '[]'::json);
end $function$;
revoke all on function public.job_alerts_list(text,uuid) from public; grant execute on function public.job_alerts_list(text,uuid) to anon, authenticated;

-- Eretz Israel Tours: a colleague's job, shared to the jobs WhatsApp group or not for the group. Recorded with who and when.
-- Only the WhatsApp group: the job reaches colleagues in the app and by alerts whatever is chosen here.
create or replace function public.job_group_mark(p_token text, p_id uuid, p_status text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs;
begin
  m := public._auth(p_token, true);
  if coalesce(p_status,'') not in ('shared','skipped') then raise exception 'Unknown answer.'; end if;
  update public.jobs set group_status = p_status, group_at = now(), group_by = m.email where id = p_id returning * into j;
  if j.id is null then raise exception 'That job is not there any more.'; end if;
  return public._job_json(j, m);
end $function$;
revoke all on function public.job_group_mark(text,uuid,text) from public; grant execute on function public.job_group_mark(text,uuid,text) to anon, authenticated;

-- ===== replaced: what a member sees of a job; as D-68, plus group_status and group_at for Eretz Israel Tours only =====
create or replace function public._job_json(j public.jobs, m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',j.id,'kind',j.kind,'title',j.title,'date_from',j.date_from,'date_to',j.date_to,'hours',j.hours,
    'start_place',j.start_place,'region',j.region,'pax',j.pax,'langs',j.langs,'needs',j.needs,
    'price',j.price,'currency',j.currency,'per',j.per,'vat',j.vat,'payment',j.payment,'note',j.note,'reply_by',j.reply_by,
    'days',j.days,
    'audience',j.audience,'status',j.status,'anon',j.anon,'mine',j.owner = m.email,
    'by', case when j.owner = m.email or m.is_admin or not j.anon or j.taken_by = m.email
      then (select json_build_object('name', case when o.is_admin then 'Eretz Israel Tours' else o.name end, 'role', o.role, 'admin', o.is_admin)
            from public.members o where o.email = j.owner order by o.created_at limit 1) end,
    'by_phone', case when j.taken_by = m.email and j.status = 'filled'
      then (select o.phone from public.members o where o.email = j.owner order by o.created_at limit 1) end,
    'my_answer', coalesce((select f.answer from public.job_offers f where f.job_id = j.id and f.member = m.email), ''),
    'my_day', public._day_state(m.email, j.date_from, j.date_to, true),
    'taken_me', j.taken_by <> '' and j.taken_by = m.email,
    'n_sent', case when j.owner = m.email or m.is_admin then (select count(*) from public.job_offers f where f.job_id = j.id and f.picked) end,
    'n_yes', case when j.owner = m.email or m.is_admin then (select count(*) from public.job_offers f where f.job_id = j.id and f.answer = 'yes') end,
    'n_no', case when j.owner = m.email or m.is_admin then (select count(*) from public.job_offers f where f.job_id = j.id and f.answer = 'no') end,
    'taker', case when (j.owner = m.email or m.is_admin) and j.taken_by <> ''
      then (select json_build_object('name', case when t.is_admin then 'Eretz Israel Tours' else t.name end, 'role', t.role, 'phone', t.phone)
            from public.members t where t.email = j.taken_by order by t.created_at limit 1) end,
    'group_status', case when m.is_admin then j.group_status end,
    'group_at', case when m.is_admin then j.group_at end,
    'filled_at',j.filled_at,'created_at',j.created_at,'updated_at',j.updated_at)
$function$;
revoke all on function public._job_json(public.jobs,public.members) from public, anon, authenticated;

-- ===== replaced: set_setting, with jobs_group_link, admin_whatsapp and alerts_for =====
-- jobs_group_link: https://chat.whatsapp.com/<code> or empty. Kept as typed (the code is case-sensitive). Never in the code.
-- admin_whatsapp: Eretz Israel Tours' business WhatsApp number, digits with the country code (e.g. 9725...), or empty.
-- alerts_for: 'admin' (only Eretz Israel Tours gets job alerts) or 'all'.
-- Every other key exactly as before.
create or replace function public.set_setting(p_token text, p_key text, p_value text)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare v text;
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email','bookings_for','jobs_for','hikes_for','rentals_for','wineries_for','forms_for','jobs_group_link','admin_whatsapp','alerts_for') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  if p_key = 'bookings_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'jobs_for' and lower(trim(p_value)) not in ('admin','receive','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'hikes_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'rentals_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'wineries_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'forms_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'alerts_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  v := case when p_key = 'jobs_group_link' then trim(coalesce(p_value,''))
            when p_key = 'admin_whatsapp' then regexp_replace(coalesce(p_value,''), '[\s+().-]', '', 'g')
            else lower(trim(p_value)) end;
  if p_key = 'jobs_group_link' and v <> '' and v !~ '^https://chat\.whatsapp\.com/[A-Za-z0-9]{10,40}$' then
    raise exception 'Paste the group''s invite link: https://chat.whatsapp.com/…'; end if;
  if p_key = 'admin_whatsapp' and v <> '' and v !~ '^[1-9][0-9]{7,14}$' then
    raise exception 'Enter the WhatsApp number with the country code, digits only, e.g. 9725…'; end if;
  insert into public.app_settings (key, value) values (p_key, v) on conflict (key) do update set value = excluded.value;
end $function$;

-- ===== for the Edge Function job-alerts only (service key) =====
-- Why a waiting row should not be sent any more, or null if it should.
create or replace function public._alert_why_not(q public.alert_queue)
 returns text language plpgsql stable security definer set search_path to ''
as $function$
declare m public.members; j public.jobs; d0 text := to_char(now() at time zone 'Asia/Jerusalem', 'YYYY-MM-DD');
begin
  if q.created_at < now() - interval '7 days' then return 'too old'; end if;
  select * into m from public.members where email = q.member and status = 'approved' order by created_at limit 1;
  if m.id is null then return 'member not active'; end if;
  if not public._alerts_on(m) then return 'alerts not open to this member'; end if;
  select * into j from public.jobs where id = q.job_id;
  if j.id is null then return 'job deleted'; end if;
  if q.channel = 'email' and not m.alerts_email then return 'email switched off'; end if;
  if q.channel = 'push' and not exists (select 1 from public.push_subs s where s.member = m.email and not s.dead) then return 'no phone'; end if;
  if q.event = 'job_new' then
    if j.status <> 'open' or coalesce(nullif(j.date_to,''), j.date_from) < d0 then return 'job no longer open'; end if;
    if public._day_state(m.email, j.date_from, j.date_to, true) = 'busy' then return 'busy on those days'; end if;
  elsif q.event = 'group_review' then
    if j.status <> 'open' or j.group_status <> '' then return 'already handled'; end if;
  elsif q.event = 'job_given' then
    if j.status <> 'filled' or j.taken_by <> m.email then return 'no longer given'; end if;
  elsif q.event = 'job_closed' then
    if j.status <> 'closed' then return 'reopened'; end if;
  elsif q.event = 'job_available' then
    if j.status <> 'open' or not exists (select 1 from public.job_offers f join public.members a on a.email = f.member
        where f.job_id = j.id and a.id::text = q.about and f.answer = 'yes') then return 'no longer available'; end if;
  end if;
  return null;
end $function$;
revoke all on function public._alert_why_not(public.alert_queue) from public, anon, authenticated;

-- The rows to send now (at most p_limit, only the channels the sender can send now), each with what the message needs. Rows that should not go any more are
-- marked skipped first. A row handed out is not handed out again for 10 minutes (claimed_at), so two runs never both
-- send it. The job goes without its owner, note or payment line: an alert never names the poster.
create or replace function public._alerts_due(p_limit integer default 50, p_channels text[] default array['push','email'])
 returns json language plpgsql security definer set search_path to ''
as $function$
declare ids uuid[]; out json;
begin
  update public.alert_queue q set status = 'skipped', sent_at = now(), error = w.why
    from (select x.id, public._alert_why_not(x) as why from public.alert_queue x where x.status = 'waiting') w
    where q.id = w.id and w.why is not null;
  select array_agg(id) into ids from (
    select id from public.alert_queue where status = 'waiting' and channel = any (coalesce(p_channels, array[]::text[]))
      and (claimed_at is null or claimed_at < now() - interval '10 minutes')
    order by created_at limit greatest(1, least(coalesce(p_limit, 50), 200)) for update skip locked) x;
  if ids is null then return '[]'::json; end if;
  update public.alert_queue set claimed_at = now() where id = any (ids);
  select json_agg(json_build_object('id', q.id, 'event', q.event, 'channel', q.channel, 'about', case when q.about = 'taker' then 'taker' else '' end,
      'to', q.member, 'key', m.alerts_key,
      'job', json_build_object('id', j.id, 'kind', j.kind, 'title', j.title, 'date_from', j.date_from, 'date_to', j.date_to, 'hours', j.hours,
        'region', j.region, 'start_place', j.start_place, 'pax', j.pax, 'langs', j.langs, 'needs', j.needs, 'price', j.price,
        'currency', j.currency, 'per', j.per, 'vat', j.vat, 'days', j.days),
      'subs', case when q.channel = 'push' then (select coalesce(json_agg(json_build_object('endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth)), '[]'::json)
        from public.push_subs s where s.member = q.member and not s.dead) end)
    order by q.created_at) into out
  from public.alert_queue q
  join lateral (select * from public.members mm where mm.email = q.member and mm.status = 'approved' order by mm.created_at limit 1) m on true
  join public.jobs j on j.id = q.job_id
  where q.id = any (ids);
  return coalesce(out, '[]'::json);
end $function$;
revoke all on function public._alerts_due(integer,text[]) from public, anon, authenticated;
grant execute on function public._alerts_due(integer,text[]) to service_role;

create or replace function public._alert_mark(p_id uuid, p_status text, p_error text default '')
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  -- 'waiting' = could not be sent this time (the service was busy): tried again on a later run, at most 6 times.
  if p_status = 'waiting' then
    update public.alert_queue set claimed_at = null, tries = tries + 1, error = left(coalesce(p_error,''), 500),
      status = case when tries + 1 >= 6 then 'failed' else 'waiting' end, sent_at = case when tries + 1 >= 6 then now() end
    where id = p_id and status = 'waiting';
  elsif p_status in ('sent','skipped','failed') then
    update public.alert_queue set status = p_status, sent_at = now(), error = left(coalesce(p_error,''), 500) where id = p_id and status = 'waiting';
  end if;
end $function$;
revoke all on function public._alert_mark(uuid,text,text) from public, anon, authenticated;
grant execute on function public._alert_mark(uuid,text,text) to service_role;

-- A phone answered (ok) or the push service said it is gone (404 / 410): then it is switched off for good.
create or replace function public._push_mark(p_endpoint text, p_ok boolean, p_gone boolean default false)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  if p_ok then
    update public.push_subs set last_ok_at = now(), fails = 0 where endpoint = p_endpoint;
  else
    update public.push_subs set fails = fails + 1, dead = dead or coalesce(p_gone, false) or fails + 1 >= 10, updated_at = now() where endpoint = p_endpoint;
  end if;
end $function$;
revoke all on function public._push_mark(text,boolean,boolean) from public, anon, authenticated;
grant execute on function public._push_mark(text,boolean,boolean) to service_role;


-- =====================================================================================================================
-- ===== Run by the go-live session, NOT part of this file's effect: the sender every 5 minutes =====
-- Everything below is commented out on purpose. Running this file sets nothing up. pg_net is installed on production
-- (schema extensions); pg_cron is available but not installed (read 31 Oct 2026). Vault is installed.
-- 1. Deploy the Edge Function job-alerts (verify_jwt = false; it checks its own secret) and set its secrets:
--    VAPID_PRIVATE_KEY, VAPID_PUBLIC_KEY, VAPID_SUBJECT, ALERTS_SECRET (RESEND_API_KEY is already set).
-- 2. Put the same ALERTS_SECRET in Vault and schedule the call:
--
-- create extension if not exists pg_cron;
-- select vault.create_secret('<the same ALERTS_SECRET>', 'job_alerts_secret', 'Shared secret for the job-alerts Edge Function');
-- select cron.schedule('job-alerts', '*/5 * * * *', $cron$
--   select net.http_post(
--     url := 'https://wjuqtjlrtcywjaspjpwu.supabase.co/functions/v1/job-alerts',
--     headers := jsonb_build_object('Content-Type', 'application/json',
--       'x-alerts-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'job_alerts_secret')),
--     body := '{}'::jsonb, timeout_milliseconds := 60000)
-- $cron$);
--
-- To stop it: select cron.unschedule('job-alerts');
-- =====================================================================================================================
