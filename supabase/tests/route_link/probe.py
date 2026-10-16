import json, os, re, subprocess
NEW, MIG = 'eitv_rl_new', 'eitv_rl_mig'
HERE = os.path.dirname(os.path.abspath(__file__))
MDIR = os.path.join(HERE, '..', '..', 'migrations')
FAF, FRL = '2026-10-15_activity_feed.sql', '2026-10-16_hike_route_link.sql'
A='ADMINTOKEN0000000000000000'; F='FULLTOKEN00000000000000000'; G='GUIDETWOTOKEN0000000000000'
def q(sql, ok=True, role=None, db=NEW):
    pre = f"set role {role}; " if role else ''
    out = subprocess.run(['psql','-qAt','-v','ON_ERROR_STOP=1','-d',db,'-c',pre+sql],capture_output=True,text=True)
    if ok and out.returncode: raise SystemExit('SQL failed: '+sql[:400]+'\n'+out.stderr)
    return out.stdout.strip() if out.returncode == 0 else 'ERR: '+out.stderr.strip().splitlines()[0]
def j(sql, **k): return json.loads(q(sql, **k))
def run_file(db, name):
    out = subprocess.run(['psql','-q','-v','ON_ERROR_STOP=1','-d',db,'-f',os.path.join(MDIR,name)],capture_output=True,text=True)
    return '' if out.returncode == 0 and 'ERROR' not in out.stderr else 'ERR: '+out.stderr.strip()[:300]
def lit(o): return "'" + json.dumps(o).replace("'", "''") + "'"
res = []
def check(name, cond, detail=''):
    res.append((name, bool(cond))); print(('PASS ' if cond else 'FAIL ') + name + ((' :: ' + str(detail)[:400]) if not cond else ''))

# ===== 1. the file, and the two builds =====
src = open(os.path.join(MDIR, FRL)).read()
code = lambda s: '\n'.join(l.split('--')[0] for l in s.splitlines())
check('the file removes nothing: no DELETE, DROP or TRUNCATE in what it runs (so it can go through the connector)', not re.search(r'\b(delete|drop|truncate)\b', code(src), re.I))
FP6 = "select string_agg(p.proname||':'||left(md5(replace(pg_get_functiondef(p.oid), E'\\r','')),6), ' ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname not like '\\_\\_%'"
fpl = lambda t: [l for l in t.splitlines() if l and not l.startswith('#')][0]
rec = fpl(subprocess.run(['git','show','d9ef8c0:supabase/tests/production_fingerprints.txt'],capture_output=True,text=True,cwd=HERE).stdout)
check('before: the schema record from main gives the functions in production_fingerprints.txt of main', q(FP6, db=MIG) == rec, [x for x in q(FP6, db=MIG).split() if x not in rec.split()][:6])
# production holds activity_feed without the comment lines inside the function that the file has (it went through the connector)
af = open(os.path.join(MDIR, FAF)).read(); af = '\n'.join(l for l in af.splitlines() if not re.match(r'^\s+--', l))
out = subprocess.run(['psql','-q','-v','ON_ERROR_STOP=1','-d',MIG],input=af,capture_output=True,text=True)
check(f'{FAF} runs clean on it (as production got it: without the comment lines inside the function)', out.returncode == 0 and 'ERROR' not in out.stderr, out.stderr[:300])
prod_before = ' '.join(sorted(rec.split() + ['activity_feed:2458b7'], key=lambda x: x.split(':')[0]))
check('with activity_feed: exactly production before D-53 (168 functions, activity_feed 2458b7, seen on production 16 Oct)', q(FP6, db=MIG) == prod_before and len(prod_before.split()) == 168)
for i in (1, 2): check(f'{FRL} runs clean (run {i})', run_file(MIG, FRL) == '')
ROLES = "array['public','anon','authenticated','service_role']"
FP = FP6.replace("left(md5(replace(pg_get_functiondef(p.oid), E'\\r','')),6)", "md5(replace(pg_get_functiondef(p.oid), E'\\r',''))")
same = lambda sql: q(sql, db=NEW) == q(sql, db=MIG)
def diff(sql):
    a, b = (set(q(sql, db=d).split(' | ')) for d in (NEW, MIG)); return sorted(a ^ b)[:6]
check('every function is the same in the schema record and after the files', same(FP), diff(FP.replace("' '", "' | '")))
now = dict(x.split(':') for x in q(FP6).split()); before = dict(x.split(':') for x in prod_before.split())
check('170 functions: the 168 on production and hike_route_link and _hike_route_public; none of the 168 changed',
    len(now) == 170 and sorted(set(now) - set(before)) == ['_hike_route_public', 'hike_route_link'] and all(now[k] == before[k] for k in before), sorted(set(now) ^ set(before)))
prod_after = fpl(open(os.path.join(HERE, '..', 'production_fingerprints.txt')).read())
check('production_fingerprints.txt is the line this build gives', q(FP6) == prod_after, [x for x in q(FP6).split() if x not in prod_after.split()][:6])
FPRIV = f"select string_agg(p.proname||'('||pg_get_function_identity_arguments(p.oid)||')='||(select string_agg(has_function_privilege(r, p.oid, 'execute')::text, ',' order by r) from unnest({ROLES}) r), ' | ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p where p.pronamespace='public'::regnamespace and p.proname not like '\\_\\_%'"
check('every function can be called by the same roles in both', same(FPRIV), diff(FPRIV))
COLS = "select string_agg(table_name||'.'||column_name||':'||ordinal_position||':'||data_type||':'||coalesce(column_default,'')||':'||is_nullable, ' | ' order by table_name, ordinal_position) from information_schema.columns where table_schema='public' and table_name not like '\\_\\_%'"
check('every table has the same columns in the same order in both, hike_gpx.link_code last', same(COLS) and 'hike_gpx.link_code:9:text::YES' in q(COLS), diff(COLS))
CONS = "select string_agg(conrelid::regclass::text||'.'||conname||':'||pg_get_constraintdef(oid), ' | ' order by conrelid::regclass::text, conname) from pg_constraint where connamespace='public'::regnamespace and conrelid <> 0 and conrelid::regclass::text not like '%\\_\\_%'"
check('and the same constraints, the code check among them', same(CONS) and 'hike_gpx_link_code_check' in q(CONS), diff(CONS))
IDX = "select string_agg(indexname||':'||indexdef, ' | ' order by indexname) from pg_indexes where schemaname='public' and tablename not like '\\_\\_%'"
check('and the same indexes, the unique code index among them', same(IDX) and 'hike_gpx_link_code_idx' in q(IDX), diff(IDX))
TPRIV = f"select string_agg(c.relname||':'||c.relkind::text||':'||c.relrowsecurity::text||':'||(select string_agg(r||'='||coalesce((select string_agg(pr, '+' order by pr) filter (where has_table_privilege(r, c.oid, pr)) from unnest(array['select','insert','update','delete','truncate','references','trigger']) pr), 'none'), ',' order by r) from unnest({ROLES}) r), ' | ' order by c.relname) from pg_class c where c.relnamespace='public'::regnamespace and c.relkind in ('r','v') and c.relname not like '\\_\\_%'"
check('and the same privileges and row security on every table', same(TPRIV), diff(TPRIV))
GR = lambda fn: q(f"select string_agg(r||'='||has_function_privilege(r, '{fn}'::regprocedure, 'execute')::text, ',' order by r) from unnest({ROLES}) r")
check('hike_route_link: the app can call it (anon, authenticated), PUBLIC cannot', GR('public.hike_route_link(text,uuid)') == 'anon=true,authenticated=true,public=false,service_role=false', GR('public.hike_route_link(text,uuid)'))
check('_hike_route_public: only the service role (the edge function) can call it', GR('public._hike_route_public(text)') == 'anon=false,authenticated=false,public=false,service_role=true', GR('public._hike_route_public(text)'))
check('hike_route_link is security definer with an empty search path', q("select prosecdef and proconfig = array['search_path=\"\"'] from pg_proc where proname='hike_route_link'") == 't')
check('0 policies; no table can be read by anon or authenticated',
    q("select count(*) from pg_policies where schemaname='public'") == '0'
    and q("select bool_or(has_table_privilege(r, c.oid, 'select,insert,update,delete')) from pg_class c, unnest(array['anon','authenticated']) r where c.relnamespace='public'::regnamespace and c.relkind='r'") == 'f')

# ===== 2. people and hikes =====
q(f"insert into public.members (name,email,token_hash,status,role,license_no,phone) values ('Gil Guide','gil@test.il', public._hash('{G}'),'approved','Licensed tour guide','222','0523334455')")
L = j("select public.request_access_org('Sample Org','org@sample.test','050-000-0000','','2026-10-03d','Sample Organisation','Sample: I run the trips for a sample organisation, six years in the role.')")['token']
org = next(m for m in j(f"select public.members_list('{A}')") if m['email']=='org@sample.test')
q(f"select public.member_decide('{A}', '{org['id']}', 'approved')")
BASE = dict(name='Sample Wadi', region='Dead Sea & Judean Desert', official=True, distance_km='5', hours_from='3', hours_to='4', start_place='Sample trailhead', is_loop=False, end_place='Sample road', notes='Sample.', source='walked')
HEAD = '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle">'
GPX = HEAD + '<trk><trkseg><trkpt lat="31.5" lon="35.4"/><trkpt lat="31.51" lon="35.41"/></trkseg></trk></gpx>'
GPX2 = HEAD + '<trk><trkseg><trkpt lat="31.6" lon="35.4"/><trkpt lat="31.61" lon="35.41"/><trkpt lat="31.62" lon="35.42"/></trkseg></trk></gpx>'
save = lambda tok, h: j(f"select public.hike_save('{tok}', {lit(h)}::jsonb)")
link = lambda tok, hid: q(f"select public.hike_route_link('{tok}', '{hid}')", ok=False, role='anon')
sq = lambda t: "'" + t.replace("'", "''") + "'"
pub = lambda c: q(f"select coalesce(public._hike_route_public({sq(c)}), 'NULL')", role='service_role')
withr = save(A, dict(BASE, name='Sample With Route', gpx=GPX))
nor = save(A, dict(BASE, name='Sample No Route'))
check('hikes off for colleagues: a guide is refused', 'not open yet' in link(F, withr['id']), link(F, withr['id']))
q(f"select public.set_setting('{A}','hikes_for','all')")
pend = save(F, dict(BASE, name='Sample Waiting', gpx=GPX))
check('Eretz Israel Tours\' hikes are approved, the guide\'s waits', withr['review_status']=='approved' and nor['review_status']=='approved' and pend['review_status']=='pending')
check('a wrong link is refused, and nothing is made', 'not active' in link('NOSUCHTOKEN0000000000000000', withr['id']) and q("select count(*) from public.hike_gpx where link_code is not null")=='0')
check('an empty link is refused', 'not active' in link('', withr['id']))
P = j("select public.request_access(p_name => 'Sample Pending', p_email => 'pending@sample.test', p_role => 'Licensed tour guide', p_license => '333', p_phone => '', p_note => '', p_terms => '2026-10-03d')")['token']
check('a member whose request is still waiting is refused', 'not active' in link(P, withr['id']), link(P, withr['id']))
check('a hike that does not exist is refused', 'not available' in link(F, '00000000-0000-0000-0000-000000000000'))
check('another member\'s waiting hike: a guide who cannot see it is refused', 'not available' in link(G, pend['id']) and 'not available' in link(L, pend['id']))
check('a waiting hike is refused even for its writer (it opens in Mapeak once approved)', 'once Eretz Israel Tours has approved' in link(F, pend['id']) and 'once Eretz Israel Tours has approved' in link(A, pend['id']))
check('a hike with no route file is refused', 'no route file' in link(F, nor['id']))
check('nothing was made by the refused tries', q("select count(*) from public.hike_gpx where link_code is not null")=='0')
c1 = link(F, withr['id'])
check('a guide gets a code: 32 letters of a web address', re.fullmatch(r'[A-Za-z0-9_-]{32}', c1) is not None, c1)
check('the code is the same on the next call, for an organisation and for Eretz Israel Tours', link(F, withr['id']) == c1 == link(L, withr['id']) == link(A, withr['id']))
check('the route file itself is not changed by making the code (updated_at, body, who)', q(f"select body = {sq(GPX)} and updated_at = created_at and added_by = 'owner@test.il' from public.hike_gpx where hike_id='{withr['id']}'") == 't')
check('the hike is not changed by it (its version stays)', next(h for h in j(f"select public.hikes_list('{A}')") if h['id']==withr['id'])['updated_at'] == withr['updated_at'])
check('the public lookup gives exactly the GPX, nothing else', pub(c1) == GPX, pub(c1))
check('a wrong code gives nothing', pub('A'*32) == 'NULL' and pub(c1[:-1] + ('A' if c1[-1] != 'A' else 'B')) == 'NULL')
check('a code that is not 32 letters gives nothing (no pattern search)', pub('%') == 'NULL' and pub('') == 'NULL' and pub(c1 + 'x') == 'NULL' and pub(c1[:31]) == 'NULL')
check('the public lookup cannot be called by anon or authenticated', all('permission denied' in q(f"select public._hike_route_public('{c1}')", ok=False, role=r) for r in ('anon', 'authenticated')))
check('the code cannot be read from the table by anon', 'permission denied' in q("select link_code from public.hike_gpx", ok=False, role='anon'))
check('hike_detail and hike_gpx do not hand out the code', c1 not in q(f"select public.hike_detail('{F}', '{withr['id']}')::text") and c1 not in q(f"select public.hike_gpx('{F}', '{withr['id']}')::text") and c1 not in q(f"select public.hikes_list('{A}')::text"))
other = save(A, dict(BASE, name='Sample Second Route', gpx=GPX2))
c2 = link(F, other['id'])
check('another hike gets another code, and each code gives its own route', c2 != c1 and pub(c2) == GPX2 and pub(c1) == GPX)
# replaced, removed, put back
save(A, dict(BASE, id=withr['id'], name='Sample With Route', gpx=GPX2))
check('a replaced route file keeps its code, and the code gives the new route', link(F, withr['id']) == c1 and pub(c1) == GPX2)
save(A, dict(BASE, id=withr['id'], name='Sample With Route', gpx_remove=True))
check('a removed route file: the public lookup gives nothing', pub(c1) == 'NULL')
check('a removed route file: asking for the code is refused', 'no route file' in link(F, withr['id']))
save(A, dict(BASE, id=withr['id'], name='Sample With Route', gpx=GPX))
check('a route put back on the same hike works under the same code again', link(F, withr['id']) == c1 and pub(c1) == GPX)
# taken off the list
seen = next(h for h in j(f"select public.hikes_list('{A}')") if h['id']==other['id'])['updated_at']
q(f"select public.hike_decide('{A}', '{other['id']}', false)")
check('a hike taken off the list: the public lookup gives nothing, and the code is refused, for Eretz Israel Tours too', pub(c2) == 'NULL' and 'not available' in link(F, other['id']) and 'once Eretz Israel Tours has approved' in link(A, other['id']))
seen = next(h for h in j(f"select public.hikes_list('{A}')") if h['id']==other['id'])['updated_at']
q(f"select public.hike_decide('{A}', '{other['id']}', true, '{seen}')")
check('put back on the list: the same code works again', pub(c2) == GPX2 and link(F, other['id']) == c2)
# a waiting hike, once approved
seen = next(h for h in j(f"select public.hikes_list('{A}')") if h['id']==pend['id'])['updated_at']
q(f"select public.hike_decide('{A}', '{pend['id']}', true, '{seen}')")
c3 = link(G, pend['id'])
check('the guide\'s hike, once approved, opens for another guide too', re.fullmatch(r'[A-Za-z0-9_-]{32}', c3) is not None and pub(c3) == GPX)
check('the code check in the table refuses anything but 32 letters', 'hike_gpx_link_code_check' in q(f"update public.hike_gpx set link_code = 'short' where hike_id='{withr['id']}'", ok=False))
check('two route files cannot share a code', 'hike_gpx_link_code_idx' in q(f"update public.hike_gpx set link_code = '{c1}' where hike_id='{other['id']}'", ok=False))
check('hikes switched back to Eretz Israel Tours only: a guide is refused again', (q(f"select public.set_setting('{A}','hikes_for','admin')") or True) and 'not open yet' in link(F, withr['id']))

print(f"\n{len(res)} checks, {sum(1 for _, ok in res if not ok)} failed")
