-- D-69: the functions the job-alerts Edge Function calls (service key only): _alerts_due, _alert_mark, _push_mark.
-- Local database only (run_sql.sh), after recipients_probe.sql's kind of data: it makes its own sample members and a job,
-- reads the queue as the sender would, and rolls everything back by ending with an error carrying the results.
do $probe$
declare r jsonb := '[]'::jsonb; ok int := 0; n int := 0; got text; due json; tp text := 'probe-p-' || md5(random()::text);
  d text := to_char((now() at time zone 'Asia/Jerusalem')::date + 20, 'YYYY-MM-DD'); jid uuid; qid uuid;
begin
  insert into public.app_settings (key, value) values ('jobs_for','all'),('alerts_for','all') on conflict (key) do update set value = excluded.value;
  insert into public.members (name,email,role,token_hash,status) values
    ('Probe Poster','p@invalid.test','Licensed tour guide',public._hash(tp),'approved'),
    ('Probe G1','g1@invalid.test','Licensed tour guide',public._hash('x'||md5(random()::text)),'approved');
  update public.members set days_updated_at = now() where email like '%@invalid.test';
  insert into public.push_subs (member, endpoint, p256dh, auth) values ('g1@invalid.test','https://push.invalid.test/g1', repeat('B',87), repeat('a',22));
  jid := (public.job_save(tp, jsonb_build_object('kind','guide','title','Probe job','date_from',d,'price','1400','note','Probe private note','payment','Probe pay'))::jsonb->>'id')::uuid;
  set constraints all immediate;

  -- only email when push is not set up: the push row stays waiting, untouched
  due := public._alerts_due(50, array['email']);
  got := (select string_agg(x->>'channel', ',') from json_array_elements(due) x where x->'job'->>'id' = jid::text);
  n := n + 1; if got = 'email' then ok := ok + 1; else r := r || jsonb_build_object('check','email channel only','got',got); end if;
  got := (select status || ':' || (claimed_at is null)::text from public.alert_queue where job_id = jid and channel = 'push' and member = 'g1@invalid.test');
  n := n + 1; if got = 'waiting:true' then ok := ok + 1; else r := r || jsonb_build_object('check','push row untouched','got',got); end if;
  -- the job sent to the sender has no poster, note or payment; the row has the member's own key
  got := (select (x->'job')::jsonb ? 'note' or (x->'job')::jsonb ? 'payment' or (x->'job')::jsonb ? 'owner' or x::text like '%p@invalid.test%' from json_array_elements(due) x where x->'job'->>'id' = jid::text limit 1)::text;
  n := n + 1; if got = 'false' then ok := ok + 1; else r := r || jsonb_build_object('check','no poster, note or payment in what the sender gets','got',got); end if;
  got := (select (x->>'key') = (select alerts_key from public.members where email = 'g1@invalid.test') from json_array_elements(due) x where x->'job'->>'id' = jid::text limit 1)::text;
  n := n + 1; if got = 'true' then ok := ok + 1; else r := r || jsonb_build_object('check','unsubscribe key comes with the row','got',got); end if;
  -- a claimed row is not handed out again
  due := public._alerts_due(50, array['email']);
  got := (select count(*)::text from json_array_elements(due) x where x->'job'->>'id' = jid::text);
  n := n + 1; if got = '0' then ok := ok + 1; else r := r || jsonb_build_object('check','claimed row not handed out twice','got',got); end if;
  -- marking
  select id into qid from public.alert_queue where job_id = jid and channel = 'email' and member = 'g1@invalid.test';
  perform public._alert_mark(qid, 'sent', '');
  got := (select status || ':' || (sent_at is not null)::text from public.alert_queue where id = qid);
  n := n + 1; if got = 'sent:true' then ok := ok + 1; else r := r || jsonb_build_object('check','marked sent','got',got); end if;
  -- push: handed out with the phone; "busy" six times becomes failed
  due := public._alerts_due(50, array['push']);
  got := (select json_array_length(x->'subs')::text from json_array_elements(due) x where x->'job'->>'id' = jid::text limit 1);
  n := n + 1; if got = '1' then ok := ok + 1; else r := r || jsonb_build_object('check','push row comes with the phone','got',got); end if;
  select id into qid from public.alert_queue where job_id = jid and channel = 'push' and member = 'g1@invalid.test';
  for i in 1..6 loop perform public._alert_mark(qid, 'waiting', 'push 503'); end loop;
  got := (select status || ':' || tries from public.alert_queue where id = qid);
  n := n + 1; if got = 'failed:6' then ok := ok + 1; else r := r || jsonb_build_object('check','six busy tries become failed','got',got); end if;
  -- 'later' (email limit reached) puts a row back without counting a try
  insert into public.alert_queue (member, event, job_id, channel) values ('g1@invalid.test','job_given', jid, 'email') returning id into qid;
  for i in 1..8 loop perform public._alert_mark(qid, 'later', 'email limit reached'); end loop;
  got := (select status || ':' || tries || ':' || (claimed_at is null)::text from public.alert_queue where id = qid);
  n := n + 1; if got = 'waiting:0:true' then ok := ok + 1; else r := r || jsonb_build_object('check','later counts no try','got',got); end if;
  -- a phone that is gone is switched off
  perform public._push_mark('https://push.invalid.test/g1', false, true);
  got := (select dead::text from public.push_subs where endpoint = 'https://push.invalid.test/g1');
  n := n + 1; if got = 'true' then ok := ok + 1; else r := r || jsonb_build_object('check','gone phone switched off','got',got); end if;
  -- a job no longer open: its waiting rows are skipped with a reason
  insert into public.members (name,email,role,token_hash,status) values ('Probe G2','g2@invalid.test','Licensed tour guide',public._hash('y'||md5(random()::text)),'approved');
  update public.members set days_updated_at = now() where email = 'g2@invalid.test';
  jid := (public.job_save(tp, jsonb_build_object('kind','guide','title','Probe job 2','date_from',d,'price','1400'))::jsonb->>'id')::uuid;
  set constraints all immediate;
  perform public.job_set_status(tp, jid, 'closed');
  perform public._alerts_due(50, array['email']);
  got := (select string_agg(distinct status || ':' || error, ',') from public.alert_queue where job_id = jid and event = 'job_new');
  n := n + 1; if got = 'skipped:job no longer open' then ok := ok + 1; else r := r || jsonb_build_object('check','closed job: new-job rows skipped','got',got); end if;
  -- busy after the alert was queued: skipped
  jid := (public.job_save(tp, jsonb_build_object('kind','guide','title','Probe job 3','date_from',d,'price','1400'))::jsonb->>'id')::uuid;
  set constraints all immediate;
  insert into public.member_days (member, day) values ('g2@invalid.test', d::date);
  perform public._alerts_due(50, array['email']);
  got := (select status || ':' || error from public.alert_queue where job_id = jid and member = 'g2@invalid.test' and channel = 'email');
  n := n + 1; if got = 'skipped:busy on those days' then ok := ok + 1; else r := r || jsonb_build_object('check','marked busy later: skipped','got',got); end if;
  raise exception 'PROBE %', jsonb_build_object('checks', n, 'passed', ok, 'fail', r);
end $probe$;
