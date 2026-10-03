-- Jobs between colleagues, and My days (3 Oct 2026, D-11): the last step.
-- The rest of supabase/migrations/2026-10-03_jobs.sql was applied to production on 3 Oct 2026 through the Supabase
-- connector (migrations jobs_2026_10_03_part1 to part4). These four functions were not: each contains a DELETE
-- statement, the connector asks the owner to confirm those, and the confirmation did not reach him.
-- Paste this whole file into the Supabase SQL editor (project wjuqtjlrtcywjaspjpwu) and press Run.
-- Nothing is deleted when it runs: the DELETE statements are inside the functions, for when a member deletes his
-- own job or frees a day. Safe to run twice. Identical to the same four functions in 2026-10-03_jobs.sql.

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
