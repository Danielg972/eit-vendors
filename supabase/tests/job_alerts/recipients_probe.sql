-- D-69 job alerts: who an alert is queued for. Changes nothing: everything it does is rolled back, because it ends by
-- raising an error that carries the results. Read the JSON after "PROBE". Run it as one statement (Supabase SQL editor,
-- or execute_sql), after 2026-10-31b_job_alerts.sql is on the database. Locally: supabase/tests/job_alerts/run_sql.sh.
--
-- It adds sample members (emails end in @invalid.test), sets jobs_for and alerts_for to 'all' inside the transaction,
-- gives a phone to two of them, posts jobs through job_save as a colleague, answers, gives and closes them through the
-- real RPCs, and reads alert_queue for its own sample members only.
-- What must come back: "fail": [] and "passed" equal to "checks".
do $probe$
declare
  r jsonb := '[]'::jsonb; ok int := 0; n int := 0;
  tp text := 'probe-p-' || md5(random()::text); ta text := 'probe-a-' || md5(random()::text);
  tg1 text := 'probe-g1-' || md5(random()::text); td1 text := 'probe-d1-' || md5(random()::text);
  d text := to_char((now() at time zone 'Asia/Jerusalem')::date + 20, 'YYYY-MM-DD');
  jg uuid; jv uuid; jo uuid; jp uuid; jx uuid; got text; want text; g1 uuid; d1 uuid;
  label text;
begin
  -- the settings, inside this transaction only
  insert into public.app_settings (key, value) values ('jobs_for','all') on conflict (key) do update set value = excluded.value;
  insert into public.app_settings (key, value) values ('alerts_for','all') on conflict (key) do update set value = excluded.value;

  insert into public.members (name,email,role,token_hash,status,job_kinds,job_tags) values
    ('Probe Poster','p@invalid.test','Licensed tour guide',public._hash(tp),'approved','',''),
    ('Probe Admin','admin@invalid.test','',public._hash(ta),'approved','',''),
    ('Probe G1 any','g1@invalid.test','Licensed tour guide',public._hash(tg1),'approved','',''),
    ('Probe G2 none','g2@invalid.test','Licensed tour guide',public._hash('probe-g2-'||md5(random()::text)),'approved','none',''),
    ('Probe G3 jeep only','g3@invalid.test','Licensed tour guide',public._hash('probe-g3-'||md5(random()::text)),'approved','jeep_driver','midbari'),
    ('Probe G4 busy','g4@invalid.test','Licensed tour guide',public._hash('probe-g4-'||md5(random()::text)),'approved','',''),
    ('Probe G5 guide no eshkol','g5@invalid.test','Licensed tour guide',public._hash('probe-g5-'||md5(random()::text)),'approved','guide',''),
    ('Probe G6 guide eshkol','g6@invalid.test','Licensed tour guide',public._hash('probe-g6-'||md5(random()::text)),'approved','guide,van_driver','eshkol'),
    ('Probe A1 agent','a1@invalid.test','Travel agent',public._hash('probe-a1-'||md5(random()::text)),'approved','',''),
    ('Probe D1 van','d1@invalid.test','Other',public._hash(td1),'approved','van_driver',''),
    ('Probe X1 other','x1@invalid.test','Tour operator',public._hash('probe-x1-'||md5(random()::text)),'approved','other',''),
    ('Probe Q1 pending','q1@invalid.test','Licensed tour guide',public._hash('probe-q1-'||md5(random()::text)),'pending','',''),
    ('Probe G7 email off','g7@invalid.test','Licensed tour guide',public._hash('probe-g7-'||md5(random()::text)),'approved','','');
  update public.members set is_admin = true where email = 'admin@invalid.test';
  update public.members set alerts_email = false where email = 'g7@invalid.test';
  insert into public.members (name,email,role,token_hash,status,member_type,sections,org,credentials,job_kinds)
    values ('Probe Org','o1@invalid.test','Other',public._hash('probe-o1-'||md5(random()::text)),'approved','limited','transport','Probe Org','probe probe probe probe','van_driver');
  insert into public.member_days (member, day) values ('g4@invalid.test', d::date);
  update public.members set days_updated_at = now() where email like '%@invalid.test';
  -- a phone for G1 and for G7 (G7 has email off, so push only)
  insert into public.push_subs (member, endpoint, p256dh, auth) values
    ('g1@invalid.test','https://push.invalid.test/g1', repeat('B',87), repeat('a',22)),
    ('g7@invalid.test','https://push.invalid.test/g7', repeat('B',87), repeat('a',22));

  -- 1. a guide job for everyone it fits, posted by a colleague (job_save inserts an empty row, then fills it)
  jg := (public.job_save(tp, jsonb_build_object('kind','guide','title','Probe guide job','date_from',d,'price','1400','needs','','audience','all'))::jsonb->>'id')::uuid;
  -- 2. a guide job needing Eshkol
  jx := (public.job_save(tp, jsonb_build_object('kind','guide','title','Probe guide Eshkol','date_from',d,'price','1400','needs','eshkol','audience','all'))::jsonb->>'id')::uuid;
  -- 3. a van-driver job
  jv := (public.job_save(tp, jsonb_build_object('kind','van_driver','title','Probe van job','date_from',d,'price','900','audience','all'))::jsonb->>'id')::uuid;
  -- 4. an "other" job
  jo := (public.job_save(tp, jsonb_build_object('kind','other','title','Probe other job','date_from',d,'price','500','audience','all'))::jsonb->>'id')::uuid;
  -- 5. a picked job: G2 (takes no jobs, but picked), G4 (busy), the org; nobody else
  jp := (public.job_save(tp, jsonb_build_object('kind','guide','title','Probe picked job','date_from',d,'price','1400','audience','picked'),
         (select jsonb_agg(id) from public.members where email in ('g2@invalid.test','g4@invalid.test','o1@invalid.test')))::jsonb->>'id')::uuid;
  set constraints all immediate;   -- the new-job trigger waits for the end of the transaction; run it now

  -- an edit queues nothing new
  perform public.job_save(tp, jsonb_build_object('id',jg,'kind','guide','title','Probe guide job, changed','date_from',d,'price','1500','audience','all'));
  set constraints all immediate;

  for got, want, label in
    select coalesce((select string_agg(split_part(q.member,'@',1), ',' order by q.member) from public.alert_queue q
        where q.job_id = x.j and q.event = 'job_new' and q.channel = 'email' and q.member like '%@invalid.test'), ''), x.w, x.n
    from (values
      (jg, 'g1,g5,g6', 'guide job by email'),       -- licensed guides; not G2 (none), G3 (jeep only), G4 (busy), G7 (email off), the agent
      (jx, 'g1,g6', 'guide job needing Eshkol by email'),   -- as _job_fits: G1 has not said what he takes, so he is offered everything
      (jv, 'd1,g6', 'van job by email'),
      (jo, 'x1', 'other job by email'),
      (jp, 'g2', 'picked job by email')) as x(j, w, n)
  loop
    n := n + 1; if got = want then ok := ok + 1; else r := r || jsonb_build_object('check', label, 'got', got, 'want', want); end if;
  end loop;

  -- push only for the members with a phone; G7 (email off) gets push and no email
  got := coalesce((select string_agg(split_part(q.member,'@',1), ',' order by q.member) from public.alert_queue q
    where q.job_id = jg and q.event = 'job_new' and q.channel = 'push' and q.member like '%@invalid.test'), '');
  n := n + 1; if got = 'g1,g7' then ok := ok + 1; else r := r || jsonb_build_object('check','guide job by push','got',got,'want','g1,g7'); end if;
  -- the poster, the org, the pending member, the busy guide never
  got := coalesce((select string_agg(distinct split_part(q.member,'@',1), ',') from public.alert_queue q
    where q.event = 'job_new' and q.member in ('p@invalid.test','o1@invalid.test','q1@invalid.test','g4@invalid.test','a1@invalid.test')), '');
  n := n + 1; if got = '' then ok := ok + 1; else r := r || jsonb_build_object('check','never: poster, org, pending, busy, agent','got',got,'want',''); end if;
  -- Eretz Israel Tours: one group_review per colleague job (5 jobs, by email; no phone), never job_new for 'all'
  got := (select count(*)::text from public.alert_queue q where q.member = 'admin@invalid.test' and q.event = 'group_review' and q.channel = 'email');
  n := n + 1; if got = '5' then ok := ok + 1; else r := r || jsonb_build_object('check','group_review for each colleague job','got',got,'want','5'); end if;
  got := (select count(*)::text from public.alert_queue q where q.member = 'admin@invalid.test' and q.event = 'job_new');
  n := n + 1; if got = '0' then ok := ok + 1; else r := r || jsonb_build_object('check','no job_new for Eretz Israel Tours','got',got,'want','0'); end if;
  -- the edit added nothing
  got := (select count(*)::text from public.alert_queue q where q.job_id = jg and q.member like '%@invalid.test');
  n := n + 1; if got = '6' then ok := ok + 1; else r := r || jsonb_build_object('check','edit queues nothing (3 email + 2 push + 1 group_review)','got',got,'want','6'); end if;

  -- 6. "I'm available" by G1 and D1 on the guide job / van job: the poster is alerted, once per colleague
  perform public.job_answer(tg1, jg, 'yes', false);
  perform public.job_answer(tg1, jg, '', false);
  perform public.job_answer(tg1, jg, 'yes', false);     -- again: still one alert
  perform public.job_answer(td1, jv, 'yes', false);
  got := (select count(*)::text from public.alert_queue q where q.member = 'p@invalid.test' and q.event = 'job_available' and q.channel = 'email');
  n := n + 1; if got = '2' then ok := ok + 1; else r := r || jsonb_build_object('check','poster alerted once per available colleague','got',got,'want','2'); end if;

  -- 7. given: the colleague it was given to
  select id into g1 from public.members where email = 'g1@invalid.test';
  perform public.job_give(tp, jg, g1);
  got := coalesce((select string_agg(split_part(q.member,'@',1)||':'||q.channel, ',' order by q.member, q.channel) from public.alert_queue q where q.job_id = jg and q.event = 'job_given'), '');
  n := n + 1; if got = 'g1:email,g1:push' then ok := ok + 1; else r := r || jsonb_build_object('check','job_given to the taker','got',got,'want','g1:email,g1:push'); end if;

  -- 8. closed: everyone who said available (D1 on the van job)
  perform public.job_set_status(tp, jv, 'closed');
  got := coalesce((select string_agg(split_part(q.member,'@',1), ',' order by q.member) from public.alert_queue q where q.job_id = jv and q.event = 'job_closed' and q.channel = 'email'), '');
  n := n + 1; if got = 'd1' then ok := ok + 1; else r := r || jsonb_build_object('check','job_closed to those available','got',got,'want','d1'); end if;

  -- 9. an organisation member's alert state has no group link and no admin number; a guide gets the link
  insert into public.app_settings (key, value) values ('jobs_group_link','https://chat.whatsapp.com/PROBEPROBEPROBE1') on conflict (key) do update set value = excluded.value;
  insert into public.app_settings (key, value) values ('admin_whatsapp','972500000000') on conflict (key) do update set value = excluded.value;
  got := (select coalesce(public._alerts_json(m)->>'group_link','-')||'|'||coalesce(public._alerts_json(m)->>'admin_whatsapp','-') from public.members m where email = 'o1@invalid.test');
  n := n + 1; if got = '-|-' then ok := ok + 1; else r := r || jsonb_build_object('check','org gets no link and no number','got',got,'want','-|-'); end if;
  got := (select coalesce(public._alerts_json(m)->>'group_link','-') from public.members m where email = 'a1@invalid.test');
  n := n + 1; if got = '-' then ok := ok + 1; else r := r || jsonb_build_object('check','travel agent gets no group link','got',got,'want','-'); end if;
  got := (select coalesce(public._alerts_json(m)->>'admin_whatsapp','-') from public.members m where email = 'a1@invalid.test');
  n := n + 1; if got = '972500000000' then ok := ok + 1; else r := r || jsonb_build_object('check','full member gets the admin number','got',got,'want','972500000000'); end if;
  got := (select coalesce(public._alerts_json(m)->>'group_link','-') from public.members m where email = 'g1@invalid.test');
  n := n + 1; if got like 'https://chat.whatsapp.com/%' then ok := ok + 1; else r := r || jsonb_build_object('check','guide gets the group link','got',got,'want','the link'); end if;

  -- 10. the unsubscribe key works without sign-in, and only for a real key
  got := public.alerts_unsubscribe((select alerts_key from public.members where email = 'g5@invalid.test'))->>'ok';
  got := got || '|' || (select alerts_email::text from public.members where email = 'g5@invalid.test');
  got := got || '|' || (public.alerts_unsubscribe(repeat('0',36))->>'ok');
  n := n + 1; if got = 'true|false|false' then ok := ok + 1; else r := r || jsonb_build_object('check','unsubscribe by key','got',got,'want','true|false|false'); end if;

  -- 11. a colleague cannot mark a job for the group; Eretz Israel Tours can
  begin perform public.job_group_mark(tp, jo, 'shared'); got := 'allowed'; exception when others then got := 'refused'; end;
  n := n + 1; if got = 'refused' then ok := ok + 1; else r := r || jsonb_build_object('check','colleague cannot mark for the group','got',got,'want','refused'); end if;
  got := public.job_group_mark(ta, jo, 'shared')::jsonb->>'group_status';
  n := n + 1; if got = 'shared' then ok := ok + 1; else r := r || jsonb_build_object('check','Eretz Israel Tours marks shared','got',got,'want','shared'); end if;
  got := coalesce(public._job_json((select j from public.jobs j where id = jo), (select m from public.members m where email = 'g1@invalid.test'))::jsonb->>'group_status', 'null');
  n := n + 1; if got = 'null' then ok := ok + 1; else r := r || jsonb_build_object('check','a colleague never sees group_status','got',got,'want','null'); end if;

  -- 12. the queue and the phones are closed to anon and authenticated
  got := (select count(*)::text from information_schema.role_table_grants where table_schema = 'public' and table_name in ('alert_queue','push_subs') and grantee in ('anon','authenticated','PUBLIC'));
  n := n + 1; if got = '0' then ok := ok + 1; else r := r || jsonb_build_object('check','no table grants','got',got,'want','0'); end if;
  got := (select string_agg(p.proname, ',') from pg_proc p join pg_namespace s on s.oid = p.pronamespace where s.nspname = 'public'
    and p.proname in ('_alerts_due','_alert_mark','_push_mark','_alert_add','_alert_recipients','_alerts_json','_setting')
    and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute')));
  n := n + 1; if got is null then ok := ok + 1; else r := r || jsonb_build_object('check','sender and helper functions closed to anon','got',got,'want','none'); end if;

  raise exception 'PROBE %', jsonb_build_object('checks', n, 'passed', ok, 'fail', r);
end $probe$;
