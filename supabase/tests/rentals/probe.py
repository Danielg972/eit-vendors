import json, os, re, subprocess, sys
NEW, MIG, MIG2 = 'eitv_rt_new', 'eitv_rt_mig', 'eitv_rt_mig2'
HERE = os.path.dirname(os.path.abspath(__file__))
MDIR = os.path.join(HERE, '..', '..', 'migrations')
FA, FB, FC = '2026-10-12_rentals.sql', '2026-10-12b_wineries_under_sites.sql', '2026-10-12c_vehicle_rental_category.sql'
A='ADMINTOKEN0000000000000000'; F='FULLTOKEN00000000000000000'; G='GUIDETWOTOKEN0000000000000'
O1, O2, O3, O4 = 'ORGSITESTOKEN0000000000000', 'ORGFOODTOKEN00000000000000', 'ORGHOTELSTOKEN000000000000', 'ORGGUIDESTOKEN000000000000'
def q(sql, ok=True, role=None, db=NEW):
    pre = f"set role {role}; " if role else ''
    out = subprocess.run(['psql','-qAt','-v','ON_ERROR_STOP=1','-d',db,'-c',pre+sql],capture_output=True,text=True)
    if ok and out.returncode: raise SystemExit('SQL failed: '+sql[:400]+'\n'+out.stderr)
    return out.stdout.strip() if out.returncode == 0 else 'ERR: '+out.stderr.strip().splitlines()[0]
def j(sql, **k): return json.loads(q(sql, **k))
def run_file(db, name):   # one migration file, stopping at the first error; '' when it ran clean
    out = subprocess.run(['psql','-q','-v','ON_ERROR_STOP=1','-d',db,'-f',os.path.join(MDIR,name)],capture_output=True,text=True)
    return '' if out.returncode == 0 and 'ERROR' not in out.stderr else 'ERR: '+out.stderr.strip()[:300]
def lit(o): return "'" + json.dumps(o).replace("'", "''") + "'"
res = []
def check(name, cond, detail=''):
    res.append((name, bool(cond))); print(('PASS ' if cond else 'FAIL ') + name + ((' :: ' + str(detail)[:400]) if not cond else ''))

# ===== 1. the files =====
src = {n: open(os.path.join(MDIR, n)).read() for n in (FA, FB, FC)}
code = lambda s: '\n'.join(l.split('--')[0] for l in s.splitlines())   # what runs, without the comments
check('files a and b remove nothing: no DELETE, DROP or TRUNCATE in what they run (so they can go through the connector)',
    not any(re.search(r'\b(delete|drop|truncate)\b', code(src[n]), re.I) for n in (FA, FB)))
check('file c is the one statement that swaps the list of categories (the owner runs it)',
    code(src[FC]).strip().count(';') == 1 and 'drop constraint vendors_category_check, add constraint vendors_category_check' in src[FC])
FP6 = "select string_agg(p.proname||':'||left(md5(replace(pg_get_functiondef(p.oid), E'\\r','')),6), ' ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname not like '\\_\\_%'"
fpl = lambda t: [l for l in t.splitlines() if l and not l.startswith('#')][0]
# production before D-42 (the fingerprints file as it was on main, 091361e) and after (the file as it is now)
prod = fpl(subprocess.run(['git','show','091361e:supabase/tests/production_fingerprints.txt'],capture_output=True,text=True,cwd=HERE).stdout)
prod_after = fpl(open(os.path.join(HERE, '..', 'production_fingerprints.txt')).read())
check('before: the schema record from main gives exactly the functions production has (production_fingerprints.txt)', q(FP6, db=MIG) == prod, [x for x in q(FP6, db=MIG).split() if x not in prod.split()][:6])
VR = "insert into public.vendors (name, category) values ('Sample rentals before','Vehicle Rental')"
check('before file c: a supplier in the category Vehicle Rental is refused', 'vendors_category_check' in q(VR, ok=False, db=MIG))
for n in (FA, FA, FB, FB, FC, FC): check(f'{n} runs clean on main (run twice)', run_file(MIG, n) == '')
check('after file c: a supplier in the category Vehicle Rental is taken', q(VR + ' returning 1', ok=False, db=MIG) == '1')
check('after file c: a category that is not on the list is still refused', 'vendors_category_check' in q(VR.replace("'Vehicle Rental'", "'Car Rental'"), ok=False, db=MIG))
q("delete from public.vendors where name = 'Sample rentals before'", db=MIG)
for n in (FC, FA, FB): check(f'{n} runs clean when file c goes first', run_file(MIG2, n) == '')

# ===== 2. the three builds are the same =====
ROLES = "array['public','anon','authenticated','service_role']"
FP = "select string_agg(p.proname||':'||md5(replace(pg_get_functiondef(p.oid), E'\\r','')), ' ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname not like '\\_\\_%'"
same = lambda sql: q(sql, db=NEW) == q(sql, db=MIG) == q(sql, db=MIG2)
def diff(sql):
    a, b, c = (set(q(sql, db=d).split(' | ')) for d in (NEW, MIG, MIG2)); return sorted((a ^ b) | (a ^ c))[:6]
check('every function is the same in the schema record and after the files, in either order', same(FP), diff(FP.replace("' '", "' | '")))
NEWF = ['_il_today','_is_rental','_rental_json','_rental_vendor_ok','_rentals_on','_wineries_on','rental_day_set','rental_review_post','rental_vehicle','rental_vehicle_archive','rental_vehicle_save','rentals_list']
CHANGED = ['_can_see','_section_of','set_setting','whoami']
now = dict(x.split(':') for x in q(FP6).split()); before = dict(x.split(':') for x in prod.split())
check('167 functions: the 155 on production and 12 new ones', len(now) == 167 and sorted(set(now) - set(before)) == NEWF, sorted(set(now) ^ set(before)))
check('production_fingerprints.txt (production after the files) is the line this build gives', q(FP6) == prod_after, [x for x in q(FP6).split() if x not in prod_after.split()][:6])
check('of the 155, only _can_see, _section_of, set_setting and whoami are changed', sorted(k for k in before if before[k] != now.get(k)) == CHANGED, sorted(k for k in before if before[k] != now.get(k)))
FPRIV = f"select string_agg(p.proname||'('||pg_get_function_identity_arguments(p.oid)||')='||(select string_agg(has_function_privilege(r, p.oid, 'execute')::text, ',' order by r) from unnest({ROLES}) r), ' | ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p where p.pronamespace='public'::regnamespace and p.proname not like '\\_\\_%'"
check('and every function can be called by the same roles in all three', same(FPRIV), diff(FPRIV))
COLS = "select string_agg(table_name||'.'||column_name||':'||ordinal_position||':'||data_type||':'||coalesce(column_default,'')||':'||is_nullable, ' | ' order by table_name, ordinal_position) from information_schema.columns where table_schema='public' and table_name not like '\\_\\_%'"
check('every table has the same columns in the same order in all three (rental_vehicles, rental_days, vendor_notes.vehicle_id)', same(COLS) and 'rental_days.status' in q(COLS) and 'vendor_notes.vehicle_id:' in q(COLS), diff(COLS))
CONS = "select string_agg(conrelid::regclass::text||'.'||conname||':'||pg_get_constraintdef(oid), ' | ' order by conrelid::regclass::text, conname) from pg_constraint where connamespace='public'::regnamespace and conrelid <> 0 and conrelid::regclass::text not like '%\\_\\_%'"
check('and the same constraints, with Vehicle Rental in the category list', same(CONS) and "'Vehicle Rental'::text" in q(CONS) and 'vendor_notes_vehicle_id_fkey' in q(CONS), diff(CONS))
IDX = "select string_agg(indexname||':'||indexdef, ' | ' order by indexname) from pg_indexes where schemaname='public' and tablename not like '\\_\\_%'"
check('and the same indexes', same(IDX) and 'rental_vehicles_vendor_idx' in q(IDX), diff(IDX))
TPRIV = f"select string_agg(c.relname||':'||c.relkind::text||':'||c.relrowsecurity::text||':'||(select string_agg(r||'='||coalesce((select string_agg(pr, '+' order by pr) filter (where case when c.relkind='S' then has_sequence_privilege(r, c.oid, pr) else has_table_privilege(r, c.oid, pr) end) from unnest(case when c.relkind='S' then array['select','update','usage'] else array['select','insert','update','delete','truncate','references','trigger'] end) pr), 'none'), ',' order by r) from unnest({ROLES}) r), ' | ' order by c.relname) from pg_class c where c.relnamespace='public'::regnamespace and c.relkind in ('r','S','v') and c.relname not like '\\_\\_%'"
check('and the same privileges and row security on every table', same(TPRIV), diff(TPRIV))
for db in (NEW, MIG, MIG2):
    check(f'{db}: the two rental tables are closed (row security on, no grant to anon or authenticated, no policy)',
        q("select bool_and(c.relrowsecurity) and not bool_or(has_table_privilege(r, c.oid, 'select,insert,update,delete,truncate,references,trigger')) from pg_class c, unnest(array['anon','authenticated']) r where c.relnamespace='public'::regnamespace and c.relname in ('rental_vehicles','rental_days')", db=db) == 't'
        and q("select count(*) from pg_policies where schemaname='public'", db=db) == '0')
    check(f'{db}: no new helper can be called from outside',
        q("select bool_or(has_function_privilege(r, p.oid, 'execute')) from pg_proc p, unnest(array['anon','authenticated','public']) r where p.pronamespace='public'::regnamespace and p.proname = any (array['_il_today','_is_rental','_rental_json','_rental_vendor_ok','_rentals_on','_wineries_on','_can_see','_section_of'])", db=db) == 'f')
    check(f'{db}: the six rental calls can be made by the app',
        q("select count(*) from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in ('rentals_list','rental_vehicle','rental_vehicle_save','rental_vehicle_archive','rental_day_set','rental_review_post') and has_function_privilege('anon', p.oid, 'execute')", db=db) == '6')
check('reading a rental table directly is refused', 'permission denied' in q("select count(*) from public.rental_vehicles", ok=False, role='anon'))
check('a rental helper called directly is refused', 'permission denied' in q("select public._rentals_on(null)", ok=False, role='anon'))

# ===== 3. people =====
def member(name, email, tok, extra=''):
    cols = "name,email,token_hash,status,role,license_no,phone" + (",member_type,sections,org,see_quotes,see_reviews,see_transport_reviews" if extra else '')
    vals = f"'{name}','{email}', public._hash('{tok}'),'approved','{ '' if extra else 'Licensed tour guide'}','{abs(hash(email))%1000}','05{abs(hash(email))%100000000:08d}'" + (f",'limited','{extra}','Sample {name}',true,false,true" if extra else '')
    q(f"insert into public.members ({cols}) values ({vals})")
member('Gil Guide', 'gil@test.il', G)
member('Org Sites', 'o1@test.il', O1, 'transport,sites'); member('Org Food', 'o2@test.il', O2, 'food')
member('Org Hotels', 'o3@test.il', O3, 'transport,hotels'); member('Org Guides', 'o4@test.il', O4, 'guides')
call = lambda fn, tok, *a: q(f"select public.{fn}('{tok}'{''.join(', '+x for x in a)})", ok=False)
callj = lambda fn, tok, *a: (lambda r: json.loads(r) if not r.startswith('ERR') else r)(call(fn, tok, *a))
def save_v(tok, d): return callj('rental_vehicle_save', tok, lit(d)+'::jsonb')
def ids(tok): return [v['id'] for v in callj('vendors_list', tok)]
def rl(tok): return callj('rentals_list', tok)
setting = lambda k, v: q(f"select public.set_setting('{A}', '{k}', '{v}')")

# ===== 4. rentals while closed (rentals_for = admin, the default) =====
me = callj('whoami', F); ad = callj('whoami', A)
check('closed: whoami tells a member rentals are off, and Eretz Israel Tours that they are on, for him only', me['rentals'] is False and me['rentals_for'] == '' and ad['rentals'] is True and ad['rentals_for'] == 'admin')
vs = lambda d: callj('vendor_save', A, lit(dict({"active":"Active","currency":"ILS","priceBasis":"Per day"}, **d))+'::jsonb')['vendor']['id']
RC = vs({"name":"Sample Desert Rentals","category":"Vehicle Rental","phone":"050-000-7777","region":"Negev & Arava"})
RP = vs({"name":"Sample Pending Rentals","category":"Vehicle Rental"}); q(f"select set_config('app.admin','on',false); update public.vendors set review_status='pending' where id='{RP}'")
RH = vs({"name":"Sample Hidden Rentals","category":"Vehicle Rental"}); q(f"update public.vendors set hidden=true where id='{RH}'")
RT = vs({"name":"Sample Bus and Rentals","category":"Transport","also_categories":"Vehicle Rental"})
TB = q("select public.__id('T')"); W = q("select public.__id('W')")
check('closed: Eretz Israel Tours sees the rental companies; a guide and an organisation do not see one whose category is Vehicle Rental',
    RC in ids(A) and RC not in ids(F) and RC not in ids(O1) and RT in ids(F))
check('closed: opening one is refused to a guide', 'not available' in call('vendor_detail', F, f"'{RC}'"))
BASE = {"vendor_id":RC,"licence_type":"eshkol","make_model":"Sample Land Cruiser","year":"2022","colour":"White","passenger_seats":"7","pickup_location":"Sample industrial zone","cost_per_day":"850","vat":"plus_vat","km_included_per_day":"200","cost_per_extra_km":"1.80","price_source":"Their price list","price_checked_on":"2026-10-09","other_terms":"Deposit by card.","renter_notes":"Call the evening before."}
V1 = save_v(A, BASE); check('closed: Eretz Israel Tours adds a vehicle', isinstance(V1, dict) and V1['cost_per_day'] == 850 and V1['by'] == 'Eretz Israel Tours', V1)
V1 = V1['id']
V2 = save_v(A, dict(BASE, licence_type="midbari", make_model="Sample Wrangler", passenger_seats="4", cost_per_day="600", is_agent=True))['id']
V3 = save_v(A, dict(BASE, vendor_id=RP, make_model="Sample Pending Car"))['id']
V4 = save_v(A, dict(BASE, vendor_id=RH, make_model="Sample Hidden Car"))['id']
V6 = save_v(A, dict(BASE, vendor_id=RT, make_model="Sample Also-offers Car"))['id']
check('a price without its source is refused (E4)', 'where the price is from' in str(save_v(A, dict(BASE, price_source=""))))
check('a price without the date it was checked is refused (E4)', 'date the price was checked' in str(save_v(A, dict(BASE, price_checked_on=""))))
check('a vehicle on a supplier that is not a rental company is refused', 'only to a supplier in Eshkol / Midbari rental' in str(save_v(A, dict(BASE, vendor_id=TB))))
check('bad licence type, year and seats are refused', 'Eshkol, Midbari or both' in str(save_v(A, dict(BASE, licence_type="jeep"))) and 'year the car' in str(save_v(A, dict(BASE, year="22"))) and 'number from 1 to 60' in str(save_v(A, dict(BASE, passenger_seats="99"))))
check('closed: a guide gets no vehicles and cannot add one', rl(F) == [] and 'not open yet' in str(save_v(F, BASE)))
check('closed: a guide cannot mark a day', 'not available' in call('rental_day_set', F, f"'{V1}'::uuid", "public._il_today()+1", "'booked'"))
check('closed: an organisation cannot add a supplier in Vehicle Rental', 'sections you have access to' in call('vendor_save', O1, lit({"name":"Org rentals","category":"Vehicle Rental"})+'::jsonb'))

# ===== 5. rentals open =====
setting('rentals_for', 'all')
check('open: whoami says rentals are on for a guide and an organisation', callj('whoami', F)['rentals'] is True and callj('whoami', O1)['rentals'] is True)
f = {v['id']: v for v in rl(F)}
check('open: a guide sees the vehicles of the approved, visible rental companies only (none of the pending or hidden one)', set(f) == {V1, V2, V6}, sorted(v['make_model'] for v in f.values()))
check('open: a guide sees the agent day price (C5)', f[V2]['cost_per_day'] == 600 and f[V2]['is_agent'] is True)
check('open: a hidden or pending supplier\'s vehicle cannot be opened by a guide', 'not available' in call('rental_vehicle', F, f"'{V3}'::uuid") and 'not available' in call('rental_vehicle', F, f"'{V4}'::uuid"))
check('open: Eretz Israel Tours sees them all', {V1, V2, V3, V4, V6} <= {v['id'] for v in rl(A)})
o = {v['id']: v for v in rl(O1)}; o_raw = call('rentals_list', O1)
check('open: an organisation with Transportation sees the vehicles with the retail day price', set(o) == {V1, V2, V6} and o[V1]['cost_per_day'] == 850)
check('open: an organisation never receives the agent day price (C3): no price, no extra-km price, no source, flagged hidden',
    o[V2]['cost_per_day'] is None and o[V2]['cost_per_extra_km'] is None and o[V2]['price_source'] == '' and o[V2]['price_hidden'] is True and o[V2]['is_agent'] is False and '600' not in o_raw)
check('open: nor through the vehicle page', '600' not in call('rental_vehicle', O1, f"'{V2}'::uuid"))
check('open: an organisation without Transportation sees no rental company and no vehicle', rl(O4) == [] and RC not in ids(O4) and 'not available' in call('rental_vehicle', O4, f"'{V1}'::uuid"))
check('open: an organisation with Transportation sees the rental company', RC in ids(O1) and RC in ids(O3))
# the calendar
r = callj('rental_day_set', F, f"'{V1}'::uuid", "public._il_today()+1", "'booked'")
check('a guide marks tomorrow booked; it carries his name, not his email', r['status'] == 'booked' and r['last']['by'] == 'Fay Full' and '@' not in json.dumps(r))
check('the list shows tomorrow booked', {v['id']: v for v in rl(G)}[V1]['tomorrow'] == 'booked' and {v['id']: v for v in rl(G)}[V2]['tomorrow'] == 'unknown')
call('rental_day_set', O1, f"'{V1}'::uuid", "public._il_today()+3", "'free'")
d = callj('rental_vehicle', G, f"'{V1}'::uuid")
check('an organisation marks a day free; the page shows who changed the calendar last, by name', d['last']['by'] == 'Org Sites' and {x['status'] for x in d['days']} == {'booked', 'free'})
call('rental_day_set', G, f"'{V1}'::uuid", "public._il_today()+3", "'unknown'")
d = callj('rental_vehicle', G, f"'{V1}'::uuid")
check('a day set back to not known leaves the calendar, and the change is still the last one recorded', len(d['days']) == 1 and d['last']['by'] == 'Gil Guide')
check('no email in anything a member is sent about vehicles', '@' not in call('rentals_list', F) + call('rentals_list', O1) + call('rental_vehicle', O1, f"'{V1}'::uuid"))
check('a day state that is not free, booked or not known is refused', 'free, booked or not known' in call('rental_day_set', F, f"'{V1}'::uuid", "public._il_today()+2", "'maybe'"))
check('a day more than two years ahead, or two months back, is refused', 'two years ahead' in call('rental_day_set', F, f"'{V1}'::uuid", "public._il_today()+800", "'free'") and 'two years ahead' in call('rental_day_set', F, f"'{V1}'::uuid", "public._il_today()-60", "'free'"))
check('the calendar holds no client, trip or note: a day row has only its vehicle, day, state, who and when', q("select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns where table_name='rental_days'") == 'vehicle_id,day,status,set_by,set_at')
# who changes a vehicle
check('a guide cannot change a vehicle Eretz Israel Tours added', 'Only the member who added' in str(save_v(F, dict(BASE, id=V1))))
V5 = save_v(F, dict(BASE, make_model="Sample Defender", cost_per_day="950", is_agent=True))
check('a guide adds his own vehicle (an agent price is allowed for a full member)', isinstance(V5, dict) and V5['by'] == 'Fay Full' and V5['is_agent'] is True and V5['mine'] is True, V5)
V5 = V5['id']
check('and changes it', save_v(F, dict(BASE, id=V5, make_model="Sample Defender 110", cost_per_day="990", is_agent=True))['make_model'] == 'Sample Defender 110')
check('another guide cannot', 'Only the member who added' in str(save_v(G, dict(BASE, id=V5))))
a = callj('rental_vehicle_archive', F, f"'{V5}'::uuid", 'true')
check('the guide archives it; it leaves colleagues\' lists, and he cannot bring it back', a['archived'] is True and V5 not in [v['id'] for v in rl(G)] and 'not available' in call('rental_vehicle_archive', F, f"'{V5}'::uuid", 'false'))
check('Eretz Israel Tours brings it back; nothing was removed', callj('rental_vehicle_archive', A, f"'{V5}'::uuid", 'false')['archived'] is False and q("select count(*) from public.rental_vehicles") == '6')
callj('rental_vehicle_archive', A, f"'{V5}'::uuid", 'true')
check('an archived vehicle cannot be marked or reviewed', 'not available' in call('rental_day_set', F, f"'{V5}'::uuid", "public._il_today()+1", "'free'") and 'not available' in call('rental_review_post', F, f"'{V5}'::uuid", "'x'", "'5'", 'false'))
OV = save_v(O1, dict(BASE, make_model="Sample Org Car", cost_per_day="700", is_agent=True))
check('an organisation adds a vehicle, and it is never stored as an agent price (D-15)', isinstance(OV, dict) and q(f"select is_agent from public.rental_vehicles where id='{OV['id']}'") == 'f', OV)
check('an organisation cannot add a vehicle to a pending rental company', 'approved this supplier' in str(save_v(O1, dict(BASE, vendor_id=RP))))
# a private-price supplier
q(f"update public.vendors set prices_private = true where id = '{RC}'")
f = {v['id']: v for v in rl(F)}
check('a private-price supplier sends no vehicle price to colleagues (D4), and Eretz Israel Tours still sees it',
    f[V1]['cost_per_day'] is None and f[V1]['price_hidden'] is True and {v['id']: v for v in rl(A)}[V1]['cost_per_day'] == 850)
check('but the member who added a vehicle still sees its price', {v['id']: v for v in rl(O1)}[OV['id']]['cost_per_day'] == 700)
q(f"update public.vendors set prices_private = false where id = '{RC}'")
# reviews
rv = callj('rental_review_post', F, f"'{V1}'::uuid", "'Sample review: clean and on time.'", "'5'", 'false')
dt = callj('vendor_detail', G, f"'{RC}'")
n = [x for x in dt['notes'] if 'Sample review' in x['body']]
check('a review can name the vehicle; colleagues read it on the supplier with the vehicle named', rv.get('status') == 'approved' and len(n) == 1 and n[0]['vehicle_id'] == V1 and n[0]['author'] == 'Fay Full', (rv, n))
check('a review naming a vehicle of a pending supplier is refused', 'not available' in call('rental_review_post', F, f"'{V3}'::uuid", "'x'", "'5'", 'false'))
check('an empty review is refused', 'Write your review' in call('rental_review_post', F, f"'{V1}'::uuid", "'  '", "'5'", 'false'))
check('a private review naming a vehicle stays private', callj('rental_review_post', G, f"'{V2}'::uuid", "'Sample private note.'", "''", 'true')['private'] is True
    and not [x for x in callj('vendor_detail', F, f"'{RC}'")['notes'] if 'Sample private note' in x['body']])
# closed again
setting('rentals_for', 'admin')
check('closed again: a guide gets nothing and the rental company is hidden again; the vehicles and days are kept',
    rl(F) == [] and RC not in ids(F) and q("select count(*) from public.rental_vehicles") == '7' and q("select count(*) from public.rental_days") == '2')
check('closed again: a supplier that only also offers rentals stays visible, without its vehicles', RT in ids(F) and 'not available' in call('rental_vehicle', F, f"'{V6}'::uuid"))
check('the setting takes only admin or all', 'Unknown setting' in q(f"select public.set_setting('{A}', 'rentals_for', 'receive')", ok=False) and 'Only Eretz Israel Tours' in q(f"select public.set_setting('{F}', 'rentals_for', 'all')", ok=False))

# ===== 6. wineries under Restaurant and under Attraction / Site (D-43) =====
seen = lambda: {k: W in ids(t) for k, t in (('sites', O1), ('food', O2), ('hotels', O3), ('guides', O4), ('guide', F))}
check('wineries closed: an organisation sees wineries with restaurants only, as before', seen() == {'sites': False, 'food': True, 'hotels': False, 'guides': False, 'guide': True}, seen())
check('wineries closed: whoami says so', callj('whoami', O1)['wineries'] is False and callj('whoami', A)['wineries'] is True and callj('whoami', A)['wineries_for'] == 'admin')
setting('wineries_for', 'all')
check('wineries open: an organisation that sees sites now sees wineries; restaurants still do; neither, still not', seen() == {'sites': True, 'food': True, 'hotels': False, 'guides': False, 'guide': True}, seen())
check('wineries open: the organisation with sites opens a winery', callj('vendor_detail', O1, f"'{W}'").get('notes') is not None)
check('wineries open: the stored category stays Winery', q(f"select category from public.vendors where id='{W}'") == 'Winery')
check('wineries open: a restaurant is still not shown to an organisation with sites only', q("select public.__id('R')") not in ids(O1))
setting('wineries_for', 'admin')
check('wineries closed again: back as before', seen() == {'sites': False, 'food': True, 'hotels': False, 'guides': False, 'guide': True})
check('the wineries setting takes only admin or all', 'Unknown setting' in q(f"select public.set_setting('{A}', 'wineries_for', 'receive')", ok=False))

print(f"\n{len(res)} checks, {sum(1 for _, ok in res if not ok)} failed")
