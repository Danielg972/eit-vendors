-- D-68 (31 Oct 2026): a job of more than one day gets its own line for each day. See docs/DECISIONS.md D-68.
-- Only adds and replaces: one new column on jobs, one new function, and _job_json replaced to send the column.
-- Nothing is deleted. No table grant or policy changes. Safe to run twice.
--
-- days = a list of {"d":"yyyy-mm-dd","text":"what that day is","hours":"08:00 to 17:00"}, one per day of the job.
-- It is written by job_set_days after job_save, by the poster or Eretz Israel Tours, while the job is open.
-- Every member the job is sent to sees it with the rest of the job. No names, phones or emails go in it.

alter table public.jobs add column if not exists days jsonb default '[]'::jsonb not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'jobs_days_check') then
    alter table public.jobs add constraint jobs_days_check check (jsonb_typeof(days) = 'array' and length(days::text) <= 30000);
  end if;
end $$;

-- What member m sees of a job: as before, plus 'days'.
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
    'filled_at',j.filled_at,'created_at',j.created_at,'updated_at',j.updated_at)
$function$;
revoke all on function public._job_json(public.jobs,public.members) from public, anon, authenticated;

-- The day-by-day lines of a job. Only days inside the job's dates are kept, in date order, one line per day.
-- An empty list (or a one-day job) clears them.
create or replace function public.job_set_days(p_token text, p_id uuid, p_days jsonb)
 returns json language plpgsql security definer set search_path to ''
as $function$
declare m public.members; j public.jobs; a date; b date; v jsonb;
begin
  m := public._auth(p_token);
  if not public._jobs_post(m) then raise exception 'Posting jobs is not open yet.' using errcode = '42501'; end if;
  select * into j from public.jobs where id = p_id and (owner = m.email or m.is_admin) for update;
  if j.id is null then raise exception 'Only the person who posted this job, or Eretz Israel Tours, can change it.'; end if;
  if j.status <> 'open' then raise exception 'This job is closed. Reopen it to change it.'; end if;
  a := public._to_date(j.date_from); b := coalesce(public._to_date(j.date_to), a);
  if a is null or b <= a or jsonb_typeof(p_days) <> 'array' then
    v := '[]'::jsonb;
  else
    select coalesce(jsonb_agg(jsonb_build_object('d', x.d, 'text', x.t, 'hours', x.h) order by x.d), '[]'::jsonb) into v
    from (select distinct on (to_char(public._to_date(e->>'d'), 'YYYY-MM-DD'))
            to_char(public._to_date(e->>'d'), 'YYYY-MM-DD') as d,
            left(trim(coalesce(e->>'text','')), 300) as t,
            left(trim(coalesce(e->>'hours','')), 40) as h
          from jsonb_array_elements(p_days) as u(e)
          where jsonb_typeof(e) = 'object' and public._to_date(e->>'d') between a and b
          order by to_char(public._to_date(e->>'d'), 'YYYY-MM-DD')) x
    where x.t <> '' or x.h <> '';
  end if;
  update public.jobs set days = v, updated_at = now() where id = p_id returning * into j;
  return public._job_json(j, m);
end $function$;
revoke all on function public.job_set_days(text,uuid,jsonb) from public; grant execute on function public.job_set_days(text,uuid,jsonb) to anon, authenticated;
