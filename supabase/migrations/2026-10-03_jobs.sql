-- Jobs between colleagues, and My days (3 Oct 2026). See docs/DECISIONS.md D-11. Run after 2026-10-02f_hours_verify.sql.
-- Paste the whole file into the Supabase SQL editor for project wjuqtjlrtcywjaspjpwu and run it once.
-- supabase/schema.sql already includes everything below; this file is the step-by-step change. Safe to run twice.
--
-- A member posts a job (who is needed, the date, the price he pays). It goes to every colleague who fits, or to the
-- ones he picks. A colleague answers "I'm available" or "Not for me"; the poster gives the job to one of them.
-- Nothing is charged: the price on the job is what the colleague is paid, directly by the poster.
-- My days: each member marks the days he is busy. A poster sees only Free / Busy / Not marked for the dates of his job.
--
-- Until Eretz Israel Tours changes the setting jobs_for, only Eretz Israel Tours sees any of it:
--   'admin'   = Eretz Israel Tours only (the default)
--   'receive' = colleagues see the Jobs tab, answer jobs and mark their days; only Eretz Israel Tours posts
--   'all'     = every member can post

-- ===== members: the jobs a member takes, and his days =====
alter table public.members
  add column if not exists job_kinds text default ''::text not null,
  add column if not exists job_tags text default ''::text not null,
  add column if not exists job_langs text default ''::text not null,
  add column if not exists days_weekly text default ''::text not null,
  add column if not exists days_shared boolean default true not null,
  add column if not exists days_updated_at timestamp with time zone;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'members_jobs_check') then
    alter table public.members add constraint members_jobs_check check (length(job_kinds) <= 80 and length(job_tags) <= 80 and length(job_langs) <= 200 and days_weekly ~ '^([0-6](,[0-6]){0,6})?$'::text);
  end if;
end $$;

-- ===== tables =====
create table if not exists public.jobs (
  id uuid default gen_random_uuid() not null,
  owner text not null,
  owner_name text default ''::text not null,
  anon boolean default true not null,
  kind text default 'guide'::text not null,
  title text default ''::text not null,
  date_from text default ''::text not null,
  date_to text default ''::text not null,
  hours text default ''::text not null,
  start_place text default ''::text not null,
  region text default ''::text not null,
  pax text default ''::text not null,
  langs text default ''::text not null,
  needs text default ''::text not null,
  price text default ''::text not null,
  currency text default 'ILS'::text not null,
  per text default 'day'::text not null,
  vat text default ''::text not null,
  payment text default ''::text not null,
  note text default ''::text not null,
  reply_by text default ''::text not null,
  audience text default 'all'::text not null,
  status text default 'open'::text not null,
  taken_by text default ''::text not null,
  filled_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  constraint jobs_pkey primary key (id),
  constraint jobs_kind_check check (kind = any (array['guide'::text, 'guide_vehicle'::text, 'van_driver'::text, 'jeep_driver'::text, 'other'::text])),
  constraint jobs_status_check check (status = any (array['open'::text, 'filled'::text, 'closed'::text])),
  constraint jobs_audience_check check (audience = any (array['all'::text, 'picked'::text])),
  constraint jobs_per_check check (per = any (array['day'::text, 'job'::text, 'hour'::text, 'vehicle'::text])),
  constraint jobs_vat_check check (vat = any (array[''::text, 'including_vat'::text, 'plus_vat'::text, 'not_applicable'::text])),
  constraint jobs_currency_check check (currency = any (array['ILS'::text, 'USD'::text, 'EUR'::text])),
  constraint jobs_dates_check check ((date_from = ''::text or date_from ~ '^\d{4}-\d{2}-\d{2}$'::text) and (date_to = ''::text or date_to ~ '^\d{4}-\d{2}-\d{2}$'::text) and (reply_by = ''::text or reply_by ~ '^\d{4}-\d{2}-\d{2}$'::text)),
  constraint jobs_price_check check (price = ''::text or price ~ '^\d{1,7}(\.\d{1,2})?$'::text),
  constraint jobs_lengths_check check (length(title) <= 120 and length(hours) <= 40 and length(start_place) <= 160 and length(region) <= 60 and length(pax) <= 80
    and length(langs) <= 120 and length(needs) <= 80 and length(payment) <= 200 and length(note) <= 1500)
);
alter table public.jobs enable row level security;
create index if not exists jobs_owner_idx on public.jobs using btree (owner);
create index if not exists jobs_status_idx on public.jobs using btree (status, date_from);
create index if not exists jobs_taken_idx on public.jobs using btree (taken_by);

-- One row per colleague a job was sent to (picked) or who answered it.
create table if not exists public.job_offers (
  job_id uuid not null,
  member text not null,
  picked boolean default false not null,
  answer text default ''::text not null,
  answered_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  constraint job_offers_pkey primary key (job_id, member),
  constraint job_offers_job_id_fkey foreign key (job_id) references public.jobs(id) on delete cascade,
  constraint job_offers_answer_check check (answer = any (array[''::text, 'yes'::text, 'no'::text]))
);
alter table public.job_offers enable row level security;
create index if not exists job_offers_member_idx on public.job_offers using btree (member);

-- A member's busy days. source 'tap' = he marked it; 'job' = filled in when he was given a job here.
create table if not exists public.member_days (
  member text not null,
  day date not null,
  source text default 'tap'::text not null,
  job_id uuid,
  created_at timestamp with time zone default now() not null,
  constraint member_days_pkey primary key (member, day),
  constraint member_days_job_id_fkey foreign key (job_id) references public.jobs(id) on delete cascade,
  constraint member_days_source_check check (source = any (array['tap'::text, 'job'::text]))
);
alter table public.member_days enable row level security;
create index if not exists member_days_job_idx on public.member_days using btree (job_id);

revoke all on table public.jobs, public.job_offers, public.member_days from public, anon, authenticated;
grant all on table public.jobs, public.job_offers, public.member_days to service_role;

-- ===== internal helpers (not RPCs) =====
-- Who may see the Jobs tab, and who may post.
create or replace function public._jobs_on(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select m.is_admin or coalesce((select value from public.app_settings where key = 'jobs_for'), '') in ('receive','all')
$function$;
revoke all on function public._jobs_on(public.members) from public, anon, authenticated;

create or replace function public._jobs_post(m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select m.is_admin or coalesce((select value from public.app_settings where key = 'jobs_for'), '') = 'all'
$function$;
revoke all on function public._jobs_post(public.members) from public, anon, authenticated;

-- A comma list cut down to known keys, in the order of p_allowed.
create or replace function public._csv_keys(p text, p_allowed text[])
 returns text language sql immutable set search_path to ''
as $function$
  select coalesce(string_agg(a, ',' order by i), '')
  from unnest(p_allowed) with ordinality as t(a, i)
  where a in (select lower(trim(x)) from unnest(string_to_array(coalesce(p,''), ',')) as u(x))
$function$;
revoke all on function public._csv_keys(text,text[]) from public, anon, authenticated;

-- 'yyyy-mm-dd' to a date; null when it is not a real date.
create or replace function public._to_date(p text)
 returns date language plpgsql immutable set search_path to ''
as $function$
begin
  if coalesce(p,'') !~ '^\d{4}-\d{2}-\d{2}$' then return null; end if;
  return p::date;
exception when others then return null;
end $function$;
revoke all on function public._to_date(text) from public, anon, authenticated;

-- Does a job of this kind, with these must-haves, fit this member?
-- A member who has not said what jobs he takes is offered everything; 'none' means he takes no jobs.
create or replace function public._job_fits(p_kind text, p_needs text, m public.members)
 returns boolean language sql stable set search_path to ''
as $function$
  select m.job_kinds <> 'none'
    and (m.job_kinds = '' or p_kind = any (string_to_array(m.job_kinds, ',')))
    and (m.job_kinds = '' or coalesce(p_needs,'') = ''
      or string_to_array(p_needs, ',') <@ string_to_array(m.job_tags || case when m.role = 'Licensed tour guide' then ',licensed' else '' end, ','))
$function$;
revoke all on function public._job_fits(text,text,public.members) from public, anon, authenticated;

-- Was this job sent to this member?
create or replace function public._job_offered(j public.jobs, m public.members)
 returns boolean language sql stable security definer set search_path to ''
as $function$
  select case when j.audience = 'picked'
    then exists (select 1 from public.job_offers f where f.job_id = j.id and f.member = m.email and f.picked)
    else public._job_fits(j.kind, j.needs, m) end
$function$;
revoke all on function public._job_offered(public.jobs,public.members) from public, anon, authenticated;

-- Free / busy for a range of days. Others get 'hidden' when the member switched sharing off.
-- 'unmarked' = he has never touched My days, so "free" would be a guess.
create or replace function public._day_state(p_email text, p_from text, p_to text, p_self boolean)
 returns text language plpgsql stable security definer set search_path to ''
as $function$
declare m public.members; a date; b date;
begin
  select * into m from public.members where email = p_email order by created_at limit 1;
  if m.id is null then return 'unknown'; end if;
  if not p_self and not m.days_shared then return 'hidden'; end if;
  a := public._to_date(p_from); if a is null then return 'unknown'; end if;
  b := coalesce(public._to_date(p_to), a);
  if b < a then b := a; end if;
  if b > a + 60 then b := a + 60; end if;
  if exists (select 1 from public.member_days d where d.member = m.email and d.day between a and b) then return 'busy'; end if;
  if m.days_weekly <> '' and exists (select 1 from generate_series(a::timestamp, b::timestamp, interval '1 day') g
      where extract(dow from g)::int::text = any (string_to_array(m.days_weekly, ','))) then return 'busy'; end if;
  if m.days_updated_at is null then return 'unmarked'; end if;
  return 'free';
end $function$;
revoke all on function public._day_state(text,text,text,boolean) from public, anon, authenticated;

-- What member m sees of a job. The poster's name shows only to the poster, to Eretz Israel Tours, on a job posted
-- with a name, and to the colleague who was given the job. A phone number passes only between the poster and the
-- colleague he gave the job to. Never an email.
create or replace function public._job_json(j public.jobs, m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object('id',j.id,'kind',j.kind,'title',j.title,'date_from',j.date_from,'date_to',j.date_to,'hours',j.hours,
    'start_place',j.start_place,'region',j.region,'pax',j.pax,'langs',j.langs,'needs',j.needs,
    'price',j.price,'currency',j.currency,'per',j.per,'vat',j.vat,'payment',j.payment,'note',j.note,'reply_by',j.reply_by,
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
    'filled_at',j.filled_at,'created_at',j.created_at,'updated_at',j.updated_at)
$function$;
revoke all on function public._job_json(public.jobs,public.members) from public, anon, authenticated;

-- A member's own days and what jobs he takes.
create or replace function public._my_days_json(m public.members)
 returns json language sql stable security definer set search_path to ''
as $function$
  select json_build_object(
    'days', coalesce((select json_agg(json_build_object('d', to_char(d.day, 'YYYY-MM-DD'), 'src', d.source,
        'job', (select jj.title from public.jobs jj where jj.id = d.job_id)) order by d.day)
      from public.member_days d where d.member = m.email and d.day >= current_date - 31), '[]'::json),
    'weekly', m.days_weekly, 'shared', m.days_shared, 'updated_at', m.days_updated_at,
    'kinds', m.job_kinds, 'tags', m.job_tags, 'langs', m.job_langs)
$function$;
revoke all on function public._my_days_json(public.members) from public, anon, authenticated;

-- ===== RPCs (member token) =====
-- open: jobs sent to me that are still open. mine: jobs I posted. taken: jobs given to me.
-- all: for Eretz Israel Tours only, every colleague's job from the last 90 days, with who posted it.
create or replace function public.jobs_list(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; d0 text := to_char(now() at time zone 'Asia/Jerusalem', 'YYYY-MM-DD');
begin
  m := public._auth(p_token);
  if not public._jobs_on(m) then return json_build_object('open','[]'::json,'mine','[]'::json,'taken','[]'::json,'all','[]'::json,'me',public._my_days_json(m)); end if;
  return json_build_object(
    'open', coalesce((select json_agg(public._job_json(j, m) order by j.date_from, j.created_at) from public.jobs j
      where j.status = 'open' and j.owner <> m.email and coalesce(nullif(j.date_to,''), j.date_from) >= d0 and (j.reply_by = '' or j.reply_by >= d0)
        and (m.is_admin or public._job_offered(j, m))), '[]'::json),
    'mine', coalesce((select json_agg(public._job_json(j, m) order by (j.status <> 'open'), j.date_from desc, j.created_at desc) from public.jobs j
      where j.owner = m.email), '[]'::json),
    'taken', coalesce((select json_agg(public._job_json(j, m) order by j.date_from desc) from public.jobs j
      where j.taken_by = m.email and j.status in ('filled','closed')), '[]'::json),
    'all', case when m.is_admin then coalesce((select json_agg(public._job_json(j, m) order by j.created_at desc) from public.jobs j
      where j.owner <> m.email and j.created_at > now() - interval '90 days'), '[]'::json) else '[]'::json end,
    'me', public._my_days_json(m));
end $function$;
revoke all on function public.jobs_list(text) from public; grant execute on function public.jobs_list(text) to anon, authenticated;

-- Post or change a job. p_to = the member ids it goes to when audience is 'picked'.
create or replace function public.job_save(p_token text, p_job jsonb, p_to jsonb default '[]'::jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; jid uuid := nullif(p_job->>'id','')::uuid; j public.jobs; a date; b date; aud text; ids uuid[];
begin
  m := public._auth(p_token);
  if not public._jobs_post(m) then raise exception 'Posting jobs is not open yet.' using errcode = '42501'; end if;
  if length(trim(coalesce(p_job->>'title',''))) < 3 then raise exception 'Say what the job is, in a few words.'; end if;
  if coalesce(p_job->>'kind','') not in ('guide','guide_vehicle','van_driver','jeep_driver','other') then raise exception 'Choose who you need.'; end if;
  a := public._to_date(p_job->>'date_from');
  if a is null then raise exception 'Add the date of the job.'; end if;
  b := coalesce(public._to_date(p_job->>'date_to'), a);
  if b < a then raise exception 'The last day is before the first day.'; end if;
  if b > a + 60 then raise exception 'A job can run 60 days at most.'; end if;
  if coalesce(p_job->>'price','') !~ '^\d{1,7}(\.\d{1,2})?$' then raise exception 'Add the price you pay, as a number.'; end if;
  aud := case when p_job->>'audience' = 'picked' then 'picked' else 'all' end;
  if aud = 'picked' then
    select array_agg(mm.id) into ids from public.members mm
      where mm.status = 'approved' and mm.email <> m.email
        and mm.id::text in (select jsonb_array_elements_text(case when jsonb_typeof(p_to) = 'array' then p_to else '[]'::jsonb end));
    if ids is null then raise exception 'Choose at least one person.'; end if;
  end if;
  if jid is not null then
    select * into j from public.jobs where id = jid and (owner = m.email or m.is_admin);
    if j.id is null then raise exception 'Only the person who posted this job, or Eretz Israel Tours, can change it.'; end if;
    if j.status <> 'open' then raise exception 'This job is closed. Reopen it to change it.'; end if;
  else
    if (select count(*) from public.jobs where owner = m.email and created_at > now() - interval '1 day') >= 30 then
      raise exception 'Too many jobs in one day. Try again tomorrow.'; end if;
    insert into public.jobs (owner, owner_name) values (m.email, m.name) returning id into jid;
  end if;
  update public.jobs set
    anon = coalesce(p_job->>'anon','true') not in ('false','f'),
    kind = p_job->>'kind',
    title = left(trim(p_job->>'title'),120),
    date_from = to_char(a, 'YYYY-MM-DD'),
    date_to = case when b > a then to_char(b, 'YYYY-MM-DD') else '' end,
    hours = left(trim(coalesce(p_job->>'hours','')),40),
    start_place = left(trim(coalesce(p_job->>'start_place','')),160),
    region = left(trim(coalesce(p_job->>'region','')),60),
    pax = left(trim(coalesce(p_job->>'pax','')),80),
    langs = left(trim(coalesce(p_job->>'langs','')),120),
    needs = public._csv_keys(p_job->>'needs', array['licensed','eshkol','midbari','gun','shabbat']),
    price = p_job->>'price',
    currency = case when p_job->>'currency' in ('USD','EUR') then p_job->>'currency' else 'ILS' end,
    per = case when p_job->>'per' in ('job','hour','vehicle') then p_job->>'per' else 'day' end,
    vat = case when p_job->>'vat' in ('including_vat','plus_vat','not_applicable') then p_job->>'vat' else '' end,
    payment = left(trim(coalesce(p_job->>'payment','')),200),
    note = left(trim(coalesce(p_job->>'note','')),1500),
    reply_by = coalesce(to_char(public._to_date(p_job->>'reply_by'), 'YYYY-MM-DD'), ''),
    audience = aud, updated_at = now()
  where id = jid returning * into j;
  -- who it goes to: rows nobody answered are rebuilt; an answer already given is kept
  delete from public.job_offers where job_id = jid and answer = '';
  update public.job_offers set picked = false where job_id = jid;
  if aud = 'picked' then
    insert into public.job_offers (job_id, member, picked) select jid, mm.email, true from public.members mm where mm.id = any (ids)
      on conflict (job_id, member) do update set picked = true;
  end if;
  return public._job_json(j, m);
end $function$;
revoke all on function public.job_save(text,jsonb,jsonb) from public; grant execute on function public.job_save(text,jsonb,jsonb) to anon, authenticated;

-- Before posting: the colleagues this job fits, with Free / Busy / Not marked for its dates. Names and roles only.
create or replace function public.job_candidates(p_token text, p_job jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; k text := coalesce(p_job->>'kind','');
  n text := public._csv_keys(p_job->>'needs', array['licensed','eshkol','midbari','gun','shabbat']);
  df text := coalesce(p_job->>'date_from',''); dt text := coalesce(p_job->>'date_to','');
begin
  m := public._auth(p_token);
  if not public._jobs_post(m) then raise exception 'Posting jobs is not open yet.' using errcode = '42501'; end if;
  return coalesce((select json_agg(json_build_object('id',c.id,'name',case when c.is_admin then 'Eretz Israel Tours' else c.name end,
      'role',c.role,'langs',c.job_langs,'tags',c.job_tags,'profile',c.job_kinds <> '',
      'day',public._day_state(c.email, df, dt, false),
      'days_age',case when c.days_shared and c.days_updated_at is not null then floor(extract(epoch from now() - c.days_updated_at) / 86400)::int end)
    order by array_position(array['free','unmarked','hidden','unknown','busy'], public._day_state(c.email, df, dt, false)), lower(c.name))
    from public.members c where c.status = 'approved' and c.email <> m.email and public._job_fits(k, n, c)), '[]'::json);
end $function$;
revoke all on function public.job_candidates(text,jsonb) from public; grant execute on function public.job_candidates(text,jsonb) to anon, authenticated;

-- A colleague answers a job sent to him: 'yes' (I'm available), 'no' (not for me), '' (take it back).
-- p_busy with 'no' also marks the job's days busy in My days.
create or replace function public.job_answer(p_token text, p_id uuid, p_answer text, p_busy boolean default false)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs; a date; b date;
begin
  m := public._auth(p_token);
  if not public._jobs_on(m) then raise exception 'Jobs are not open yet.' using errcode = '42501'; end if;
  if coalesce(p_answer,'') not in ('yes','no','') then raise exception 'Unknown answer.'; end if;
  select * into j from public.jobs where id = p_id for update;
  if j.id is null or j.owner = m.email or not (m.is_admin or public._job_offered(j, m)) then raise exception 'This job was not sent to you.'; end if;
  if j.status <> 'open' then raise exception 'This job is no longer open.'; end if;
  insert into public.job_offers (job_id, member, answer, answered_at)
    values (p_id, m.email, coalesce(p_answer,''), case when coalesce(p_answer,'') = '' then null else now() end)
    on conflict (job_id, member) do update set answer = excluded.answer, answered_at = excluded.answered_at;
  if p_answer = 'no' and coalesce(p_busy, false) then
    a := public._to_date(j.date_from); b := coalesce(public._to_date(j.date_to), a);
    if a is not null then
      insert into public.member_days (member, day) select m.email, g::date from generate_series(a::timestamp, b::timestamp, interval '1 day') g
        on conflict (member, day) do nothing;
      update public.members set days_updated_at = now() where id = m.id returning * into m;
    end if;
  end if;
  return public._job_json(j, m);
end $function$;
revoke all on function public.job_answer(text,uuid,text,boolean) from public; grant execute on function public.job_answer(text,uuid,text,boolean) to anon, authenticated;

-- For the poster (or Eretz Israel Tours): who the job went to and who said he is available. Names and roles only.
create or replace function public.job_replies(p_token text, p_id uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs;
begin
  m := public._auth(p_token);
  select * into j from public.jobs where id = p_id and (owner = m.email or m.is_admin);
  if j.id is null then raise exception 'Only the person who posted this job, or Eretz Israel Tours, can see the answers.'; end if;
  return coalesce((select json_agg(json_build_object('id',c.id,'name',case when c.is_admin then 'Eretz Israel Tours' else c.name end,
      'role',c.role,'langs',c.job_langs,'tags',c.job_tags,'picked',f.picked,'answer',f.answer,'answered_at',f.answered_at,
      'day',public._day_state(c.email, j.date_from, j.date_to, false))
    order by (f.answer = 'yes') desc, f.answered_at nulls last, lower(c.name))
    from public.job_offers f join public.members c on c.email = f.member and c.status = 'approved'
    where f.job_id = j.id and (f.picked or f.answer = 'yes')), '[]'::json);
end $function$;
revoke all on function public.job_replies(text,uuid) from public; grant execute on function public.job_replies(text,uuid) to anon, authenticated;

-- The poster gives the job to one colleague who said he is available. From here the two see each other's name and
-- phone, the job's days go into that colleague's My days, and everyone else sees the job is no longer open.
create or replace function public.job_give(p_token text, p_id uuid, p_member uuid)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs; t public.members; a date; b date;
begin
  m := public._auth(p_token);
  select * into j from public.jobs where id = p_id and (owner = m.email or m.is_admin) for update;
  if j.id is null then raise exception 'Only the person who posted this job, or Eretz Israel Tours, can give it.'; end if;
  if j.status <> 'open' then raise exception 'This job is no longer open.'; end if;
  select * into t from public.members where id = p_member and status = 'approved';
  if t.id is null or not exists (select 1 from public.job_offers f where f.job_id = p_id and f.member = t.email and f.answer = 'yes') then
    raise exception 'That person has not said they are available.'; end if;
  update public.jobs set taken_by = t.email, status = 'filled', filled_at = now(), updated_at = now() where id = p_id returning * into j;
  a := public._to_date(j.date_from); b := coalesce(public._to_date(j.date_to), a);
  if a is not null then
    insert into public.member_days (member, day, source, job_id) select t.email, g::date, 'job', p_id from generate_series(a::timestamp, b::timestamp, interval '1 day') g
      on conflict (member, day) do nothing;
  end if;
  return public._job_json(j, m);
end $function$;
revoke all on function public.job_give(text,uuid,uuid) from public; grant execute on function public.job_give(text,uuid,uuid) to anon, authenticated;

-- closed: the job is withdrawn (a colleague who had it gets his days back). open: reopen it for answers.
create or replace function public.job_set_status(p_token text, p_id uuid, p_status text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs;
begin
  m := public._auth(p_token);
  select * into j from public.jobs where id = p_id and (owner = m.email or m.is_admin);
  if j.id is null then raise exception 'Only the person who posted this job, or Eretz Israel Tours, can change it.'; end if;
  if p_status = 'closed' then
    delete from public.member_days where job_id = p_id and source = 'job';
    update public.jobs set status = 'closed', updated_at = now() where id = p_id returning * into j;
  elsif p_status = 'open' then
    delete from public.member_days where job_id = p_id and source = 'job';
    update public.jobs set status = 'open', taken_by = '', filled_at = null, updated_at = now() where id = p_id returning * into j;
  else
    raise exception 'Unknown status.';
  end if;
  return public._job_json(j, m);
end $function$;
revoke all on function public.job_set_status(text,uuid,text) from public; grant execute on function public.job_set_status(text,uuid,text) to anon, authenticated;

create or replace function public.job_delete(p_token text, p_id uuid)
 returns void language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  delete from public.jobs where id = p_id and (owner = m.email or m.is_admin);
end $function$;
revoke all on function public.job_delete(text,uuid) from public; grant execute on function public.job_delete(text,uuid) to anon, authenticated;

-- My days: read.
create or replace function public.my_days(p_token text)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  return public._my_days_json(m);
end $function$;
revoke all on function public.my_days(text) from public; grant execute on function public.my_days(text) to anon, authenticated;

-- My days: mark days busy (p_busy) or free again (p_free). Arrays of 'yyyy-mm-dd'.
create or replace function public.my_days_set(p_token text, p_busy jsonb default '[]'::jsonb, p_free jsonb default '[]'::jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if not public._jobs_on(m) then raise exception 'Jobs are not open yet.' using errcode = '42501'; end if;
  if jsonb_typeof(p_busy) = 'array' then
    if jsonb_array_length(p_busy) > 400 then raise exception 'Too many days at once.'; end if;
    insert into public.member_days (member, day)
      select distinct m.email, public._to_date(x) from jsonb_array_elements_text(p_busy) as u(x)
      where public._to_date(x) between current_date - 31 and current_date + 800
      on conflict (member, day) do nothing;
  end if;
  if jsonb_typeof(p_free) = 'array' then
    if jsonb_array_length(p_free) > 400 then raise exception 'Too many days at once.'; end if;
    delete from public.member_days where member = m.email and day in (select public._to_date(x) from jsonb_array_elements_text(p_free) as u(x));
  end if;
  update public.members set days_updated_at = now() where id = m.id returning * into m;
  return public._my_days_json(m);
end $function$;
revoke all on function public.my_days_set(text,jsonb,jsonb) from public; grant execute on function public.my_days_set(text,jsonb,jsonb) to anon, authenticated;

-- My days: weekdays that are always busy, whether colleagues see free/busy, the jobs I take, and "still right".
create or replace function public.my_days_prefs(p_token text, p_prefs jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members;
begin
  m := public._auth(p_token);
  if not public._jobs_on(m) then raise exception 'Jobs are not open yet.' using errcode = '42501'; end if;
  update public.members set
    days_weekly = case when p_prefs ? 'weekly' then public._csv_keys(p_prefs->>'weekly', array['0','1','2','3','4','5','6']) else days_weekly end,
    days_shared = case when p_prefs ? 'shared' then coalesce(p_prefs->>'shared','true') not in ('false','f') else days_shared end,
    job_kinds = case when p_prefs ? 'kinds' then
        case when lower(trim(coalesce(p_prefs->>'kinds',''))) = 'none' then 'none'
             else public._csv_keys(p_prefs->>'kinds', array['guide','guide_vehicle','van_driver','jeep_driver','other']) end
      else job_kinds end,
    job_tags = case when p_prefs ? 'tags' then public._csv_keys(p_prefs->>'tags', array['licensed','eshkol','midbari','gun','shabbat']) else job_tags end,
    job_langs = case when p_prefs ? 'langs' then left(trim(coalesce(p_prefs->>'langs','')),200) else job_langs end,
    days_updated_at = case when p_prefs ? 'weekly' or coalesce(p_prefs->>'confirm','') = 'true' then now() else days_updated_at end
  where id = m.id returning * into m;
  return public._my_days_json(m);
end $function$;
revoke all on function public.my_days_prefs(text,jsonb) from public; grant execute on function public.my_days_prefs(text,jsonb) to anon, authenticated;

-- whoami: also whether the Jobs tab is open to this member (jobs), whether he may post (jobs_post), and, for
-- Eretz Israel Tours, the setting itself (jobs_for).
create or replace function public.whoami(p_token text)
 returns json language sql security definer set search_path to ''
as $function$
  select json_build_object('name',name,'email',email,'status',status,'is_admin',is_admin,'role',role,'has_proof',proof_path is not null,'terms_version',terms_version,
    'reminder_due', (not is_admin) and (reminder_seen_at is null or reminder_seen_at < now() - interval '30 days'),
    'bcc_email', case when status = 'approved' then (select value from public.app_settings where key = 'bcc_email') else '' end,
    'bcc_opt_out', bcc_opt_out, 'bcc_ack', bcc_ack,
    'phone', phone,
    'bookings', status = 'approved' and (is_admin or coalesce((select value from public.app_settings where key = 'bookings_for'),'') = 'all'),
    'bookings_for', case when is_admin then coalesce((select value from public.app_settings where key = 'bookings_for'),'admin') else '' end,
    'jobs', status = 'approved' and (is_admin or coalesce((select value from public.app_settings where key = 'jobs_for'),'') in ('receive','all')),
    'jobs_post', status = 'approved' and (is_admin or coalesce((select value from public.app_settings where key = 'jobs_for'),'') = 'all'),
    'jobs_for', case when is_admin then coalesce((select value from public.app_settings where key = 'jobs_for'),'admin') else '' end)
  from public.members where token_hash = public._hash(p_token);
$function$;

-- set_setting: also jobs_for ('admin', 'receive' or 'all'; see the top of this file).
create or replace function public.set_setting(p_token text, p_key text, p_value text)
 returns void language plpgsql security definer set search_path to ''
as $function$
begin
  perform public._auth(p_token, true);
  if p_key not in ('bcc_email','bookings_for','jobs_for') then raise exception 'Unknown setting'; end if;
  if p_key = 'bcc_email' and p_value <> '' and p_value !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Enter a full email address.'; end if;
  if p_key = 'bookings_for' and lower(trim(p_value)) not in ('admin','all') then raise exception 'Unknown setting'; end if;
  if p_key = 'jobs_for' and lower(trim(p_value)) not in ('admin','receive','all') then raise exception 'Unknown setting'; end if;
  insert into public.app_settings (key, value) values (p_key, lower(trim(p_value))) on conflict (key) do update set value = excluded.value;
end $function$;
