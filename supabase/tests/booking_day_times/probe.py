import json, subprocess
A='ADMINTOKEN0000000000000000'; F='FULLTOKEN00000000000000000'
def q(sql, db='eitv_bt_mig', ok=True, role=None):
    pre = f"set role {role}; " if role else ''
    out = subprocess.run(['psql','-qAt','-v','ON_ERROR_STOP=1','-d',db,'-c',pre+sql],capture_output=True,text=True)
    if ok and out.returncode: raise SystemExit('SQL failed: '+sql+'\n'+out.stderr)
    return out.stdout.strip() if out.returncode == 0 else 'ERR: '+out.stderr.strip().splitlines()[0]
def j(sql, **k): return json.loads(q(sql, **k))
def lit(o): return "'" + json.dumps(o).replace("'", "''") + "'"
res = []
def check(name, cond, detail=''):
    res.append(bool(cond)); print(('PASS ' if cond else 'FAIL ') + name + ((' :: ' + str(detail)[:400]) if not cond else ''))
FP = "select string_agg(p.proname||':'||left(md5(replace(pg_get_functiondef(p.oid), E'\\r','')),6), ' ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname not like '\\_\\_%'"
a, b = q(FP, db='eitv_bt_new'), q(FP, db='eitv_bt_mig')
check('the migration (run twice) leaves the same functions as the schema record', a == b, [x for x in zip(a.split(), b.split()) if x[0] != x[1]])
COLS = "select string_agg(column_name||':'||data_type||':'||coalesce(column_default,''), ',' order by column_name) from information_schema.columns where table_schema='public' and table_name='bookings'"
check('bookings has the same columns either way', q(COLS, db='eitv_bt_new') == q(COLS, db='eitv_bt_mig'))
check('the plan constraint is there once', q("select count(*) from pg_constraint where conname='bookings_day_plan_check'") == '1')
check('no table grants, no policies', q("select count(*) from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated')") == '0' and q("select count(*) from pg_policies where schemaname='public'") == '0')
check('sheets made before the change read exactly as they did', q("select string_agg(md5(public._booking_content(b)::text), ',' order by booker_name) from public.bookings b") == open('/tmp/bt_before.txt').read().strip() and q("select count(*) from public.bookings where day_plan <> '{}'::jsonb") == '0')
check('the helper cannot be called from outside', 'permission denied' in q("select public._booking_plan_clean('{}'::jsonb,'a','b','c')", ok=False, role='anon'))
T = q("select id from public.__ids where k='T'")
def save(o, tok=F): return j(f"select public.booking_save('{tok}', '{T}', {lit(o)}::jsonb)")
base = {'date_from':'2026-11-18','date_to':'2026-11-27','service':'bus','booker_name':'Yael','booker_phone':'050-000-0000','pax':'24'}
five = '2026-11-18,2026-11-19,2026-11-22,2026-11-24,2026-11-26'
plan = {'2026-11-18':{'start':'08:30','end':'18:00','route':'Dead Sea'},'2026-11-19':{'start':'10:30'},'2026-11-22':{'start':'10:15','end':'19:00'},'2026-11-24':{'start':'09:00','end':'18:00','route':'Gaza Envelope'}}
s = save(dict(base, days=five, day_plan=plan))
check('each day keeps its own times and where to; a day with nothing has no entry', s['day_plan'] == plan, s['day_plan'])
key = s['key']
o = j(f"select public.booking_open('{key}')", role='anon')
check('the company page receives the plan', o['day_plan'] == plan, o.get('day_plan'))
check('the company page still receives no private field', not ({'client_ref','private_note','owner','vendor_id','id'} & set(o)), list(o))
x = save(dict(base, booker_name='Junk', days=five, day_plan={'2026-11-18':{'start':'8:30','end':'25:00','route':'  x  '},'2026-11-20':{'start':'09:00'},'2026-12-01':{'start':'09:00'},'junk':{'start':'09:00'},'2026-11-19':'09:00','2026-11-22':{'start':'09:00','end':'17:59','route':'r'*400,'extra':'no'},'2026-11-24':{}}))
check('bad times dropped, days not on the sheet dropped, route cut to 300, unknown keys dropped, empty entries dropped',
      x['day_plan'] == {'2026-11-18':{'route':'x'},'2026-11-22':{'start':'09:00','end':'17:59','route':'r'*300}}, x['day_plan'])
x = save(dict(base, booker_name='One', date_to='', day_plan={'2026-11-18':{'start':'09:00'}}))
check('a one-day sheet has no plan (it uses its own pick-up and drop-off time)', x['day_plan'] == {}, x)
x = save(dict(base, booker_name='Plain', day_plan={'2026-11-18':{'start':'08:00'},'2026-11-21':{'start':'11:00','end':'16:00'}}))
check('a plain period (no separate days) can have a plan too', x['day_plan'] == {'2026-11-18':{'start':'08:00'},'2026-11-21':{'start':'11:00','end':'16:00'}}, x['day_plan'])
check('a sheet without a plan has no day_plan key in what both sides accept', q("select bool_or(public._booking_content(b) ? 'day_plan')::text from public.bookings b where day_plan = '{}'::jsonb") == 'false')
# an old app copy sends no day_plan
x = save(dict(base, id=s['id'], days=five, date_to='2026-11-26', pax='30'))
check('an old app copy changing something else keeps the plan', x['day_plan'] == plan and x['pax'] == '30', x['day_plan'])
x = save(dict(base, id=s['id'], days='2026-11-18,2026-11-22,2026-11-26', date_to='2026-11-26'))
check('when a day is taken off the sheet, its times go with it', x['day_plan'] == {k:v for k,v in plan.items() if k in ('2026-11-18','2026-11-22')}, x['day_plan'])
# both sides accept; then the guide moves a time
s = save(dict(base, id=s['id'], days=five, day_plan=plan))
terms = {'price':'3000','currency':'ILS','vat':'not_applicable','hours_incl':'10','km_incl':'250','overtime':'200','tolls':'incl','tip':'none','cancel':'48 hours'}
o = j(f"select public.booking_answer('{key}', {lit(terms)}::jsonb, 'Dudu')", role='anon')
check('the company answers: status answered', o['status'] == 'answered', o['status'])
x = save(dict(base, id=s['id'], days=five, day_plan=plan))
check('saving again with the same plan does not disturb the acceptance', x['status'] == 'answered', x['status'])
plan2 = json.loads(json.dumps(plan)); plan2['2026-11-19']['end'] = '17:00'
x = save(dict(base, id=s['id'], days=five, day_plan=plan2))
check('a time changed after the company accepted: back to waiting', x['status'] == 'waiting' and x['company_ok_at'] is None and x['day_plan'] == plan2, x)
o = j(f"select public.booking_open('{key}')", role='anon')
check('the company sees the new time, and what it last accepted for comparison', o['day_plan'] == plan2 and (o['seen'] or {}).get('day_plan') == plan, o.get('seen'))
o = j(f"select public.booking_accept('{key}', 'Dudu')", role='anon')
if o['status'] != 'confirmed': j(f"select public.booking_set_status('{F}', '{s['id']}', 'confirmed')")
line = q(f"select l.times from public.quote_lines l join public.quote_options o on o.id=l.option_id join public.bookings b on b.quote_id=o.quote_id where b.id='{s['id']}'")
check('confirmed, and the quote still counts the five chosen days', q(f"select status from public.bookings where id='{s['id']}'") == 'confirmed' and line == '5', line)
# an organisation
L = j("select public.request_access_org('Avi Stern','avi@yeshiva.test','050-000-0000','','2026-10-03b','Sample Yeshiva','I run the trips for a yeshiva of 120 students, six years in the role. Office 02-000-0000.')")['token']
q(f"select public.member_decide('{A}', (select id from public.members where email='avi@yeshiva.test'), 'approved')")
x = save(dict(base, days=five, day_plan=plan), tok=L)
mine = j(f"select public.bookings_list('{L}')")
check('an organisation can set times per day on its own sheet, and sees only its own sheets', x['day_plan'] == plan and all(m['mine'] for m in mine) and len(mine) == 1, [(m['mine'], m['booker_name']) for m in mine])
print(f"\n{len(res)} checks, {res.count(False)} failed")
