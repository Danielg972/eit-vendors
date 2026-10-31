-- D-69 go-live (31 Oct 2026): the keys for job alerts live in the database's Vault, made where they are used and never
-- typed in or seen by anyone. Run after 2026-10-31b_job_alerts.sql. Only adds and replaces. Safe to run twice.
--   job_alerts_secret          made here, at random. pg_cron sends it to the Edge Function job-alerts; the function
--                              reads the same value through _alerts_config and refuses any call without it.
--   job_alerts_vapid_public /  the key pair for phone notifications, made by the Edge Function on its first run
--   job_alerts_vapid_private   (web-push generateVAPIDKeys) and stored through _alerts_set_vapid, once.
-- The public key goes to approved full members through alerts_state (vapid_public), for the phone to subscribe.
-- _alerts_config and _alerts_set_vapid are for the service key only.

do $$ begin
  if not exists (select 1 from vault.secrets where name = 'job_alerts_secret') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(24), 'hex'), 'job_alerts_secret', 'D-69: shared secret between pg_cron and the job-alerts Edge Function');
  end if;
end $$;

create or replace function public._alerts_config()
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object(
    'secret', (select decrypted_secret from vault.decrypted_secrets where name = 'job_alerts_secret' limit 1),
    'vapid_public', (select decrypted_secret from vault.decrypted_secrets where name = 'job_alerts_vapid_public' limit 1),
    'vapid_private', (select decrypted_secret from vault.decrypted_secrets where name = 'job_alerts_vapid_private' limit 1))
$function$;
revoke all on function public._alerts_config() from public, anon, authenticated;
grant execute on function public._alerts_config() to service_role;

-- Stores the key pair once. A second call (two runs at the same moment) changes nothing and returns false.
create or replace function public._alerts_set_vapid(p_public text, p_private text)
 returns boolean language plpgsql security definer set search_path to ''
as $function$
begin
  if exists (select 1 from vault.secrets where name in ('job_alerts_vapid_public', 'job_alerts_vapid_private')) then return false; end if;
  if coalesce(p_public,'') !~ '^[A-Za-z0-9_-]{80,100}$' or coalesce(p_private,'') !~ '^[A-Za-z0-9_-]{40,50}$' then
    raise exception 'Not a VAPID key pair.'; end if;
  perform vault.create_secret(p_public, 'job_alerts_vapid_public', 'D-69: public key for phone notifications');
  perform vault.create_secret(p_private, 'job_alerts_vapid_private', 'D-69: private key for phone notifications');
  return true;
end $function$;
revoke all on function public._alerts_set_vapid(text,text) from public, anon, authenticated;
grant execute on function public._alerts_set_vapid(text,text) to service_role;

-- As in 2026-10-31b, plus vapid_public (a public key, needed by the phone) for approved full members.
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
    'alerts_for', case when m.is_admin then coalesce(nullif(public._setting('alerts_for'), ''), 'admin') end,
    'vapid_public', case when m.status = 'approved' and not public._limited(m)
      then (select decrypted_secret from vault.decrypted_secrets where name = 'job_alerts_vapid_public' limit 1) end)
$function$;
revoke all on function public._alerts_json(public.members) from public, anon, authenticated;

-- ===== Run by the go-live session after the Edge Function is deployed: the sender every 5 minutes =====
-- create extension if not exists pg_cron;
-- select cron.schedule('job-alerts', '*/5 * * * *', $cron$
--   select net.http_post(
--     url := 'https://wjuqtjlrtcywjaspjpwu.supabase.co/functions/v1/job-alerts',
--     headers := jsonb_build_object('Content-Type', 'application/json',
--       'x-alerts-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'job_alerts_secret')),
--     body := '{}'::jsonb, timeout_milliseconds := 60000)
-- $cron$);
-- To stop it: select cron.unschedule('job-alerts');
