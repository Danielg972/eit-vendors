import json, subprocess, sys
NEW, MIG = 'eitv_hk_new', 'eitv_hk_mig'
A='ADMINTOKEN0000000000000000'; F='FULLTOKEN00000000000000000'; G='GUIDETWOTOKEN0000000000000'
def q(sql, ok=True, role=None, db=MIG):
    pre = f"set role {role}; " if role else ''
    out = subprocess.run(['psql','-qAt','-v','ON_ERROR_STOP=1','-d',db,'-c',pre+sql],capture_output=True,text=True)
    if ok and out.returncode: raise SystemExit('SQL failed: '+sql[:400]+'\n'+out.stderr)
    return out.stdout.strip() if out.returncode == 0 else 'ERR: '+out.stderr.strip().splitlines()[0]
def j(sql, **k): return json.loads(q(sql, **k))
def lit(o): return "'" + json.dumps(o).replace("'", "''") + "'"
res = []
def check(name, cond, detail=''):
    res.append((name, bool(cond))); print(('PASS ' if cond else 'FAIL ') + name + ((' :: ' + str(detail)[:400]) if not cond else ''))
def save(tok, h, ok=True): 
    r = q(f"select public.hike_save('{tok}', {lit(h)}::jsonb)", ok=ok)
    return json.loads(r) if not r.startswith('ERR') else r
def report(tok, hid, r, ok=True):
    x = q(f"select public.hike_report_save('{tok}', '{hid}', {lit(r)}::jsonb)", ok=ok)
    return json.loads(x) if not x.startswith('ERR') else x
def seen(hid): return next(h for h in j(f"select public.hikes_list('{A}')") if h['id']==hid)['updated_at']
def approve(hid, at=None): return q(f"select public.hike_decide('{A}', '{hid}', true, '{at or seen(hid)}')", ok=False)
BASE = dict(name='Sample Canyon', region='Dead Sea & Judean Desert', official=True, distance_km='5', hours_from='3', hours_to='4', start_place='Sample trailhead', is_loop=False, end_place='Sample road', notes='Not after rain.', source='walked')
HEAD = '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle">'
GPX = HEAD + '<trk><trkseg><trkpt lat="31.5" lon="35.4"/><trkpt lat="31.51" lon="35.41"/></trkseg></trk></gpx>'
REFUSED = ('does not look like a GPX', 'should not', 'no route in it')

# --- the two builds are the same
FP = "select string_agg(p.proname||':'||md5(replace(pg_get_functiondef(p.oid), E'\\r','')), ' ' order by p.proname, pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname not like '\\_\\_%'"
check('every function is the same in the schema record and after the migration', q(FP, db=NEW) == q(FP, db=MIG))
COLS = "select string_agg(table_name||'.'||column_name||':'||data_type||':'||coalesce(column_default,'')||':'||is_nullable, ' ' order by table_name, column_name) from information_schema.columns where table_schema='public' and table_name like 'hike%'"
check('the three hike tables have the same columns in both builds', q(COLS, db=NEW) == q(COLS, db=MIG) and 'hike_gpx.body' in q(COLS))
CONS = "select string_agg(conname||':'||pg_get_constraintdef(oid), ' ' order by conname) from pg_constraint where conrelid::regclass::text like 'hike%' or conrelid::regclass::text like 'public.hike%'"
check('and the same constraints', q(CONS, db=NEW) == q(CONS, db=MIG) and 'hike_reports_hike_id_fkey' in q(CONS), (q(CONS, db=NEW), q(CONS)))
IDX = "select string_agg(indexname, ' ' order by indexname) from pg_indexes where schemaname='public' and tablename like 'hike%'"
check('and the same indexes', q(IDX, db=NEW) == q(IDX, db=MIG), (q(IDX, db=NEW), q(IDX)))
for db in (NEW, MIG):
    check(f'{db}: the hike tables are closed (row security on, no grant to anon or authenticated, no policy)',
        q("select bool_and(c.relrowsecurity) and not bool_or(has_table_privilege(r, c.oid, 'select,insert,update,delete,truncate,references,trigger')) from pg_class c, unnest(array['anon','authenticated']) r where c.relnamespace='public'::regnamespace and c.relname in ('hikes','hike_reports','hike_gpx')", db=db) == 't'
        and q("select count(*) from pg_policies where schemaname='public'", db=db) == '0')
    check(f'{db}: no helper can be called from outside',
        q("select bool_or(has_function_privilege(r, p.oid, 'execute')) from pg_proc p, unnest(array['anon','authenticated','public']) r where p.pronamespace='public'::regnamespace and p.proname like '\\_hike%'", db=db) == 'f')
    check(f'{db}: the seven hike calls can be made by the app',
        q("select count(*) from pg_proc p where p.pronamespace='public'::regnamespace and p.proname in ('hikes_list','hike_detail','hike_save','hike_decide','hike_report_save','hike_report_hide','hike_gpx') and has_function_privilege('anon', p.oid, 'execute')", db=db) == '7')
check('reading the table directly is refused', 'permission denied' in q("select count(*) from public.hikes", ok=False, role='anon'))
check('a helper called directly is refused', 'permission denied' in q("select public._hikes_on(null)", ok=False, role='anon'))

# --- people: a second guide, and an organisation
q(f"insert into public.members (name,email,token_hash,status,role,license_no,phone) values ('Gil Guide','gil@test.il', public._hash('{G}'),'approved','Licensed tour guide','222','0523334455')")
L = j("select public.request_access_org('Avi Stern','avi@yeshiva.test','050-000-0000','','2026-10-03d','Sample Yeshiva','I run the trips for a yeshiva of 120 students, six years in the role. Office 02-000-0000.')")['token']
avi = next(m for m in j(f"select public.members_list('{A}')") if m['email']=='avi@yeshiva.test')
q(f"select public.member_decide('{A}', '{avi['id']}', 'approved')")
P = j("select public.request_access(p_name => 'Pending Pat', p_email => 'pat@test.il', p_role => 'Licensed tour guide', p_license => '333', p_phone => '', p_note => '', p_terms => '2026-10-03d')")['token']

# --- the switch: Eretz Israel Tours first
w_old = set(j(f"select public.whoami('{F}')", db=NEW).keys())
wf = j(f"select public.whoami('{F}')"); wa = j(f"select public.whoami('{A}')")
check('whoami keeps every key it had and gains hikes and hikes_for', {'name','email','status','is_admin','role','has_proof','terms_version','reminder_due','bcc_email','bcc_opt_out','bcc_ack','phone','bookings','bookings_for','jobs','jobs_post','jobs_for','member_type','sections','see_quotes','see_guide_rates','see_transport_reviews','see_reviews','org','hikes','hikes_for'} == set(wf.keys()) == w_old, set(wf.keys()))
check('before the switch: a member has no hikes, Eretz Israel Tours has', wf['hikes'] is False and wf['hikes_for']=='' and wa['hikes'] is True and wa['hikes_for']=='admin', (wf, wa))
check('before the switch: a member gets an empty list', j(f"select public.hikes_list('{F}')") == [])
check('before the switch: a member cannot add a hike', 'not open yet' in save(F, BASE, ok=False))
check('before the switch: a member cannot open, report or fetch', all('not open yet' in q(s, ok=False) for s in (f"select public.hike_detail('{F}', gen_random_uuid())", f"select public.hike_report_save('{F}', gen_random_uuid(), '{{}}'::jsonb)", f"select public.hike_gpx('{F}', gen_random_uuid())", f"select public.hike_report_hide('{F}', gen_random_uuid())")))
h0 = save(A, dict(BASE, name='Admin Loop', is_loop=True, end_place='ignored', markers=[{'color':'blue','number':'9456'},{'color':'BLACK','number':''},{'color':'pink','number':'abc'},{'color':'','number':'77'}]))
check('Eretz Israel Tours adds a hike: approved at once', h0['review_status']=='approved' and h0['by']=='Eretz Israel Tours' and h0['mine'] is True)
check('a loop keeps no end place', h0['is_loop'] is True and h0['end_place']=='')
check('markers: known colours and numbers kept in order, the rest left out', h0['markers']==[{'color':'blue','number':'9456'},{'color':'black','number':''},{'color':'','number':'77'}], h0['markers'])
check('more than 8 markers are cut to 8', len(save(A, dict(BASE, id=h0['id'], name='Admin Loop', is_loop=True, markers=[{'color':'red','number':str(i)} for i in range(12)]))['markers'])==8)
check('a member cannot change the setting', 'Only Eretz Israel Tours' in q(f"select public.set_setting('{F}','hikes_for','all')", ok=False))
check('the setting takes admin or all only', 'Unknown setting' in q(f"select public.set_setting('{A}','hikes_for','receive')", ok=False))
q(f"select public.set_setting('{A}','hikes_for','all')")
check('the older settings still work', q(f"select public.set_setting('{A}','jobs_for','all')")=='' and 'Unknown setting' in q(f"select public.set_setting('{A}','nothing','x')", ok=False))
wf = j(f"select public.whoami('{F}')"); wl = j(f"select public.whoami('{L}')")
check('after the switch: a guide and an organisation both have hikes', wf['hikes'] is True and wl['hikes'] is True and wl['member_type']=='limited' and wl['hikes_for']=='' and j(f"select public.whoami('{A}')")['hikes_for']=='all', (wf, wl))
check('a member whose request is still waiting gets nothing', j(f"select public.whoami('{P}')")['hikes'] is False and 'not active' in q(f"select public.hikes_list('{P}')", ok=False))
check('a wrong link gets nothing', 'not active' in q("select public.hikes_list('NOSUCHTOKEN')", ok=False))

# --- adding a hike: what is asked for
for name, change, msg in (
    ('no name', dict(name=' a '), 'name of the hike'), ('no region', dict(region=''), 'Choose the region'),
    ('not ticked as an official marked trail', dict(official=False), 'official marked trails'), ('official left out', dict(official=None), 'official marked trails'),
    ('no distance', dict(distance_km=''), 'distance in kilometres'), ('distance not a number', dict(distance_km='five'), 'distance in kilometres'), ('distance zero', dict(distance_km='0'), 'distance in kilometres'),
    ('no hours', dict(hours_from=''), 'how long'), ('longer time below the shorter', dict(hours_from='4', hours_to='3'), 'longer time'),
    ('distance in wide digits', dict(distance_km='１２'), 'distance in kilometres'), ('a name of spaces only', dict(name='\u00a0\u00a0\u200b  \t'), 'name of the hike'), ('a name of dots', dict(name='...'), 'name of the hike'),
    ('a name of invisible fillers', dict(name='\u3164\u3164\u3164'), 'name of the hike'), ('a name of control characters', dict(name='\x01\x02\x03'), 'name of the hike'),
    ('an id that is not an id', dict(id='zzz'), 'not available'), ('an id of another kind', dict(id=['x']), 'not available'),
    ('website without a link', dict(source='website', source_url=''), 'link to the page'), ('website link that is not a link', dict(source='website', source_url='javascript:alert(1)'), 'link to the page'),
    ('page dated 4 years back', dict(source='website', source_url='https://example.org/hike', source_year='2022'), 'older than 3 years'),
    ('page dated in the future', dict(source='website', source_url='https://example.org/hike', source_year='2031'), 'not come yet'),
    ('page year that is not a year', dict(source='website', source_url='https://example.org/hike', source_year='last'), 'year the page')):
    r = save(F, {k: v for k, v in dict(BASE, **change).items() if v is not None}, ok=False)
    check('a hike is refused: ' + name, isinstance(r, str) and msg in r, r)
check('nothing was saved by the refused tries', q("select count(*) from public.hikes")=='1')
check('a bad id with a bad link says only that the link is not active', 'not active' in q("select public.hike_save('', '{\"id\":\"zzz\"}'::jsonb)", ok=False, role='anon') and 'not active' in q("select public.hike_report_save('nope', gen_random_uuid(), '{\"id\":\"zzz\"}'::jsonb)", ok=False, role='anon'))
check('Eretz Israel Tours: a longer time without the shorter one is asked for the shorter one', 'how long' in save(A, dict(BASE, name='Admin hours', hours_from='', hours_to='5'), ok=False))
check('a name keeps its joiners and its Hebrew', (lambda n: n=='נחל עוג a\u200db')(save(A, dict(BASE, name='נחל  עוג\u00a0a\u200db'))['name']))
q("update public.hikes set review_status='rejected' where name like 'נחל%'")
check('a long name with spaces in it is tidied, not refused with a database message', save(A, dict(BASE, name='ab' + ' '*118 + 'cdef'))['name']=='ab cdef')
q("update public.hikes set review_status='rejected' where name='ab cdef'")
h1 = save(F, dict(BASE, markers=[{'color':'red','number':'123'}], gpx=GPX, gpx_name='my <walk>/../file.GPX'))
check('a guide adds a hike: it waits for approval', h1['review_status']=='pending' and h1['mine'] is True and h1['by']=='Fay Full' and h1['can_edit'] is True and h1['org'] is False, h1)
check('the route file is kept, under a plain name: the file\'s own name is not', h1['gpx'] and h1['gpx']['name']=='route.gpx' and h1['gpx']['by']=='Fay Full' and q("select count(*) from public.hike_gpx where name <> 'route.gpx'")=='0', h1['gpx'])
web = save(F, dict(BASE, name='Web Hike No Date', source='website', source_url='https://example.org/hike', source_year=''))
check('a page with no date is taken, with an empty year', web['source']=='website' and web['source_year']=='' and web['source_url']=='https://example.org/hike')
web3 = save(F, dict(BASE, name='Web Hike 3 Years', source='website', source_url='https://example.org/h3', source_year='2023'))
check('a page dated 3 years back is taken', web3['source_year']=='2023')
q(f"update public.hikes set source_year='2021' where id='{web3['id']}'")
check('an older entry can still be corrected once its page has aged past 3 years', save(F, dict(BASE, id=web3['id'], name='Web Hike 3 Years', source='website', source_url='https://example.org/h3', source_year='2021', notes='Corrected.'))['notes']=='Corrected.')
check('but its year cannot be changed to another old one', 'older than 3 years' in save(F, dict(BASE, id=web3['id'], name='Web Hike 3 Years', source='website', source_url='https://example.org/h3', source_year='2020'), ok=False))
check('walked: a link and a year sent with it are not kept', (lambda x: x['source_url']=='' and x['source_year']=='')(save(F, dict(BASE, name='Walked Only', source_url='https://example.org/x', source_year='2024'))))
ids = lambda tok: {h['name'] for h in j(f"select public.hikes_list('{tok}')")}
check('waiting hikes: their writer sees them', {'Sample Canyon','Web Hike No Date','Web Hike 3 Years','Walked Only','Admin Loop'} == ids(F), ids(F))
check('waiting hikes: another guide and an organisation do not', ids(G)=={'Admin Loop'} and ids(L)=={'Admin Loop'}, (ids(G), ids(L)))
check('waiting hikes: Eretz Israel Tours sees them all, and the one it took off', len(ids(A))==7 and 'ab cdef' in ids(A), ids(A))
check('a waiting hike cannot be opened, reported on or fetched by someone else', all('not available' in q(s, ok=False) for s in (f"select public.hike_detail('{G}', '{h1['id']}')", f"select public.hike_gpx('{L}', '{h1['id']}')", f"select public.hike_report_save('{G}', '{h1['id']}', '{{\"walked_on\":\"2026-09-14\"}}'::jsonb)")))
check('a waiting hike cannot be changed by someone else', 'not available' in save(G, dict(BASE, id=h1['id'], name='Taken over'), ok=False))
check('its writer can change it while it waits', save(F, dict(BASE, id=h1['id'], notes='Changed.'))['notes']=='Changed.')
check('a member cannot approve', 'Only Eretz Israel Tours' in q(f"select public.hike_decide('{F}', '{h1['id']}', true)", ok=False))
check('approving without naming the version that was read is refused', 'changed after you opened it' in q(f"select public.hike_decide('{A}', '{h1['id']}', true)", ok=False))
check('approving or turning down with no answer is refused', 'Say whether' in q(f"select public.hike_decide('{A}', '{h1['id']}', null)", ok=False))
old_seen = seen(h1['id'])
save(F, dict(BASE, id=h1['id'], notes='Swapped after the admin read it.', start_place='https://evil.example/login'))
check('a hike changed by its writer after Eretz Israel Tours read it cannot be approved unread', 'changed after you opened it' in approve(h1['id'], old_seen) and next(h for h in j(f"select public.hikes_list('{A}')") if h['id']==h1['id'])['review_status']=='pending')
old_seen = seen(h1['id'])
save(F, dict(BASE, id=h1['id'], notes='Changed.', gpx=GPX.replace('31.51', '31.61')))
check('nor can its route file be swapped unread', 'changed after you opened it' in approve(h1['id'], old_seen))
check('the writer cannot swap the route file through a report either', 'already has a route file' in report(F, h1['id'], dict(walked_on='2026-01-05', gpx=GPX, gpx_name='again.gpx'), ok=False))
save(F, dict(BASE, id=h1['id'], notes='Changed.', gpx=GPX, gpx_name='my <walk>/../file.GPX'))
check('approving the version that was read works', approve(h1['id'])=='')
check('approved: everyone sees it', 'Sample Canyon' in ids(G) and 'Sample Canyon' in ids(L))
check('approved: its writer can no longer change it', 'Suggest a change' in save(F, dict(BASE, id=h1['id'], name='Renamed'), ok=False))
check('approved: Eretz Israel Tours can, and it stays approved', (lambda x: x['name']=='Sample Canyon (lower)' and x['review_status']=='approved')(save(A, dict(BASE, id=h1['id'], name='Sample Canyon (lower)'))))
check('the writer is still named after Eretz Israel Tours changed it', next(h for h in j(f"select public.hikes_list('{G}')") if h['id']==h1['id'])['by']=='Fay Full')
q(f"select public.hike_decide('{A}', '{web['id']}', false)")
check('an approved hike changed by Eretz Israel Tours still shows its route file', next(h for h in j(f"select public.hikes_list('{G}')") if h['id']==h1['id'])['gpx']['name'].lower().endswith('.gpx'))
check('turned down: only its writer and Eretz Israel Tours see it', 'Web Hike No Date' in ids(F) and 'Web Hike No Date' in ids(A) and 'Web Hike No Date' not in ids(G))
check('turned down: a change by its writer sends it back to waiting', save(F, dict(BASE, id=web['id'], name='Web Hike No Date', source='website', source_url='https://example.org/hike'))['review_status']=='pending')

# --- the route file
gx = j(f"select public.hike_gpx('{L}', '{h1['id']}')")
check('an organisation can fetch the route file of an approved hike', gx['body']==GPX and gx['name']=='route.gpx', gx['name'])
PT = '<trkpt lat="31.5" lon="35.4"/><trkpt lat="31.51" lon="35.41"/>'; TRK = '<trk><trkseg>' + PT + '</trkseg></trk>'
for name, body in (('text that is not GPX', 'hello'), ('GPX with a DOCTYPE', '<!DOCTYPE x>' + HEAD + TRK + '</gpx>'), ('GPX cut off', HEAD + '<trk>'),
    ('a GPX file as a recording app writes it', '<?xml version="1.0"?><gpx version="1.1" creator="SomeApp"><trk><trkseg><trkpt lat="31.5" lon="35.4"></trkpt><trkpt lat="31.6" lon="35.4"></trkpt></trkseg></trk></gpx>'),
    ('another kind of file with gpx in a comment', '<html><!-- ' + HEAD + '</gpx> --><body>x</body></html>'),
    ('GPX with a script', HEAD + '<script>x</script>' + TRK + '</gpx>'), ('GPX with a script from another namespace', HEAD + '<h:script xmlns:h="http://www.w3.org/1999/xhtml">x</h:script>' + TRK + '</gpx>'),
    ('GPX with a picture element', HEAD + '<svg onload="x"></svg>' + TRK + '</gpx>'), ('GPX with a handler attribute on a point', HEAD + '<trk><trkseg><trkpt lat="31.5" lon="35.4" onload="x"/><trkpt lat="31.6" lon="35.4"/></trkseg></trk></gpx>'),
    ('GPX with a handler attribute on the opening tag', HEAD.replace('>', ' onload="x">') + TRK + '</gpx>'), ('GPX with a stylesheet line', '<?xml-stylesheet href="x.xsl"?>' + HEAD + TRK + '</gpx>'),
    ('GPX with a comment', HEAD + '<!-- made by an app -->' + TRK + '</gpx>'), ('GPX with a CDATA block', HEAD + '<![CDATA[x]]>' + TRK + '</gpx>'),
    ("GPX with the recorder's name and email", HEAD + '<metadata><author><name>Fay Full</name><email id="fay" domain="test.il"></email></author></metadata>' + TRK + '</gpx>'),
    ('GPX with the time of each point', HEAD + '<trk><trkseg><trkpt lat="31.5" lon="35.4"><time>2026-09-14T06:00:00Z</time></trkpt><trkpt lat="31.6" lon="35.4"/></trkseg></trk></gpx>'),
    ('GPX with extra data from the app', HEAD + '<trk><extensions><x>1</x></extensions><trkseg>' + PT + '</trkseg></trk></gpx>'),
    ('GPX with a name on the recording', HEAD + '<trk><name>Sample family walk</name><trkseg>' + PT + '</trkseg></trk></gpx>'),
    ('GPX with loose text in it', HEAD + 'call 052-0000000' + TRK + '</gpx>'), ('GPX with text after the end', HEAD + TRK + '</gpx>call 052-0000000'), ('GPX with two files in one', HEAD + TRK + '</gpx>' + HEAD + TRK + '</gpx>'),
    ('GPX with points that have no place', HEAD + '<trk><trkseg><trkpt/><trkpt/></trkseg></trk></gpx>'),
    ('GPX with a place that is not a number', HEAD + '<trk><trkseg><trkpt lat="javascript:alert(1)" lon="35.4"/><trkpt lat="31.5" lon="35.4"/></trkseg></trk></gpx>'),
    ('GPX with a place in wide digits', HEAD + '<trk><trkseg><trkpt lat="３１.5" lon="35.4"/><trkpt lat="31.5" lon="35.4"/></trkseg></trk></gpx>'),
    ('GPX with points outside a track', HEAD + PT + '</gpx>'), ('GPX with a track inside a track', HEAD + '<trk><trk><trkseg>' + PT + '</trkseg></trk></trk></gpx>'),
    ('GPX with a spot name longer than 60', HEAD + '<wpt lat="31.5" lon="35.4"><name>' + 'x'*61 + '</name></wpt>' + TRK + '</gpx>'),
    ('GPX with markup in a spot name', HEAD + '<wpt lat="31.5" lon="35.4"><name><b>x</b></name></wpt>' + TRK + '</gpx>'), ('GPX with another entity in a spot name', HEAD + '<wpt lat="31.5" lon="35.4"><name>&xxe;</name></wpt>' + TRK + '</gpx>'),
    ('GPX with more marked spots than the app sends', HEAD + '<wpt lat="31.5" lon="35.4"/>'*201 + TRK + '</gpx>'),
    ('GPX with points hidden in a spot name', HEAD + '<wpt lat="31.5" lon="35.4"><name><trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/></name></wpt></gpx>'),
    ('GPX with a place off the globe', HEAD + '<trk><trkseg><trkpt lat="91" lon="35.4"/><trkpt lat="31.5" lon="35.4"/></trkseg></trk></gpx>'), ('GPX with a place far off the globe', HEAD + '<trk><trkseg><trkpt lat="31.5" lon="999"/><trkpt lat="31.5" lon="35.4"/></trkseg></trk></gpx>'),
    ('GPX with a height of six figures', HEAD + '<trk><trkseg><trkpt lat="31.5" lon="35.4"><ele>100000</ele></trkpt><trkpt lat="31.5" lon="35.5"/></trkseg></trk></gpx>'),
    ('GPX with a character XML does not allow in a spot name', HEAD + '<wpt lat="31.5" lon="35.4"><name>x\uffffy</name></wpt>' + TRK + '</gpx>'),
    ('GPX with a prefix nobody declared', HEAD + '<h:script>x</h:script>' + TRK + '</gpx>'), ('GPX with a control character', HEAD + TRK.replace('<trkseg>', '<trkseg>\u0001') + '</gpx>'),
    ('GPX with marked spots only', HEAD + '<wpt lat="31.5" lon="35.4"/><wpt lat="31.6" lon="35.4"/></gpx>'), ('GPX with one point only', HEAD + '<trk><trkseg><trkpt lat="31.5" lon="35.4"/></trkseg></trk></gpx>')):
    r = save(A, dict(BASE, id=h0['id'], name='Admin Loop', is_loop=True, gpx=body), ok=False)
    check('a route file is refused: ' + name, isinstance(r, str) and any(m in r for m in REFUSED), r)
check('a route file is refused: over the size limit', 'too large' in q(f"select public.hike_save('{A}', {lit(dict(BASE, id=h0['id'], name='Admin Loop', is_loop=True))}::jsonb || jsonb_build_object('gpx', '{HEAD}<trk><trkseg>'||repeat('<trkpt lat=\"31.5\" lon=\"35.4\"/>', 70000)||'</trkseg></trk></gpx>'))", ok=False))
check('a save far bigger than any hike is refused at the door', 'more than a hike holds' in q(f"select public.hike_save('{A}', {lit(dict(BASE, name='Big'))}::jsonb || jsonb_build_object('markers', (select jsonb_agg('{{}}'::jsonb) from generate_series(1, 41))))", ok=False) and 'more than a hike holds' in q(f"select public.hike_save('{A}', '[1]'::jsonb)", ok=False) and 'more than a report holds' in q(f"select public.hike_report_save('{A}', '{h0['id']}', 'null'::jsonb)", ok=False))
check('a refused route file leaves the hike without one', next(h for h in j(f"select public.hikes_list('{A}')") if h['id']==h0['id'])['gpx'] is None and 'no route file' in q(f"select public.hike_gpx('{G}', '{h0['id']}')", ok=False))

check('a route with marked spots, heights and the GPX namespace is taken', isinstance(save(A, dict(BASE, id=h0['id'], name='Admin Loop', is_loop=True, gpx=HEAD + '<wpt lat="31.5" lon="35.4"><ele>-300.5</ele><name>עין &amp; Spring &lt;1&gt;</name></wpt><wpt lat="-0.000001" lon="180"/><wpt lat="90" lon="-179.999999"><ele>99999.9</ele></wpt><rte><rtept lat="31.5" lon="35.4"/><rtept lat="31.6" lon="35.5"><ele>0</ele></rtept></rte><trk><trkseg><trkpt lat="31.5" lon="35.4"><ele>12</ele></trkpt><trkpt lat="31.51" lon="35.41"/></trkseg><trkseg><trkpt lat="31.52" lon="35.42"/></trkseg></trk></gpx>')), dict))
save(A, dict(BASE, id=h0['id'], name='Admin Loop', is_loop=True, gpx_remove=True))
# a report by its writer on a hike that still waits counts as a change to it
pend = save(G, dict(BASE, name='Gil pending'))
at = seen(pend['id']); report(G, pend['id'], dict(walked_on='2026-09-01', note='Added after the admin read it.'))
check('a report added to a waiting hike after Eretz Israel Tours read it stops the approval', 'changed after you opened it' in approve(pend['id'], at))
at = seen(pend['id']); q(f"select public.hike_report_hide('{G}', (select id from public.hike_reports where hike_id='{pend['id']}'))")
check('so does taking that report off', 'changed after you opened it' in approve(pend['id'], at) and approve(pend['id'])=='')
at = seen(pend['id']); report(F, pend['id'], dict(walked_on='2026-09-02'))
check('a report on an approved hike does not touch the hike', seen(pend['id'])==at)
q(f"update public.hike_reports set hidden=true where hike_id='{pend['id']}'"); q(f"select public.hike_decide('{A}', '{pend['id']}', false)")

# --- reports after the hike
R = dict(walked_on='2026-09-14', group_size='12', age_min='10', age_max='58', difficulty='moderate', cliffs='yes', cliffs_note='Rungs on three drops', water_shoes='not_needed', poi='The rungs', firing_zone='crosses', water_route='no', drinking_water='no', bathrooms='none', eat='yes', eat_note='Shaded ledge', note='Start early.')
for name, change, msg in (('no date', dict(walked_on=''), 'date you walked'), ('a date that is not a date', dict(walked_on='2026-02-31'), 'date you walked'), ('a date to come', dict(walked_on='2031-01-01'), 'not come yet'), ('a date in 1990', dict(walked_on='1990-01-01'), 'year of the date'),
    ('group size in words', dict(group_size='a dozen'), 'group size'), ('group size zero', dict(group_size='0'), 'group size'), ('ages in words', dict(age_min='ten'), 'ages as numbers'), ('age 200', dict(age_max='200'), 'ages as numbers'), ('youngest above oldest', dict(age_min='60', age_max='10'), 'older than the oldest')):
    check('a report is refused: ' + name, msg in report(G, h1['id'], dict(R, **change), ok=False))
check('nothing was saved by the refused tries', q("select count(*) from public.hike_reports where not hidden")=='0')
q("select count(*) from public.hike_reports where not hidden"); d1 = report(G, h1['id'], dict(R, gpx=GPX, gpx_name='second.gpx'), ok=False)
check('a report cannot replace a route file that is there', isinstance(d1, str) and 'already has a route file' in d1 and q("select count(*) from public.hike_reports where not hidden")=='0', d1)
d1 = report(G, h1['id'], R)
check('a guide reports: the report comes back with his name', len(d1['reports'])==1 and d1['reports'][0]['by']=='Gil Guide' and d1['reports'][0]['mine'] is True and d1['reports'][0]['org'] is False, d1['reports'])
d2 = report(L, h1['id'], dict(walked_on='2026-05-02', group_size='24', age_min='9', age_max='67', difficulty='hard', cliffs='no', firing_zone='no', water_shoes='not_needed', bathrooms='end,start,elsewhere', eat='yes', difficulty_extra='x'))
check('an organisation reports: marked as an organisation, named', (lambda r: r['by']=='Avi Stern' and r['org'] is True and r['bathrooms']=='start,end')(next(r for r in d2['reports'] if r['walked_on']=='2026-05-02')), d2['reports'])
d3 = report(F, h1['id'], dict(walked_on='2026-03-01', group_size='6', difficulty='moderate', cliffs='no', firing_zone='unsure', difficulty_bad='x', water_shoes='boots'))
s = d3['hike']['r']
check('summary: count, latest walk, group and age range', s['n']==3 and s['last']=='2026-09-14' and s['group_min']==6 and s['group_max']==24 and s['age_min']==9 and s['age_max']==67, s)
check('summary: the most common difficulty', s['difficulty']=='moderate', s)
check('summary: one yes on cliffs is enough, one "crosses" on the firing zone is enough', s['cliffs']=='yes' and s['firing_zone']=='crosses', s)
check('a choice outside the list is left empty', next(r for r in d3['reports'] if r['walked_on']=='2026-03-01')['water_shoes']=='')
check('reports come newest walk first', [r['walked_on'] for r in d3['reports']]==['2026-09-14','2026-05-02','2026-03-01'])
gid = d1['reports'][0]['id']
check('a report cannot be changed by another member', 'Only the person who wrote' in report(F, h1['id'], dict(R, id=gid, note='hijack'), ok=False))
check('its writer can change it', (lambda d: next(r for r in d['reports'] if r['id']==gid)['note']=='Start at 07:00.' and len(d['reports'])==3)(report(G, h1['id'], dict(R, id=gid, note='Start at 07:00.'))))
check('Eretz Israel Tours can change it, and the writer stays', (lambda d: next(r for r in d['reports'] if r['id']==gid)['by']=='Gil Guide')(report(A, h1['id'], dict(R, id=gid, note='Edited.'))))
check('a report cannot be taken off by another member', 'Only the person who wrote' in q(f"select public.hike_report_hide('{L}', '{gid}')", ok=False))
q(f"select public.hike_report_hide('{G}', '{gid}')")
dd = j(f"select public.hike_detail('{L}', '{h1['id']}')")
check('taken off by its writer: gone from the page and the summary, the row kept', len(dd['reports'])==2 and dd['hike']['r']['n']==2 and dd['hike']['r']['cliffs']=='no' and q("select count(*) from public.hike_reports where hike_id='"+h1['id']+"' and created_at > now() - interval '1 hour' and note <> ''")>='1', dd['hike']['r'])
check('taken off twice is refused', 'Only the person who wrote' in q(f"select public.hike_report_hide('{G}', '{gid}')", ok=False))
d4 = report(G, h0['id'], dict(walked_on='2026-08-01', gpx=GPX, gpx_name='loop'))
check('a report can bring the first route file', d4['hike']['gpx'] and d4['hike']['gpx']['name']=='route.gpx' and d4['hike']['gpx']['by']=='Gil Guide', d4['hike']['gpx'])
save(A, dict(BASE, id=h0['id'], name='Admin Loop', is_loop=True, gpx_remove=True))
check('Eretz Israel Tours takes a route file off: nobody can fetch it, the row is kept', 'no route file' in q(f"select public.hike_gpx('{F}', '{h0['id']}')", ok=False) and q("select count(*) from public.hike_gpx")=='2')

# --- what leaves the database: names only
blob = ' '.join(q(s) for s in (f"select public.hikes_list('{L}')", f"select public.hikes_list('{G}')", f"select public.hikes_list('{A}')", f"select public.hike_detail('{L}', '{h1['id']}')", f"select public.hike_detail('{A}', '{h1['id']}')", f"select public.hike_gpx('{L}', '{h1['id']}')"))
check('no email, phone or licence number in anything a hike call returns', not any(x in blob for x in ('@test.il','@yeshiva.test','0521112233','0523334455','050-000-0000','"111"','"222"','token')), [x for x in ('@test.il','@yeshiva.test','0521112233','token') if x in blob])
check('text is kept as typed, quotes and all', save(A, dict(BASE, name="O'Brien's <b>\"trail\"</b>", notes="'; select 1; --"))['name']=="O'Brien's <b>\"trail\"</b>")

# --- the daily limit
for i in range(16): save(F, dict(BASE, name=f'Limit hike {i}'))
check('the 21st hike in a day is refused', 'Too many hikes' in save(F, dict(BASE, name='One too many'), ok=False), q("select count(*) from public.hikes where added_by='fay@test.il'"))
check('Eretz Israel Tours has no daily limit', all(isinstance(save(A, dict(BASE, name=f'Admin bulk {i}')), dict) for i in range(22)))

print('\n%d checks, %d failed' % (len(res), sum(1 for _, ok in res if not ok)))
