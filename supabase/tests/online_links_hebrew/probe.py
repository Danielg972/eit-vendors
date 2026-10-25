# D-62 / D-63: checks on a local copy, through the real functions, as Eretz Israel Tours, a guide (full member) and an
# organisation (limited member), on the sample data of ../limited_members/seed.sql. Prints PASS / FAIL lines and a total.
#   python3 probe.py <database built by run.sh>
import json, subprocess, sys
DB = sys.argv[1] if len(sys.argv) > 1 else 'eitv_olh_test'
A = 'ADMINTOKEN0000000000000000'; F = 'FULLTOKEN00000000000000000'
def q(sql, ok=True, role=None, db=None):
    pre = f"set role {role}; " if role else ''
    out = subprocess.run(['psql', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', db or DB, '-c', pre + sql], capture_output=True, text=True)
    if ok and out.returncode: raise SystemExit('SQL failed: ' + sql[:300] + '\n' + out.stderr)
    return out.stdout.strip() if out.returncode == 0 else 'ERR: ' + out.stderr.strip().splitlines()[0]
def j(sql): return json.loads(q(sql))
def lit(o): return "'" + json.dumps(o, ensure_ascii=False).replace("'", "''") + "'"
def txt(t): return "E'" + t.replace('\\', '\\\\').replace("'", "''").replace('\n', '\\n') + "'"
res = []
def check(name, cond, detail=''):
    res.append((name, bool(cond))); print(('PASS ' if cond else 'FAIL ') + name + ((' :: ' + str(detail)[:300]) if not cond else ''))
ID = dict(l.split('|') for l in q("select k, id from public.__ids").splitlines())
def row(tok, vid): return next((v for v in j(f"select public.vendors_list('{tok}')") if v['id'] == vid), None)
def save(tok, data, reason=''): return j(f"select public.vendor_save('{tok}', {lit(data)}::jsonb, {txt(reason)})")
def db_row(vid): return j(f"select row_to_json(v) from public.vendors v where id = '{vid}'")

# an organisation, the way limited_members/probe.py makes one
L = j("select public.request_access_org('Sample Org','org@sample.test','050-000-0000','','2026-10-03b','Sample Yeshiva','Trips coordinator for a sample yeshiva, invented for this check.')")['token']
oid = next(m['id'] for m in j(f"select public.members_list('{A}')") if m['email'] == 'org@sample.test')
q(f"select public.member_decide('{A}', '{oid}', 'approved')")

LINKS = 'https://www.instagram.com/sample_place\nhttps://www.tripadvisor.com/Attraction_Review-Sample.html\nhttps://maps.app.goo.gl/SamplePin'
H = ID['H']   # the sample hotel: an organisation sees hotels, never its agent price

# --- the columns exist, start empty, and are closed like the rest
cols = q("select string_agg(column_name||':'||data_type||':'||column_default||':'||is_nullable, ' ' order by column_name) from information_schema.columns where table_schema='public' and table_name='vendors' and column_name in ('links','name_he','contactPerson_he')")
check('three new columns, text, empty by default, not null', cols == "contactPerson_he:text:''::text:NO links:text:''::text:NO name_he:text:''::text:NO", cols)
check('existing suppliers start with the three fields empty', q("select count(*) from public.vendors where links <> '' or name_he <> '' or \"contactPerson_he\" <> ''") == '0')
check('no table grants to anon or authenticated, no policies', q("select count(*) from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated')") == '0' and q("select count(*) from pg_policies where schemaname='public'") == '0')
check('_links_clean is closed to anon', 'permission denied' in q("select public._links_clean('https://a.example', true)", ok=False, role='anon'))
check('_links_clean is closed to authenticated', 'permission denied' in q("select public._links_clean('https://a.example', true)", ok=False, role='authenticated'))
check('the app can still call vendor_save and vendors_list as anon (with a token)', q(f"select json_array_length(public.vendors_list('{A}'))", role='anon').isdigit())

# --- Eretz Israel Tours saves links and the Hebrew fields; they round-trip
cur = row(A, H)
r = save(A, dict(cur, links='instagram.com/sample_place\n' + LINKS + '\nhttps://maps.app.goo.gl/SamplePin', name_he='מלון לדוגמה', contactPerson_he='דסק קבוצות'))
v = r['vendor']
check('admin: links cleaned (https added, repeats dropped, one per line)', v['links'] == 'https://instagram.com/sample_place\n' + LINKS, v['links'])
check('admin: Hebrew name and contact saved', v['name_he'] == 'מלון לדוגמה' and v['contactPerson_he'] == 'דסק קבוצות', v)
check('admin: saved straight away, no request', r['request'] is False)
q(f"update public.vendors set links = {txt(LINKS)} where id = '{H}'")

# --- URL cleaning: bad schemes refused through the real function, for every kind of member
for bad in ['javascript:alert(1)', 'JAVASCRIPT:alert(1)', 'data:text/html;base64,PHNjcmlwdD4=', 'vbscript:msgbox(1)', 'file:///etc/passwd', 'ftp://sample.example/x',
            'mailto:a@sample.example', 'https://sample.example/"onmouseover=x', "https://sample.example/'x", 'https://sample.example/<b>', 'https://', 'hello world', 'https://localhost/x']:
    for tok, who in ((A, 'admin'), (F, 'guide'), (L, 'organisation')):
        out = q(f"select public.vendor_save('{tok}', {lit(dict(row(tok, H), links=bad))}::jsonb, ''::text)", ok=False)
        check(f'{who}: "{bad[:28]}" refused', out.startswith('ERR') and ('Only web links' in out or 'does not look right' in out), out)
check('after all the refusals the links are as they were', db_row(H)['links'] == LINKS)
out = q(f"select public.vendor_save('{A}', {lit(dict(row(A, H), links=chr(10).join(f'https://s{i}.example/' for i in range(11))))}::jsonb, '')", ok=False)
check('11 links refused', 'At most 10 online links' in out, out)
out = q(f"select public.vendor_save('{A}', {lit(dict(row(A, H), links=chr(10).join(f'https://s{i}.example/' for i in range(10))))}::jsonb, '')")
check('10 links saved', db_row(H)['links'].count('\n') == 9)
check('a link over 500 characters refused', 'does not look right' in q(f"select public.vendor_save('{A}', {lit(dict(row(A, H), links='https://s.example/' + 'a' * 500))}::jsonb, '')", ok=False))
check('the table refuses a non-web link written past the functions', 'vendors_links_check' in q(f"update public.vendors set links = 'javascript:alert(1)' where id = '{H}'", ok=False))
check('the table refuses a Hebrew name over 200 characters', 'vendors_hebrew_check' in q(f"update public.vendors set name_he = repeat('א', 201) where id = '{H}'", ok=False))
q(f"update public.vendors set links = {txt(LINKS)} where id = '{H}'")
check('an empty links box clears the links', save(A, dict(row(A, H), links=''))['vendor']['links'] == '')
q(f"update public.vendors set links = {txt(LINKS)} where id = '{H}'")
old = {k: x for k, x in row(A, H).items() if k not in ('links', 'name_he', 'contactPerson_he')}
check('an older page that sends none of the three keys keeps them', (lambda v: v['links'] == LINKS and v['name_he'] == 'מלון לדוגמה')(save(A, old, '')['vendor']))

# --- a guide (full member): links are open, the Hebrew name and contact are locked (E3)
g = row(F, H)
check('guide: sees links, Hebrew name and contact', g['links'] == LINKS and g['name_he'] == 'מלון לדוגמה' and g['contactPerson_he'] == 'דסק קבוצות', g)
r = save(F, dict(g, links=LINKS + '\nhttps://www.facebook.com/samplehotel'))
check('guide: a link change saves straight away (not locked)', r['request'] is False and db_row(H)['links'].endswith('facebook.com/samplehotel'))
g = row(F, H)
out = q(f"select public.vendor_save('{F}', {lit(dict(g, name_he='מלון אחר'))}::jsonb, '')", ok=False)
check('guide: Hebrew name change without a reason is refused', 'Say briefly why' in out, out)
out = q(f"select public.vendor_save('{F}', {lit(dict(g, contactPerson_he='איש קשר אחר'))}::jsonb, '')", ok=False)
check('guide: Hebrew contact change without a reason is refused', 'Say briefly why' in out, out)
r = save(F, dict(g, name_he='מלון אחר', contactPerson_he='איש קשר אחר', links=LINKS), 'Sample reason')
d = db_row(H)
check('guide: with a reason it becomes a change request; nothing locked changes yet', r['request'] is True and d['name_he'] == 'מלון לדוגמה' and d['contactPerson_he'] == 'דסק קבוצות', d)
check('guide: the link part of the same save went straight in', d['links'] == LINKS, d['links'])
req = next(x for x in j(f"select public.requests_list('{A}')") if x['vendor_id'] == H)
check('Review: the request carries Hebrew name and contact, now and proposed, and no links', req['proposed'] == {'name_he': 'מלון אחר', 'contactPerson_he': 'איש קשר אחר'} and req['current'] == {'name_he': 'מלון לדוגמה', 'contactPerson_he': 'דסק קבוצות'}, req)
q(f"select public.request_decide('{A}', '{req['id']}', true)")
d = db_row(H)
check('approved: both Hebrew fields applied', d['name_he'] == 'מלון אחר' and d['contactPerson_he'] == 'איש קשר אחר', d)
check('guide: an agent price is still what it was', d['agentPrice'] == '1150')
nv = save(F, {'name': 'Sample New Site', 'category': 'Attraction / Site', 'active': 'Active', 'currency': 'ILS', 'priceBasis': 'Per person', 'name_he': 'אתר לדוגמה', 'contactPerson_he': 'מישהו', 'links': 'www.sample-site.example'})['vendor']
check('guide: a new supplier keeps the Hebrew fields and links (it waits for review anyway)', nv['name_he'] == 'אתר לדוגמה' and nv['contactPerson_he'] == 'מישהו' and nv['links'] == 'https://www.sample-site.example' and db_row(nv['id'])['review_status'] == 'pending', nv)

# --- an organisation (limited member): sees the links and Hebrew fields; nothing more than before
o = row(L, H)
check('organisation: sees links, Hebrew name and contact', o['links'] == LINKS and o['name_he'] == 'מלון אחר' and o['contactPerson_he'] == 'איש קשר אחר', o)
check('organisation: still no agent price, agent link or how-to', o['agentPrice'] == '' and o['agentPriceVatTreatment'] == '' and o['agent_link'] == '' and o['agent_howto'] == '', o)
check('organisation: still no ratings or remarks on a hotel', all(o[k] == '' for k in ('rateValue', 'weaknesses', 'notes')), o)
r = save(L, dict(o, links=LINKS + '\nhttps://www.tiktok.com/@samplehotel'))
d = db_row(H)
check('organisation: a link change saves straight away', r['request'] is False and d['links'].endswith('tiktok.com/@samplehotel'))
check('organisation: its save left the agent price and how-to as they were', d['agentPrice'] == '1150' and d['agent_howto'] != '', d)
out = q(f"select public.vendor_save('{L}', {lit(dict(row(L, H), name_he='שם אחר'))}::jsonb, '')", ok=False)
check('organisation: the Hebrew name is locked for it too', 'Say briefly why' in out, out)
TA = ID['A']
check('organisation: a travel agent (not its section) is still not sent', row(L, TA) is None)
check('organisation: a hidden supplier is still not sent', row(L, ID['X']) is None)
check('vendor_detail opens for the organisation as before', 'prices' in j(f"select public.vendor_detail('{L}', '{H}')"))

# --- every function that lists vendor columns has the new ones
src = q("select string_agg(p.proname||'='||pg_get_functiondef(p.oid), E'\\n#####\\n') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'")
fns = dict(x.split('=', 1) for x in src.split('\n#####\n'))
for fn in ('_vendor_apply', 'vendor_save'):
    check(f'{fn} writes links, name_he and "contactPerson_he"', all(c in fns[fn] for c in ('links', 'name_he', '"contactPerson_he"')))
check('_all_fields lists the three fields', all(f"'{c}'" in fns['_all_fields'] for c in ('links', 'name_he', 'contactPerson_he')))
check('_locked_fields locks the Hebrew name and contact, not links', "'name_he'" in fns['_locked_fields'] and "'contactPerson_he'" in fns['_locked_fields'] and "'links'" not in fns['_locked_fields'])
lists = [n for n, b in fns.items() if '"cancelPolicyVerifiedDate","npResLink"' in b]
check('every function that lists the vendor columns by name lists links too', all('links' in fns[n] for n in lists), lists)
check('the Cockpit reader still compiles and is untouched (no contact or link fields)', 'cockpit_supplier_prices' in fns and 'links' not in fns['cockpit_supplier_prices'] and 'name_he' not in fns['cockpit_supplier_prices'])

n = len(res); bad = [x for x, ok in res if not ok]
print(f'{n} checks, {len(bad)} failed')
sys.exit(1 if bad else 0)
