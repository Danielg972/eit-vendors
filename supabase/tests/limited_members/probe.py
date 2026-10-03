import json, subprocess, sys
DB = sys.argv[1] if len(sys.argv) > 1 else 'eitv_limited_test'
A='ADMINTOKEN0000000000000000'; F='FULLTOKEN00000000000000000'
def q(sql, ok=True, role=None):
    pre = f"set role {role}; " if role else ''
    out = subprocess.run(['psql','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',pre+sql],capture_output=True,text=True)
    if ok and out.returncode: raise SystemExit('SQL failed: '+sql+'\n'+out.stderr)
    return out.stdout.strip() if out.returncode == 0 else 'ERR: '+out.stderr.strip().splitlines()[0]
def j(sql): return json.loads(q(sql))
def lit(o): return "'" + json.dumps(o).replace("'", "''") + "'"
ID = dict(l.split('|') for l in q("select k, id from public.__ids").splitlines())
res = []
def check(name, cond, detail=''):
    res.append((name, bool(cond))); print(('PASS ' if cond else 'FAIL ') + name + ((' :: ' + str(detail)[:300]) if not cond else ''))

# --- an organisation asks to join (as the anonymous role, the way the app calls it)
r = q("select public.request_access_org('Avi Stern','AVI@yeshiva.test','050-000-0000','','2026-10-03b','','short')", ok=False, role='anon')
check('join refused without an organisation name', 'name of your organisation' in r, r)
r = q("select public.request_access_org('Avi Stern','avi@yeshiva.test','050-000-0000','','2026-10-03b','Sample Yeshiva','short')", ok=False, role='anon')
check('join refused with too-short credentials', 'few lines' in r, r)
L = j("select public.request_access_org('Avi Stern','avi@yeshiva.test','050-000-0000','','2026-10-03b','Sample Yeshiva','I run the trips for a yeshiva of 120 students, six years in the role. Office 02-000-0000.')")['token']
L2 = j("select public.request_access_org('Miri Cohen','miri@school.test','','','2026-10-03b','Sample School','Trips coordinator at a girls school in Beit Shemesh since 2019.')")['token']
OLD = j("select public.request_access(p_name => 'Old App', p_email => 'old@guide.test', p_role => 'Licensed tour guide', p_license => '999', p_phone => '', p_note => '', p_terms => '2026-10-02e')")['token']
check('pending organisation cannot read the list', 'not active' in q(f"select public.vendors_list('{L}')", ok=False))
ml = j(f"select public.members_list('{A}')")
avi = next(m for m in ml if m['email']=='avi@yeshiva.test'); miri = next(m for m in ml if m['email']=='miri@school.test'); old = next(m for m in ml if m['email']=='old@guide.test')
check('organisation starts limited with the standard sections', avi['member_type']=='limited' and avi['sections']=='transport,guides,hotels,sites,food' and avi['see_quotes'] and not avi['see_guide_rates'] and avi['see_transport_reviews'] and not avi['see_reviews'], avi)
check('admin sees the free-text credentials and organisation', 'yeshiva of 120' in avi['credentials'] and avi['org']=='Sample Yeshiva' and avi['role']=='Organisation, not in tourism', avi)
check('the role an organisation cannot pick through the old join call', 'Choose what you do' in q("select public.request_access('X Y','xy@test.il','Organisation, not in tourism','','','','2026-10-03b')", ok=False))
check('a guide joining through an old app copy is a full member', old['member_type']=='full' and old['sections']=='')
for m in (avi, miri): q(f"select public.member_decide('{A}', '{m['id']}', 'approved')")
w = j(f"select public.whoami('{L}')")
check('whoami: limited, sections, no jobs, booking sheets on', w['role']=='Organisation, not in tourism' and w['org']=='Sample Yeshiva' and w['member_type']=='limited' and w['sections']==avi['sections'] and w['jobs'] is False and w['jobs_post'] is False and w['bookings'] is True and w['see_reviews'] is False and w['see_transport_reviews'] is True, w)
wf = j(f"select public.whoami('{F}')")
check('whoami: a full member is unchanged (full, jobs on)', wf['member_type']=='full' and wf['jobs'] is True and wf['see_reviews'] is True and wf['sections']=='', wf)

# --- what the limited member receives
vl = j(f"select public.vendors_list('{L}')"); names = {v['name'] for v in vl}; by = {v['name']: v for v in vl}
check('list: no travel agent, no hidden supplier', 'Test Travel Agent' not in names and 'Hidden Site' not in names, names)
check('list: transport, guide, hotel, site, restaurant, winery, guide-as-extra are there', {'Test Bus Co','Gila Guide','Test Hotel','Test Reserve','Test Grill','Test Winery','Jeep Guide','Private Price Site'} <= names, names)
check('list: no agent price, agent link or how-to anywhere', all(v['agentPrice']=='' and v['agentPriceVatTreatment']=='' and v['agent_link']=='' and v['agent_howto']=='' for v in vl), [(v['name'],v['agentPrice'],v['agent_howto']) for v in vl])
check('list: hotel shows its listed price', by['Test Hotel']['listedPrice']=='1400')
check('list: guide shows no price at all (guide rates off)', by['Gila Guide']['listedPrice']=='' and by['Gila Guide']['_prices']==0, by['Gila Guide'])
check('list: hotel ratings, strengths, weaknesses and summary are hidden', all(by['Test Hotel'][k]=='' for k in ('rateValue','weaknesses','notes','strengths','rateReliability','rateService')), by['Test Hotel'])
check('list: bus company ratings and summary are shown (transport reviews on)', by['Test Bus Co']['rateReliability']=='4' and by['Test Bus Co']['notes']=='bus summary')
check('list: counts match what he can open', by['Test Hotel']['_prices']==1 and by['Test Hotel']['_notes']==0 and by['Test Hotel']['_files']==0 and by['Test Reserve']['_prices']==1 and by['Test Reserve']['_notes']==1 and by['Test Reserve']['_files']==1, (by['Test Hotel']['_prices'],by['Test Hotel']['_notes'],by['Test Hotel']['_files'],by['Test Reserve']['_prices'],by['Test Reserve']['_notes'],by['Test Reserve']['_files']))
dh = j(f"select public.vendor_detail('{L}', '{ID['H']}')")
check('hotel page: only the public price line', [p['label'] for p in dh['prices']]==['Room rack'], dh['prices'])
check('hotel page: the guide\'s note is hidden', dh['notes']==[] and dh['reviews_open'] is False, dh['notes'])
ds = j(f"select public.vendor_detail('{L}', '{ID['S']}')")
check('site page: public line only, website note shown', [p['label'] for p in ds['prices']]==['Adult'] and len(ds['notes'])==1, ds)
check('guide page: no price lines', j(f"select public.vendor_detail('{L}', '{ID['G']}')")['prices']==[])
for fn in ('vendor_detail','quotes_list','drivers_list','food_list'):
    check(f'{fn} on a supplier outside his sections is refused', 'not available' in q(f"select public.{fn}('{L}', '{ID['A']}')", ok=False))
check('hidden supplier is refused', 'not available' in q(f"select public.vendor_detail('{L}', '{ID['X']}')", ok=False))
tr = j(f"select public.quotes_tracker('{L}')")
check('quotes: the bus quote only (no hotel, guide or private quote)', [x['vendor_id'] for x in tr]==[ID['T']], [(x['vendor_id'],x['options'][0]['name']) for x in tr])
check('quotes on the hotel page: none', j(f"select public.quotes_list('{L}', '{ID['H']}')")==[])
dr = j(f"select public.drivers_list('{L}', '{ID['T']}')")
check('drivers: reads the guide\'s review (transport reviews on)', dr[0]['n']==1 and len(dr[0]['reviews'])==1 and dr[0]['some_hidden'] is False, dr)
blob = json.dumps([vl, dh, ds, tr, dr, j(f"select public.vendor_detail('{L}', '{ID['T']}')")])
check('no other member\'s email in anything he received', '@test.il' not in blob and 'fay@' not in blob, [s for s in blob.split('"') if '@' in s][:5])

# --- what he adds is shown to everyone
r = j(f"select public.price_save('{L}', '{ID['H']}', {lit({'label':'Group of 40, half board','price':'780','basis':'Per group','is_agent':True})})")
check('his price is saved at once as an organisation rate', r=={'request':False,'mine':True,'org':True}, r)
row = j(f"select row_to_json(p) from public.vendor_prices p where label like 'Group of 40%'")
check('stored: org, never an agent rate, not private', row['org'] and not row['is_agent'] and not row['private'] and row['owner']=='avi@yeshiva.test', row)
def orgline(tok): return [p for p in j(f"select public.vendor_detail('{tok}', '{ID['H']}')")['prices'] if p['org']]
for who, tok in (('full member', F), ('another organisation', L2)):
    o = orgline(tok)
    check(f'{who} sees the organisation rate, without the name or email', len(o)==1 and o[0]['owner']=='' and o[0]['by']['name']=='an organisation' and not o[0]['mine'], o)
o = orgline(A); check('Eretz Israel Tours sees who added it', len(o)==1 and o[0]['owner']=='avi@yeshiva.test' and o[0]['by']['name']=='Avi Stern', o)
check('owner sees it as his own', orgline(L)[0]['mine'] is True)
check('a full member cannot change or suggest changing it', 'your own prices' in q(f"select public.price_save('{F}', '{ID['H']}', {lit({'id':row['id'],'label':'x','price':'1'})}, 'because')", ok=False))
check('a full member\'s personal line stays invisible to him', all(p['label']!='Fay own' for p in dh['prices']))
fay_line = q("select id from public.vendor_prices where label='Fay own'")
check('he cannot touch a line he cannot see', 'no longer exists' in q(f"select public.price_save('{L}', '{ID['H']}', {lit({'id':fay_line,'label':'x','price':'1'})}, 'why not')", ok=False))
q(f"select public.review_add('{L}', '{ID['H']}', 'Shabbaton for 80. Dining room handled the group well.', '4')")
for who, tok in (('full member', F), ('another organisation', L2), ('himself', L)):
    d = j(f"select public.vendor_detail('{tok}', '{ID['H']}')"); mine = [n for n in d['notes'] if n['org']]
    check(f'{who} reads his review with its rating and his name', len(mine)==1 and mine[0]['rating']=='4' and mine[0]['author']=='Avi Stern' and d['note_by'][mine[0]['id']]['role']=='Sample Yeshiva', mine)
check('the other organisation still does not read the guide\'s note', len(j(f"select public.vendor_detail('{L2}', '{ID['H']}')")['notes'])==1)
q(f"select public.note_add(p_token => '{F}', p_vendor => '{ID['H']}', p_body => 'old app copy note')")
check('note_add still works the old way (three named values)', q("select org::text || rating from public.vendor_notes where body='old app copy note'")=='false')
q(f"select public.note_add('{L2}', '{ID['S']}', 'plain note from an organisation')")
check('a plain note from an organisation is stamped too', q("select org::text from public.vendor_notes where body='plain note from an organisation'")=='true')
qid = q(f"select public.quote_save('{L}', '{ID['H']}', {lit({'date_from':'2026-09-10','date_to':'2026-09-12','title':'Shabbaton','options':[{'name':'Rooms','service':'hotel_room','lines':[{'label':'Double','kind':'Base','price':'780','unit':'per room per night'}]}]})})")
for who, tok in (('full member', F), ('another organisation', L2)):
    t = [x for x in j(f"select public.quotes_tracker('{tok}')") if x['id']==qid]
    check(f'{who} sees his hotel quote, without owner or title', len(t)==1 and t[0]['org'] and t[0]['owner']=='' and t[0]['title']=='' and not t[0]['mine'], t)
check('the other organisation still does not see the guide\'s hotel quote', sorted(x['vendor_id'] for x in j(f"select public.quotes_tracker('{L2}')"))==sorted([ID['T'], ID['H']]))

# --- switches
def access(**kw):
    a = dict(member_type='limited', sections='transport,guides,hotels,sites,food', see_quotes=True, see_guide_rates=False, see_transport_reviews=True, see_reviews=False); a.update(kw)
    q(f"select public.member_set_access('{A}', '{avi['id']}', {lit(a)})")
access(see_transport_reviews=False)
dr = j(f"select public.drivers_list('{L}', '{ID['T']}')")
check('transport reviews off: the guide\'s driver review is hidden and not counted', dr[0]['n']==0 and dr[0]['reviews']==[] and dr[0]['avg'] is None and dr[0]['some_hidden'] is True, dr)
check('transport reviews off: bus company ratings hidden', j(f"select public.vendors_list('{L}')") and next(v for v in j(f"select public.vendors_list('{L}')") if v['name']=='Test Bus Co')['rateReliability']=='')
q(f"select public.driver_review_add('{L}', '{ID['D']}', '{ID['T']}', {lit({'rating':'5','body':'Great with the boys'})})")
dr = j(f"select public.drivers_list('{L2}', '{ID['T']}')"); orgrev=[r for r in dr[0]['reviews'] if r['org']]
check('his driver review is read by everyone', len(orgrev)==1 and orgrev[0]['by']['name']=='Avi Stern' and dr[0]['n']==2)
dr = j(f"select public.drivers_list('{L}', '{ID['T']}')")
check('with the switch off he reads organisations\' reviews and his own only', dr[0]['n']==1 and dr[0]['reviews'][0]['mine'])
access(see_quotes=False)
check('quotes off: no bus quotes, own quote stays; booking sheets off', [x['id'] for x in j(f"select public.quotes_tracker('{L}')")]==[qid] and j(f"select public.whoami('{L}')")['bookings'] is False and 'not open' in q(f"select public.booking_save('{L}', '{ID['T']}', '{{}}')", ok=False))
access(see_guide_rates=True)
g = next(v for v in j(f"select public.vendors_list('{L}')") if v['name']=='Gila Guide')
check('guide rates on: listed price, public line and guide quote appear; never the agent price', g['listedPrice']=='2000' and g['agentPrice']=='' and g['_prices']==1 and ID['G'] in [x['vendor_id'] for x in j(f"select public.quotes_tracker('{L}')")], g)
access(see_reviews=True)
d = j(f"select public.vendor_detail('{L}', '{ID['H']}')"); h = next(v for v in j(f"select public.vendors_list('{L}')") if v['name']=='Test Hotel')
check('reviews on: guides\' notes, ratings and summary appear; still no agent price or agent line', d['reviews_open'] and len(d['notes'])==3 and h['rateValue']=='3' and h['notes']!='' and h['agentPrice']=='' and all(not p['is_agent'] for p in d['prices']), (len(d['notes']), h['rateValue']))
access(sections='transport')
names = {v['name'] for v in j(f"select public.vendors_list('{L}')")}
check('sections = transport only: only the bus company', names=={'Test Bus Co'}, names)
check('his own hotel quote is no longer listed once hotels are off', j(f"select public.quotes_tracker('{L}')")==[] or all(x['vendor_id']==ID['T'] for x in j(f"select public.quotes_tracker('{L}')")))
access(sections='guides')
names = {v['name'] for v in j(f"select public.vendors_list('{L}')")}
check('sections = guides only: the guide, and the supplier that also offers guiding', names=={'Gila Guide','Jeep Guide'}, names)
check('without transport he cannot look a driver up by phone or review one', q(f"select public.driver_find('{L}', '050-123-4567')")=='' and 'not part of your access' in q(f"select public.driver_review_add('{L}', '{ID['D']}', '', {lit({'rating':'5'})})", ok=False))
check('no sections ticked is refused', 'at least one section' in q(f"select public.member_set_access('{A}', '{avi['id']}', {lit({'member_type':'limited','sections':'nonsense'})})", ok=False))
access()

# --- editing and adding suppliers
before = j(f"select row_to_json(v) from public.vendors v where id = '{ID['H']}'")
form = {k: by['Test Hotel'].get(k, '') for k in ['name','category','active','contactPerson','phone','whatsapp','email','website','location','languages','kosher','maxCap','listedPrice','listedPriceVatTreatment','agentPrice','agentPriceVatTreatment','maxPax','priceBasis','currency','payTerms','cancelPolicy','cancelNoticeAmount','cancelNoticeUnit','cancelDayType','cancelPenalty','cancelPolicyVerifiedDate','npResLink','rateReliability','rateService','rateValue','strengths','weaknesses','notes','region','tags','experience_years','agent_link','agent_howto','also_categories','maps_link','hours','hours_last']}
form.update(id=ID['H'], location='Jerusalem', languages='English')
r = j(f"select public.vendor_save('{L}', {lit(form)}, '')")
after = j(f"select row_to_json(v) from public.vendors v where id = '{ID['H']}'")
check('editing the hotel: his empty agent, rating and summary fields change nothing; open fields save; no change request', r['request'] is False and all(after[k]==before[k] for k in ('agentPrice','agent_howto','rateValue','weaknesses','notes')) and after['location']=='Jerusalem' and r['vendor']['agentPrice']=='', {k: after[k] for k in ('agentPrice','agent_howto','rateValue','weaknesses','notes','location')})
check('adding a supplier outside his sections is refused', 'sections you have access to' in q(f"select public.vendor_save('{L}', {lit({'name':'New Agent','category':'Travel Agent','active':'Active','currency':'ILS','priceBasis':'Per person'})})", ok=False))
r = j(f"select public.vendor_save('{L}', {lit({'name':'New Hostel','category':'Hotel','active':'Active','currency':'ILS','priceBasis':'Per person','agentPrice':'500','listedPrice':'650','agent_howto':'x'})})")
nv = j(f"select row_to_json(v) from public.vendors v where name = 'New Hostel'")
check('adding a hotel: saved, pending review, with no agent price', nv['review_status']=='pending' and nv['agentPrice']=='' and nv['agent_howto']=='' and nv['listedPrice']=='650', nv)
check('agent sign-up details cannot be set by him', 'tour guides and agents' in q(f"select public.vendor_set_agent('{L}', '{ID['H']}', 'https://x.example/a', 'how')", ok=False))
check('admin-only calls are refused', 'Only Eretz Israel Tours' in q(f"select public.member_set_access('{L}', '{avi['id']}', '{{\"member_type\":\"full\"}}')", ok=False) and 'Only Eretz Israel Tours' in q(f"select public.members_list('{L}')", ok=False))

# --- jobs, files, helpers
c = j(f"select public.job_candidates('{A}', '{{\"kind\":\"guide\"}}')")
check('jobs: a limited member is never a candidate', all(x['name'] not in ('Avi Stern','Miri Cohen') for x in c) and any(x['name']=='Fay Full' for x in c), [x['name'] for x in c])
jb = q(f"select public.job_save('{A}', {lit({'kind':'guide','title':'Guide for a day','date_from':'2026-12-01','price':'1500','per':'day','currency':'ILS','vat':'plus_vat','audience':'all'})})", ok=False)
jl = j(f"select public.jobs_list('{L}')"); jf = j(f"select public.jobs_list('{F}')")
check('jobs: a job sent to everyone reaches the guide, not the organisation', len(jf['open'])==1 and jl['open']==[] and jl['mine']==[] and jl['taken']==[], (jb, jl, len(jf['open'])))
check('jobs: he cannot post one', 'not open' in q(f"select public.job_save('{L}', {lit({'kind':'guide','title':'x','date_from':'2026-12-01','price':'1','per':'day'})})", ok=False), q(f"select public.job_save('{L}', '{{}}')", ok=False))
fs = j(f"select public._file_scope('{avi['id']}', '{ID['A']}')"); fs2 = j(f"select public._file_scope('{avi['id']}', '{ID['H']}')")
check('files scope: closed outside his sections, limited inside', fs=={'can_see':False,'limited':True} and fs2=={'can_see':True,'limited':True}, (fs, fs2))
check('files scope is usable with the service key, not by the public key', q(f"select public._file_scope('{avi['id']}', '{ID['H']}')", role='service_role')!='' and 'permission denied' in q(f"select public._file_scope('{avi['id']}', '{ID['H']}')", ok=False, role='anon'))
check('a quote saved through a booking sheet or quote_save is stamped by the trigger', q(f"select org::text from public.quotes where id = '{qid}'")=='true' and q("select bool_or(org)::text from public.quotes where owner='fay@test.il'")=='false')
helpers = "quotes_org_stamp() _me() _section_of(text) _limited(public.members) _can_see(public.members,text,text) _reviews_open(public.members,text,text) _price_visible(public.vendor_prices,public.vendors,public.members) _note_visible(public.vendor_notes,public.vendors,public.members) _file_visible(public.vendor_files,public.members) _file_scope(uuid,text) _quote_kind(public.quotes,public.vendors) _quote_visible(public.quotes,public.vendors,public.members) _vendor_for(public.vendors,public.members)".split()
check('none of the new helpers can be called from outside', q("select bool_or(has_function_privilege(r, f::regprocedure, 'execute')) from unnest(array['anon','authenticated','public']) r, unnest(array[" + ','.join("'public."+h+"'" for h in helpers) + "]) f")=='f')
check('still no table open to the public key', q("select count(*) from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated','PUBLIC')")=='0')

# --- where limited members meet D-12, D-14 and D-16 (a guide's page for clients, claimed pages, reviews, guide rules)
access()
G = ID['G']
q(f"select public.vendor_set_client('{A}', '{G}', 'Gila has guided for twenty years.', '$650 a day')")
g = next(v for v in j(f"select public.vendors_list('{L}')") if v['id']==G)
check('client section: the organisation reads the bio, not the retail price (guide rates off)', g['client_bio'].startswith('Gila has') and g['retail_price']=='' and g['claimed_by']=='', (g['client_bio'], g['retail_price']))
access(see_guide_rates=True)
check('client section: retail price shown with guide rates on, agent price still not', (lambda v: v['retail_price']=='$650 a day' and v['agentPrice']=='')(next(v for v in j(f"select public.vendors_list('{L}')") if v['id']==G)))
access()
check('client section: the organisation cannot write it', 'written by guides, agents' in q(f"select public.vendor_set_client('{L}', '{G}', 'x', 'y')", ok=False))
check('client section: the stored bio and retail price are untouched', q(f"select client_bio || '|' || retail_price from public.vendors where id = '{G}'")=='Gila has guided for twenty years.|$650 a day')
check('claims: the organisation cannot claim a page', 'guides, agents and suppliers' in q(f"select public.vendor_claim('{L}', '{G}', 'ours')", ok=False))
check('claims: nor a supplier outside its sections', 'not available' in q(f"select public.vendor_claim('{L}', '{ID['A']}', 'ours')", ok=False))
# reviews: an organisation's review is live at once and reaches everyone; private and waiting notes reach nobody else
r1 = j(f"select public.review_post('{L}', '{G}', 'MEET org public review', '5', false)")
r2 = j(f"select public.review_post('{L}', '{G}', 'MEET org private review', '', true)")
check('reviews: the organisation\'s review is approved at once; its private one stays private', r1=={'status':'approved','private':False} and r2=={'status':'approved','private':True}, (r1, r2))
q(f"insert into public.members (name,email,token_hash,status,role,license_no,phone) values ('Gil Other','gil@test.il', public._hash('GUIDETWOTOKEN0000000000000'),'approved','Licensed tour guide','222','0529998877')")
G2T = 'GUIDETWOTOKEN0000000000000'
r3 = j(f"select public.review_post('{G2T}', '{G}', 'MEET guide about guide', '', false)"); r4 = j(f"select public.review_post('{F}', '{G}', 'MEET guide private', '', true)")
check('reviews: a guide about a guide waits; a guide\'s private note does not', r3['status']=='pending' and r4=={'status':'approved','private':True}, (r3, r4))
def bodies(tok): return sorted(n['body'] for n in j(f"select public.vendor_detail('{tok}', '{G}')")['notes'] if n['body'].startswith('MEET'))
check('reviews: the other organisation reads the public organisation review only', bodies(L2)==['MEET org public review'], bodies(L2))
check('reviews: a guide reads the public organisation review, and his own private note', bodies(F)==['MEET guide private','MEET org public review'], bodies(F))
check('reviews: the author of the waiting note sees it; the organisation that wrote privately sees its own two', bodies(G2T)==['MEET guide about guide','MEET org public review'] and bodies(L)==['MEET org private review','MEET org public review'], (bodies(G2T), bodies(L)))
check('reviews: Eretz Israel Tours reads all four', bodies(A)==['MEET guide about guide','MEET guide private','MEET org private review','MEET org public review'], bodies(A))
cnt = lambda tok: next(v for v in j(f"select public.vendors_list('{tok}')") if v['id']==G)['_notes']
check('reviews: the note count each one gets is what he can open', cnt(L2)==len(j(f"select public.vendor_detail('{L2}', '{G}')")['notes']) and cnt(F)==len(j(f"select public.vendor_detail('{F}', '{G}')")['notes']), (cnt(L2), cnt(F)))
q(f"select public.note_decide('{A}', (select id from public.vendor_notes where body = 'MEET guide about guide'), true)")
access(see_reviews=True)
check('reviews: approved, the guide\'s note reaches an organisation only where its switches open guides\' reviews', 'MEET guide about guide' in bodies(L) and 'MEET guide about guide' not in bodies(L2), (bodies(L), bodies(L2)))
access()
# the owner of a page: a guide whose phone is on it, then by claim. No notes at all, organisation reviews included.
q(f"update public.vendors set phone = '052-999-8877' where id = '{G}'")
own = next(v for v in j(f"select public.vendors_list('{G2T}')") if v['id']==G); dg = j(f"select public.vendor_detail('{G2T}', '{G}')")
check('own page: no ratings, no notes (organisation reviews included), flagged as his', own['_own'] is True and own['rateService']=='' and own['notes']=='' and own['_notes']==0 and dg['notes']==[] and dg['own'] is True, (own['_own'], own['rateService'], own['_notes'], dg['notes']))
check('own page: he cannot add a note or a review to it', 'your own page' in q(f"select public.review_add('{G2T}', '{G}', 'I am great', '5')", ok=False))
check('own page: everyone else still reads the reviews', 'MEET org public review' in bodies(F) and next(v for v in j(f"select public.vendors_list('{F}')") if v['id']==G)['rateService']=='5')
q(f"update public.vendors set phone = '' where id = '{G}'")
q(f"select public.vendor_set_claim('{A}', '{G}', (select id from public.members where email = 'gil@test.il'))")
check('claimed page: a guide who is not the claimer cannot write the client section; the claimer can', 'has claimed the page' in q(f"select public.vendor_set_client('{F}', '{G}', 'x', 'y')", ok=False) and j(f"select public.vendor_set_client('{G2T}', '{G}', 'My own bio', '$700 a day')")['_mine'] is True)
lv = next(v for v in j(f"select public.vendors_list('{L}')") if v['id']==G)
check('claimed page: the organisation gets a name, never the claimer\'s email', lv['_claimed'] is True and lv['claimed_name']=='Gil Other' and lv['claimed_by']=='' and 'gil@test.il' not in json.dumps(lv), lv)
# guide rules
nv = {'active':'Active','currency':'ILS','priceBasis':'Per day','name':'Org Added Guide','category':'Guide'}
check('guide rules: an organisation adding a guide must say licensed or specialty too', 'Say whether this guide is licensed' in q(f"select public.vendor_save('{L}', {lit(nv)})", ok=False))
check('guide rules: with the tag it saves, with no agent price', (lambda v: v['vendor']['tags']=='Licensed tour guide' and v['vendor']['agentPrice']=='')(j(f"select public.vendor_save('{L}', {lit(dict(nv, tags='Licensed tour guide', agentPrice='999'))})")))
check('none of the claim helpers can be called from outside', q("select bool_or(has_function_privilege(r, f::regprocedure, 'execute')) from unnest(array['anon','authenticated','public']) r, unnest(array['public._is_guide(public.vendors)','public._is_own(public.vendors,public.members)','public._driver_own(public.drivers,public.members)','public._is_guide_member(public.members)']) f")=='f')
access(member_type='full')
check('switched to full: he gets the whole list with agent prices', any(v['agentPrice']=='1150' for v in j(f"select public.vendors_list('{L}')")) and j(f"select public.whoami('{L}')")['member_type']=='full')
print('\n%d checks, %d failed' % (len(res), sum(1 for _, ok in res if not ok)))
