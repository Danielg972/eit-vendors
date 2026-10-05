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
# ---- D-25: terms left off the sheet
check('the two helpers of D-25 cannot be called from outside', 'permission denied' in q("select public._terms_off_clean('tip')", ok=False, role='anon') and 'permission denied' in q("select public._terms_on('{}'::jsonb,'tip')", ok=False, role='anon'))
check('the off list keeps only known groups, in a fixed order', q("select public._terms_off_clean('tip, junk,km,tip,;drop,KM,payment')") == 'km,tip,payment')
full = {'price':'3000','currency':'ILS','vat':'not_applicable','hours_incl':'10','km_incl':'250','hours_from':'pickup','overtime':'200','extra_km':'5','tolls':'extra','tolls_note':'by the bill','parking':'incl','tip':'customary','tip_amt':'100','cancel':'48 hours','extras':'overnight 350','payment':'transfer','note':'n'}
o1 = save(dict(base, booker_name='Off', proposed=full, terms_off='tip,km'))
check('left off tip and mileage: gone from what the guide expects, the rest stays', o1['terms_off'] == 'km,tip' and not ({'tip','tip_amt','km_incl','extra_km'} & set(o1['proposed'])) and {'hours_incl','overtime','tolls','parking','cancel','payment','price','vat'} <= set(o1['proposed']), o1['proposed'])
oc = j(f"select public.booking_open('{o1['key']}')", role='anon')
check('the company page is told which terms are off', oc['terms_off'] == 'km,tip' and 'tip' not in oc['proposed'], oc.get('terms_off'))
oc = j(f"select public.booking_answer('{o1['key']}', {lit(full)}::jsonb, 'Dudu')", role='anon')
check('the company cannot add a term that was left off', oc['status'] == 'answered' and not ({'tip','tip_amt','km_incl','extra_km'} & set(oc['terms'])) and oc['terms']['overtime'] == '200', oc['terms'])
x = save(dict(base, id=o1['id'], booker_name='Off', proposed=full, private_note='only for me'))
check('an old app copy (no terms_off) keeps the list', x['terms_off'] == 'km,tip' and x['private_note'] == 'only for me' and x['status'] == 'answered', (x['terms_off'], x['status']))
x = save(dict(base, id=o1['id'], booker_name='Off', proposed=full, terms_off='km,tip'))
check('saving the same list again does not disturb the acceptance', x['status'] == 'answered', x['status'])
x = save(dict(base, id=o1['id'], booker_name='Off', proposed=full, terms_off='km,tip,parking'))
check('one more term left off after the company accepted: it leaves the agreed terms, and the sheet goes back to waiting', x['status'] == 'waiting' and 'parking' not in x['terms'] and x['terms']['overtime'] == '200', x)
oc = j(f"select public.booking_open('{o1['key']}')", role='anon')
check('the company sees what it last accepted for comparison', (oc['seen'] or {}).get('terms_off') == 'km,tip' and 'parking' in (oc['seen'] or {}).get('terms', {}), oc.get('seen'))
x = save(dict(base, id=o1['id'], booker_name='Off', proposed=full, terms_off=''))
check('a term put back on the sheet is asked again (it comes back empty)', x['terms_off'] == '' and 'tip' in x['proposed'] and 'tip' not in x['terms'] and x['status'] == 'waiting', x)
g2 = save(dict(base, booker_name='Typed', terms_off='cancel,tip', terms=full, company_agreed=True, answered_by='Dudu'))
check('terms the guide types in himself lose the ones left off too', not ({'tip','tip_amt','cancel'} & set(g2['terms'])) and g2['terms']['km_incl'] == '250', g2['terms'])
check('a sheet with every term on has no terms_off key in what both sides accept', q("select bool_or(public._booking_content(b) ? 'terms_off')::text from public.bookings b where terms_off = ''") == 'false')
# ---- D-26 and the loose end of D-25: the conditions on the quote a confirmed sheet leaves
def confirm(o):
    s0 = save(dict(base, **o)); j(f"select public.booking_answer('{s0['key']}', {lit(dict(full, hours_from='depot'))}::jsonb, 'Dudu')", role='anon'); j(f"select public.booking_set_status('{F}', '{s0['id']}', 'confirmed')")
    return q(f"select q.conditions from public.quotes q join public.bookings b on b.quote_id = q.id where b.id = '{s0['id']}'")
c1 = confirm(dict(booker_name='Q1'))
check('the quote says "when the bus turns on", and gives the cancellation policy', 'Hours counted from when the bus turns on.' in c1 and 'leaving the depot' not in c1 and 'Cancellation policy: 48 hours' in c1, c1)
c2 = confirm(dict(booker_name='Q2', terms_off='cancel'))
check('with the cancellation policy left off the sheet, the quote says nothing about it', 'Cancellation policy' not in c2 and 'From a booking sheet accepted by both sides.' in c2, c2)
s3 = save(dict(base, booker_name='Q3')); j(f"select public.booking_answer('{s3['key']}', {lit({'price':'3000'})}::jsonb, 'Dudu')", role='anon'); j(f"select public.booking_set_status('{F}', '{s3['id']}', 'confirmed')")
c3 = q(f"select q.conditions from public.quotes q join public.bookings b on b.quote_id = q.id where b.id = '{s3['id']}'")
check('with the policy on the sheet and left empty, the quote still says none was given', 'Cancellation policy: none given.' in c3, c3)
# an organisation
L = j("select public.request_access_org('Avi Stern','avi@yeshiva.test','050-000-0000','','2026-10-03b','Sample Yeshiva','I run the trips for a yeshiva of 120 students, six years in the role. Office 02-000-0000.')")['token']
q(f"select public.member_decide('{A}', (select id from public.members where email='avi@yeshiva.test'), 'approved')")
x = save(dict(base, days=five, day_plan=plan), tok=L)
mine = j(f"select public.bookings_list('{L}')")
check('an organisation can set times per day on its own sheet, and sees only its own sheets', x['day_plan'] == plan and all(m['mine'] for m in mine) and len(mine) == 1, [(m['mine'], m['booker_name']) for m in mine])
print(f"\n{len(res)} checks, {res.count(False)} failed")
