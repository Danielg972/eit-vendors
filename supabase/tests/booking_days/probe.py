import json, subprocess
A='ADMINTOKEN0000000000000000'; F='FULLTOKEN00000000000000000'
def q(sql, db='eitv_bd_mig', ok=True, role=None):
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
a, b = q(FP, db='eitv_bd_new'), q(FP, db='eitv_bd_mig')
check('the migration (run twice) leaves the same functions as the schema record', a == b, [x for x in zip(a.split(), b.split()) if x[0] != x[1]])
COLS = "select string_agg(column_name||':'||data_type||':'||coalesce(column_default,''), ',' order by column_name) from information_schema.columns where table_schema='public' and table_name='bookings'"
check('bookings has the same columns either way', q(COLS, db='eitv_bd_new') == q(COLS, db='eitv_bd_mig'))
check('the days constraint is there once', q("select count(*) from pg_constraint where conname='bookings_days_check'") == '1')
check('no table grants, no policies', q("select count(*) from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated')") == '0' and q("select count(*) from pg_policies where schemaname='public'") == '0')
check('a sheet made before the change reads exactly as it did', q("select md5(public._booking_content(b)::text) from public.bookings b") == open('/tmp/bd_before.txt').read().strip() and q("select days from public.bookings") == '')
check('the helper cannot be called from outside', 'permission denied' in q("select public._booking_days_clean('a','b','c')", ok=False, role='anon'))
T = q("select id from public.__ids where k='T'")
def save(o, tok=F): return j(f"select public.booking_save('{tok}', '{T}', {lit(o)}::jsonb)")
base = {'date_from':'2026-11-18','date_to':'2026-11-27','service':'bus','booker_name':'Yael','booker_phone':'050-000-0000','pax':'24'}
five = '2026-11-18,2026-11-19,2026-11-22,2026-11-24,2026-11-26'
s = save(dict(base, days=five))
check('five of ten days are kept, and the period becomes first to last chosen day', s['days'] == five and s['date_from'] == '2026-11-18' and s['date_to'] == '2026-11-26', s)
key = s['key']
o = j(f"select public.booking_open('{key}')", role='anon')
check('the company page receives the days', o['days'] == five and o['date_to'] == '2026-11-26', o)
check('the company page still receives no private field', not ({'client_ref','private_note','owner','vendor_id','id'} & set(o)), list(o))
x = save(dict(base, days='2026-11-18,2026-11-19,2026-11-20,2026-11-21,2026-11-22,2026-11-23,2026-11-24,2026-11-25,2026-11-26,2026-11-27'))
check('every day chosen is stored as no list', x['days'] == '' and x['date_to'] == '2026-11-27', x)
x = save(dict(base, date_to='2026-11-20', days='2026-11-18,2026-11-19,2026-11-20'))
check('days in a row are stored as a plain period', x['days'] == '' and x['date_from'] == '2026-11-18' and x['date_to'] == '2026-11-20', x)
x = save(dict(base, days='2026-11-26,2026-11-18,2026-11-18,2026-12-25,2026-02-30,junk,2026-11-22, 2026-11-19'))
check('days outside the period, impossible dates, repeats and junk are dropped; the rest sorted', x['days'] == '2026-11-18,2026-11-22,2026-11-26', x['days'])
x = save(dict(base, days='2026-11-22'))
check('one chosen day is not a list', x['days'] == '', x)
x = save(dict(base, date_from='2026-01-01', date_to='2026-12-31', days=','.join(f'2026-{m:02d}-{d:02d}' for m in range(1,13) for d in (1,15,28))[:900]))
check('never more than 62 days, and the stored list fits', x['days'].count(',') + 1 <= 62 and len(x['days']) <= 700, len(x['days']))
# a copy of the app from before the change sends no "days"
old = dict(base, id=s['id'], pax='30', date_to='2026-11-26')   # it sends the dates it was given
x = save(old)
check('an old app copy changing something else keeps the days', x['days'] == five and x['pax'] == '30', x)
x = save(dict(old, date_from='2026-11-18', date_to='2026-11-30'))
check('an old app copy moving the dates clears the days', x['days'] == '' and x['date_to'] == '2026-11-30', x)
# both sides accept; then the guide drops a day
s = save(dict(base, id=s['id'], days=five))
terms = {'price':'3000','currency':'ILS','vat':'not_applicable','hours_incl':'10','km_incl':'250','overtime':'200','tolls':'incl','tip':'none','cancel':'48 hours'}
o = j(f"select public.booking_answer('{key}', {lit(terms)}::jsonb, 'Dudu')", role='anon')
check('the company answers: status answered', o['status'] == 'answered', o['status'])
four = '2026-11-18,2026-11-19,2026-11-22,2026-11-26'
x = save(dict(base, id=s['id'], days=four))
check('the guide drops a day after the company accepted: back to waiting', x['status'] == 'waiting' and x['days'] == four and x['company_ok_at'] is None, x)
o = j(f"select public.booking_open('{key}')", role='anon')
check('the company sees the new days, and what it last accepted for comparison', o['days'] == four and (o['seen'] or {}).get('days') == five, o.get('seen'))
o = j(f"select public.booking_accept('{key}', 'Dudu')", role='anon')
x = j(f"select public.booking_set_status('{F}', '{s['id']}', 'confirmed')") if o['status'] != 'confirmed' else None
check('accepted by both: confirmed', q(f"select status from public.bookings where id='{s['id']}'") == 'confirmed')
line = q(f"select l.times||'|'||l.price||'|'||l.unit from public.quote_lines l join public.quote_options o on o.id=l.option_id join public.bookings b on b.quote_id=o.quote_id where b.id='{s['id']}'")
check('the quote it leaves counts the chosen days, not the period', line == '4|3000|per vehicle per day', line)
cond = q(f"select q.conditions from public.quotes q join public.bookings b on b.quote_id=q.id where b.id='{s['id']}'")
check('and says they are separate days', '4 separate days between these dates.' in cond, cond)
# a plain period still counts every day
p = save(dict(base, booker_name='Plain'))
j(f"select public.booking_answer('{p['key']}', {lit(terms)}::jsonb, 'Dudu')", role='anon'); j(f"select public.booking_set_status('{F}', '{p['id']}', 'confirmed')")
line = q(f"select l.times from public.quote_lines l join public.quote_options o on o.id=l.option_id join public.bookings b on b.quote_id=o.quote_id where b.id='{p['id']}'")
check('a plain period of ten days still counts ten', line == '10', line)
check('a plain sheet has no days key in what both sides accept', q(f"select (public._booking_content(b) ? 'days')::text from public.bookings b where id='{p['id']}'") == 'false')
# a limited member (an organisation) can use it the same way, on his own sheets only
L = j("select public.request_access_org('Avi Stern','avi@yeshiva.test','050-000-0000','','2026-10-03b','Sample Yeshiva','I run the trips for a yeshiva of 120 students, six years in the role. Office 02-000-0000.')")['token']
q(f"select public.member_decide('{A}', (select id from public.members where email='avi@yeshiva.test'), 'approved')")
if True:
    x = save(dict(base, days=five), tok=L)
    check('an organisation can choose days on its own sheet', x['days'] == five, x)
    mine = j(f"select public.bookings_list('{L}')")
    check('and still sees only its own sheets', all(m['mine'] for m in mine) and len(mine) == 1, [(m['mine'], m['booker_name']) for m in mine])
print(f"\n{len(res)} checks, {res.count(False)} failed")
