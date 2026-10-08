# Hike page (D-34): the page's sections, map links that ask Android for the app, the route drawn on the page, and how
# a route file is handed over. Opens index.html in preview mode (sample data) as an Android phone (two widths), an
# iPhone-like browser that can pass files to apps, a browser that offers to pass files and then refuses, and a computer.
# It also calls the page's own helpers with made-up routes and places and checks the figures and links they give.
# Needs playwright with chromium; the page is handed to the browser from the file, so no server is needed. Pictures go to argv[1].
import asyncio, os, sys, json, math
from urllib.parse import quote
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/hike_page').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]
PAGE=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','..','index.html'),encoding='utf-8').read()
END='\n})();\n</script>'; assert PAGE.count(END)==1
HOOKED=PAGE.replace(END,'\nObject.assign(window,{S,DB,hkTrack,hkRouteHtml,hkGpxFileText,hkPlaceRow,hkLinkProps,hkWaze,hkGmaps,hkLoadGpx,demoHikesInit,HK_GPX_HEAD});'+END)
def check(n,c,d=''):
    res.append((n,bool(c))); print(('PASS ' if c else 'FAIL ')+n+((' :: '+str(d)[:500]) if not c else ''))
ANDROID='Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Mobile Safari/537.36'
WEBVIEW='Mozilla/5.0 (Linux; Android 10; SM-G973F Build/QP1A; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/154.0.0.0 Mobile Safari/537.36'
IPHONE='Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'
G='https://www.google.com/maps/search/?api=1&query='; MAPS='com.google.android.apps.maps'; WAZE='com.waze'; NEW=['_blank','noopener noreferrer']
def intent(url, pkg): return 'intent://'+url[len('https://'):]+'#Intent;scheme=https;package='+pkg+';S.browser_fallback_url='+quote(url, safe="-_.!~*'()")+';end'
SHARE_OK="navigator.canShare=()=>true; navigator.share=async d=>{ window.__shared={n:d.files.length,name:d.files[0].name,type:d.files[0].type,text:await d.files[0].text()}; };"
SHARE_REFUSED="navigator.canShare=()=>true; navigator.share=async()=>{ const e=new Error('Permission denied'); e.name='NotAllowedError'; throw e; };"
HEAD='<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle">'
async def start(p, tag, ua, w, h, init=''):
    b=await p.chromium.launch(); kw=dict(viewport={'width':w,'height':h}, device_scale_factor=2, accept_downloads=True)
    if ua: kw.update(user_agent=ua, has_touch=True, is_mobile=True)
    ctx=await b.new_context(**kw)
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}"+init)
    async def serve(route): await route.fulfill(body=HOOKED, content_type='text/html; charset=utf-8')
    await ctx.route('**/index.html', serve)
    pg=await ctx.new_page(); pg.on('pageerror', lambda e: errs.append(tag+' pageerror: '+str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('[data-tab="hikes"]')
    await pg.add_style_tag(content='#demoAs,.demo-bar{display:none!important}')   # the preview's own "View as" bar is wider than a small phone
    return b, pg
async def open_hike(pg, name):
    if not await pg.locator('#hkResults').count(): await pg.click('[data-tab="hikes"]')
    await pg.wait_for_selector('#hkResults .row'); await pg.click(f'#hkResults .row:has-text("{name}")'); await pg.wait_for_selector('#sheetWrap .hkp-card')
over=lambda pg: pg.evaluate('()=>document.documentElement.scrollWidth>document.documentElement.clientWidth+1')
inside=lambda pg: pg.evaluate('()=>{ const s=document.querySelector(".sheet-body"), R=s.getBoundingClientRect(); return [...s.querySelectorAll("*")].filter(e=>{ const r=e.getBoundingClientRect(); return r.width>0&&(r.right>R.right+1||r.left<R.left-1); }).map(e=>e.className||e.tagName).slice(0,5); }')
async def page_checks(pg, tag):
    await open_hike(pg, 'Nahal Og')
    heads=await pg.eval_on_selector_all('#sheetWrap .hkp-h, #sheetWrap .panel h3','els=>els.map(e=>e.textContent)')
    check(tag+': the page is in sections, in this order', heads==['Getting there','The trail','Important notes','From colleagues who walked it','Before every trip'], heads)
    facts=await pg.eval_on_selector_all('#sheetWrap .hkp-fact','els=>els.map(e=>{ const b=e.querySelector("b"); return [e.querySelector("span").textContent,b.textContent,b.scrollWidth<=b.clientWidth+1&&b.getBoundingClientRect().height<50]; })')
    check(tag+': the key facts lead the page and none is cut off', facts==[['Distance','5 km',True],['Usual time','3–4 h',True],['Difficulty','Moderate',True]], facts)
    check(tag+': nothing runs off the side of the page', not await over(pg) and await inside(pg)==[], await inside(pg))
    await pg.wait_for_selector('#hkRouteBox svg polyline')
    side=await pg.eval_on_selector_all('#sheetWrap .hkp-card .hkp-row > .hkp-btns','els=>els.map(b=>{ const a=[...b.querySelectorAll("a")].map(x=>Math.round(x.getBoundingClientRect().top)); return a.length<2||a[0]===a[1]; })')
    check(tag+': the Google Maps and Waze buttons of a place sit side by side', side and all(side), side)
    small=await pg.eval_on_selector_all('#sheetWrap .hkp-go','els=>els.map(e=>[e.textContent.trim(),Math.round(e.getBoundingClientRect().height*10)/10]).filter(x=>x[1]<40)')
    check(tag+': every new button is tall enough to tap', small==[], small)
async def main():
    async with async_playwright() as p:
        # ================= an Android phone, 411 wide =================
        b,pg=await start(p,'android',ANDROID,411,812, SHARE_REFUSED); await page_checks(pg,'android')
        rt=' '.join((await pg.inner_text('#hkRoute')).split())
        # the sample line: its figures worked out here from the same points the preview makes
        pts=[(31.8+0.012*t+0.002*math.sin(t*9), 35.4+0.016*t*t+0.003*math.sin(t*5), -250+180*t+25*math.sin(t*7)) for t in [i/47 for i in range(48)]]
        pts=[(round(a,6),round(o,6),round(e,1)) for a,o,e in pts]
        def hav(a,b):
            R=6371000; dla=math.radians(b[0]-a[0]); dlo=math.radians(b[1]-a[1]); x=math.sin(dla/2)**2+math.cos(math.radians(a[0]))*math.cos(math.radians(b[0]))*math.sin(dlo/2)**2; return 2*R*math.asin(min(1,math.sqrt(x)))
        L=sum(hav(pts[i-1],pts[i]) for i in range(1,48)); up=dn=0; ref=pts[0][2]
        for q in pts[1:]:
            d=q[2]-ref
            if d>=10: up+=d; ref=q[2]
            elif d<=-10: dn-=d; ref=q[2]
        want=f'Length of the recording {L/1000:.2f} km Climb, about {round(up)} m Descent, about {round(dn)} m Lowest point {round(min(q[2] for q in pts))} m Highest point {round(max(q[2] for q in pts))} m'
        check('android: the route is drawn with its own length, climb, descent, lowest and highest point', want in rt and 'A recorded route is on file' in rt and 'A sketch of the recording, not a map' in rt, [want, rt])
        pl=await pg.eval_on_selector('#hkRouteBox polyline','e=>e.getAttribute("points").trim().split(/\\s+/).map(p=>p.split(",").map(Number))')
        check('android: the line holds every point of the sample and stays inside its frame', len(pl)==48 and all(0<=x<=320 and 0<=y<=200 for x,y in pl), [len(pl), pl[:2]])
        s_ll='%.6f,%.6f'%(pts[0][0],pts[0][1]); e_ll='%.6f,%.6f'%(pts[-1][0],pts[-1][1])
        ends=await pg.eval_on_selector_all('#hkRouteBox .hkp-ends a','els=>els.map(a=>[a.textContent,a.getAttribute("href"),a.getAttribute("target")||"",a.getAttribute("rel")||""])')
        check('android: where the recording starts and ends open the Google Maps app and Waze themselves, at the first and the last point', ends==[['Google Maps',intent(G+s_ll,MAPS),'',''],['Waze',intent('https://waze.com/ul?ll='+s_ll+'&navigate=yes',WAZE),'',''],['Google Maps',intent(G+e_ll,MAPS),'',''],['Waze',intent('https://waze.com/ul?ll='+e_ll+'&navigate=yes',WAZE),'','']], ends)
        pb=await pg.eval_on_selector_all('#sheetWrap .hkp-card .hkp-row:not(#hkRoute) > .hkp-btns a','els=>els.map(a=>[a.textContent,a.getAttribute("href"),a.getAttribute("target")||""])')
        check('android: start and end each have a Google Maps and a Waze button that ask for the app, by the words of the place', pb==[['Google Maps',intent(G+quote('Og trailhead, by Almog',safe="-_.!~*'()"),MAPS),''],['Waze',intent('https://waze.com/ul?q='+quote('Og trailhead, by Almog',safe="-_.!~*'()")+'&navigate=yes',WAZE),''],['Google Maps',intent(G+quote('Road 90, north of the Dead Sea',safe="-_.!~*'()"),MAPS),''],['Waze',intent('https://waze.com/ul?q='+quote('Road 90, north of the Dead Sea',safe="-_.!~*'()")+'&navigate=yes',WAZE),'']], pb)
        tiles=await pg.eval_on_selector_all('#sheetWrap .actions a.act','els=>els.map(a=>[a.textContent.trim(),a.getAttribute("href").slice(0,9),a.getAttribute("target")||""])')
        check('android: the Waze and Google Maps tiles at the top ask for the app too', tiles==[['Waze','intent://',''],['Google Maps','intent://','']], tiles)
        await pg.wait_for_timeout(500); await pg.screenshot(path=OUT+'hp_1_top.png')
        await pg.eval_on_selector('#hkRoute','e=>e.scrollIntoView({block:"start"})'); await pg.wait_for_timeout(300); await pg.screenshot(path=OUT+'hp_2_route.png')
        await pg.click('[data-hgpx]'); await pg.wait_for_selector('#hkModal'); mt=await pg.inner_text('#hkModal')
        check('android: the route file box does not offer what Android refuses; it says how to do it', await pg.locator('#hkModal [data-g="share"]').count()==0 and 'Save the file' in mt and 'open the file from there' in mt and 'Nothing can open the file until one is installed' in mt and 'Israel Hiking Map' in mt and 'Amud Anan' in mt, mt)
        await pg.screenshot(path=OUT+'hp_3_route_file.png')
        async with pg.expect_download() as dl: await pg.click('#hkModal [data-g="save"]')
        d=await dl.value; body=open(await d.path(),encoding='utf-8').read()
        check('android: the saved file is named after the hike and is a whole GPX file', d.suggested_filename=='Nahal-Og-lower-canyon.gpx' and body.startswith('<?xml version="1.0" encoding="UTF-8"?>\n'+HEAD+'<metadata><name>Nahal Og, lower canyon</name></metadata>') and '<trk><name>Nahal Og, lower canyon</name><trkseg>' in body and body.rstrip().endswith('</trkseg></trk></gpx>') and body.count('<trkpt')==48, body[:260])
        import xml.dom.minidom as md
        try: doc=md.parseString(body.encode('utf-8')); ok=doc.documentElement.tagName=='gpx' and len(doc.getElementsByTagName('trkpt'))==48
        except Exception: ok=False
        check('android: the saved file reads as correct XML with every point', ok)
        await pg.click('#hkModal [data-g="x"]'); await pg.click('#closeS')
        # ---- the owner's own case: a hike whose start and end are only pasted Google Maps short links ----
        A='https://maps.app.goo.gl/EnkUGVzWA2exJgkp6?g_st=ac'; Z='https://maps.app.goo.gl/qtTAazuByYUmZjp86?g_st=ac'
        await pg.evaluate("([a,z])=>{ const h=S.demoHikes.find(x=>x.name==='Ein Avdat canyon'); h.start_place=a; h.end_place=z; h.is_loop=false; }",[A,Z])
        await open_hike(pg,'Ein Avdat canyon')
        rows=await pg.eval_on_selector_all('#sheetWrap .hkp-card .hkp-row:not(#hkRoute)','els=>els.filter(r=>r.querySelector(".hkp-ptxt")).map(r=>[r.querySelector(".hkp-k").textContent,r.querySelector(".hkp-ptxt").textContent,[...r.querySelectorAll(".hkp-btns a")].map(a=>[a.textContent,a.getAttribute("href"),a.getAttribute("target")||""])])')
        check('android: a start and an end that are only a pasted Google Maps link say what they are and open that very link in the Google Maps app; no Waze button is made up', rows==[['Start','A pin on the map',[['Google Maps',intent(A,MAPS),'']]],['End','A pin on the map',[['Google Maps',intent(Z,MAPS),'']]]], rows)
        heads=await pg.eval_on_selector_all('#sheetWrap .hkp-h','els=>els.map(e=>e.textContent)')
        check('android: a hike in a park has the section "The place" between the trail and the notes', heads==['Getting there','The trail','The place','Important notes'], heads)
        await pg.wait_for_timeout(400); await pg.screenshot(path=OUT+'hp_4_link_only_places.png'); await pg.click('#closeS')
        # ---- the page's helpers, called with made-up places and routes ----
        P=await pg.evaluate("""()=>{ const row=(p,l)=>{ const d=document.createElement('div'); d.innerHTML=hkPlaceRow('Start',p,'start',l); return [d.querySelector('.hkp-ptxt')?d.querySelector('.hkp-ptxt').textContent:null, [...d.querySelectorAll('a')].map(a=>[a.textContent,a.getAttribute('href')])]; };
          return { words:row('Lower car park'), waze_ll:row('https://waze.com/ul?ll=31.7,35.2&navigate=yes'), waze_only:row('https://waze.com/ul?q=somewhere'), both:row('Gate https://www.google.com/maps/@31.5,35.4,15z https://waze.com/ul?ll=31.6,35.5'),
            other:row('Car park https://evil.example/login?x=1'), empty:hkPlaceRow('Start','','start'), loop:row('Lower car park','A loop: it ends where it starts.'),
            evil:[hkLinkProps('https://evil.example/maps').href, hkLinkProps('javascript:alert(1)').href, (h=>[h.split(';package=').length, h.includes(';package=com.google.android.apps.maps;S.browser_fallback_url='), /;end$/.test(h), h.indexOf('#')===h.lastIndexOf('#')])(hkLinkProps('https://maps.app.goo.gl/x;package=com.evil;end#Intent;package=com.evil;end').href)] }; }""")
        I=lambda u,pk: intent(u,pk)
        check('helpers: words alone give a Google Maps search and a Waze search for those words', P['words']==['Lower car park',[['Google Maps',I(G+'Lower%20car%20park',MAPS)],['Waze',I('https://waze.com/ul?q=Lower%20car%20park&navigate=yes',WAZE)]]], P['words'])
        check('helpers: a Waze link with a point gives Waze that link and Google Maps that point, never the hike\'s name', P['waze_ll']==['A pin on the map',[['Google Maps',I(G+'31.7,35.2',MAPS)],['Waze',I('https://waze.com/ul?ll=31.7,35.2&navigate=yes',WAZE)]]], P['waze_ll'])
        check('helpers: a Waze link with no point gives Waze only: no Google Maps button is made up', P['waze_only']==['A pin on the map',[['Waze',I('https://waze.com/ul?q=somewhere',WAZE)]]], P['waze_only'])
        check('helpers: with both kinds of link each button gets its own', P['both']==['Gate',[['Google Maps',I('https://www.google.com/maps/@31.5,35.4,15z',MAPS)],['Waze',I('https://waze.com/ul?ll=31.6,35.5',WAZE)]]], P['both'])
        check('helpers: a link that is not a map stays words: the buttons search for the words only', P['other']==['Car park https://evil.example/login?x=1',[['Google Maps',I(G+'Car%20park',MAPS)],['Waze',I('https://waze.com/ul?q=Car%20park&navigate=yes',WAZE)]]], P['other'])
        check('helpers: no place, no row; a loop\'s end points at the start', P['empty']=='' and P['loop']==['A loop: it ends where it starts.',[['Google Maps',I(G+'Lower%20car%20park',MAPS)],['Waze',I('https://waze.com/ul?q=Lower%20car%20park&navigate=yes',WAZE)]]], [P['empty'],P['loop']])
        check('helpers: only Google Maps and Waze addresses ever become an app link, and the app named is never the address\'s to choose', P['evil']==['https://evil.example/maps','javascript:alert(1)',[2,True,True,True]], P['evil'])
        T=await pg.evaluate("""()=>{ const H=HK_GPX_HEAD, p=(la,lo,e)=>'<trkpt lat="'+la+'" lon="'+lo+'">'+(e===undefined?'':'<ele>'+e+'</ele>')+'</trkpt>', r=(la,lo)=>'<rtept lat="'+la+'" lon="'+lo+'"/>';
          const pick=t=>t&&{segs:t.segs.map(s=>s.length), len:Math.round(t.len), up:t.up, down:t.down, lo:t.lo, hi:t.hi, start:t.start, end:t.end, same:t.same};
          const flat=Array.from({length:400},(_,i)=>p((31+i*0.0001).toFixed(6),'35.000000',(100+(i%2?4:-4)).toFixed(1))).join('');
          return { two:pick(hkTrack(H+'<trk><trkseg>'+p('31.000000','35.000000','100')+p('31.010000','35.000000','130')+'</trkseg></trk></gpx>')),
            wpt:pick(hkTrack(H+'<wpt lat="10" lon="10"><name>Spring</name></wpt><trk><trkseg>'+p('31.000000','35.000000')+p('31.010000','35.000000')+'</trkseg></trk></gpx>')),
            gap:pick(hkTrack(H+'<trk><trkseg>'+p('31.000000','35.000000')+p('31.010000','35.000000')+'</trkseg><trkseg>'+p('32.000000','35.000000')+p('32.010000','35.000000')+'</trkseg></trk></gpx>')),
            rte_and_trk:pick(hkTrack(H+'<rte>'+r('31','35')+r('31.5','35')+'</rte><trk><trkseg>'+p('31.000000','35.000000')+p('31.010000','35.000000')+'</trkseg></trk></gpx>')),
            rte_only:pick(hkTrack(H+'<rte>'+r('-31.000000','-35.000000')+r('-31.010000','-35.000000')+'</rte></gpx>')),
            noisy:pick(hkTrack(H+'<trk><trkseg>'+flat+'</trkseg></trk></gpx>')),
            loop:pick(hkTrack(H+'<trk><trkseg>'+p('31.000000','35.000000')+p('31.010000','35.010000')+p('31.000300','35.000200')+'</trkseg></trk></gpx>')),
            one:hkTrack(H+'<trk><trkseg>'+p('31','35')+'</trkseg></trk></gpx>'), none:hkTrack(H+'</gpx>'),
            lines:(()=>{ const d=document.createElement('div'); d.innerHTML=hkRouteHtml(hkTrack(H+'<trk><trkseg>'+p('31.000000','35.000000')+p('31.010000','35.000000')+'</trkseg><trkseg>'+p('32.000000','35.000000')+p('32.010000','35.000000')+'</trkseg></trk></gpx>')); return [d.querySelectorAll('polyline').length, /NaN|Infinity/.test(d.innerHTML)]; })(),
            same_pt:(()=>{ const d=document.createElement('div'); d.innerHTML=hkRouteHtml(hkTrack(H+'<trk><trkseg>'+p('31.000000','35.000000')+p('31.000000','35.000000')+'</trkseg></trk></gpx>')); return [/NaN|Infinity/.test(d.innerHTML), d.querySelector('.hkp-map svg').querySelectorAll('circle').length, d.textContent.includes('starts and ends')]; })() }; }""")
        km=lambda a,b: round(hav(a,b))
        check('helpers: two points 0.01 of a degree apart are about 1,112 m, climbing 30 m', T['two']=={'segs':[2],'len':km((31,35),(31.01,35)),'up':30,'down':0,'lo':100,'hi':130,'start':'31.000000,35.000000','end':'31.010000,35.000000','same':False} and 1105<T['two']['len']<1120, T['two'])
        check('helpers: marked spots are not counted as points of the route, and no heights means no climb figures', T['wpt']['segs']==[2] and T['wpt']['start']=='31.000000,35.000000' and T['wpt']['up'] is None and T['wpt']['lo'] is None, T['wpt'])
        check('helpers: two parts of a track far apart are two lines; the gap between them is neither counted nor drawn', T['gap']['segs']==[2,2] and T['gap']['len']==2*km((31,35),(31.01,35)) and T['gap']['end']=='32.010000,35.000000' and T['lines']==[2,False], [T['gap'],T['lines']])
        check('helpers: a file with a track and a route uses the track only', T['rte_and_trk']['segs']==[2] and T['rte_and_trk']['len']==km((31,35),(31.01,35)), T['rte_and_trk'])
        check('helpers: a file with a route only is read, south and west of zero too', T['rte_only']['segs']==[2] and T['rte_only']['start']=='-31.000000,-35.000000' and T['rte_only']['len']==km((-31,-35),(-31.01,-35)), T['rte_only'])
        check('helpers: a flat walk whose height reading jumps 8 m back and forth shows no climb', T['noisy']['up']==0 and T['noisy']['down']==0 and T['noisy']['lo']==96 and T['noisy']['hi']==104, T['noisy'])
        check('helpers: a walk that comes back to within 80 m of its start is "starts and ends" in one place; one point or none is no route', T['loop']['same'] is True and T['two']['same'] is False and T['one'] is None and T['none'] is None and T['same_pt']==[False,1,True], [T['loop'],T['one'],T['none'],T['same_pt']])
        F=await pg.evaluate("""()=>{ const H=HK_GPX_HEAD, body=H+'<wpt lat="1" lon="1"/><rte><rtept lat="1" lon="1"/><rtept lat="2" lon="2"/></rte><trk><trkseg><trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/></trkseg></trk><trk><trkseg><trkpt lat="3" lon="3"/><trkpt lat="4" lon="4"/></trkseg></trk></gpx>';
          const f=n=>hkGpxFileText({name:n}, body); return { amp:f('N'.repeat(116)+' & S'), dollar:f("Wadi $' east $& $`"), tags:f('A <b>bold</b> & "quoted" ]]> name'), heb:f('נחל עוג'), empty:f(''), raw:hkGpxFileText({name:'x'},'not a gpx') }; }""")
        import xml.dom.minidom as md2
        def good(x, name):
            try: d=md2.parseString(x.encode('utf-8'))
            except Exception as e: return 'not XML: '+str(e)[:80]
            g=d.documentElement; kids=[c.tagName for c in g.childNodes if c.nodeType==1]
            names=[n.firstChild.data if n.firstChild else '' for n in g.getElementsByTagName('name')]
            return kids==['metadata','wpt','rte','trk','trk'] and names==[name,name,name] and len(g.getElementsByTagName('trkpt'))==4 and x.startswith('<?xml version="1.0" encoding="UTF-8"?>\n')
        check('helpers: the file handed over is correct XML whatever the hike is called: a name cut at 120 with an & at the end', good(F['amp'],'N'*116+' & S')is True, good(F['amp'],'N'*116+' & S'))
        check('helpers: ... a name with dollar signs', good(F['dollar'],"Wadi $' east $& $`") is True, [good(F['dollar'],"Wadi $' east $& $`"), F['dollar'][:260]])
        check('helpers: ... a name with markup, quotes and Hebrew; no name becomes "Route"; a body that is not ours is left alone', good(F['tags'],'A <b>bold</b> & "quoted" ]]> name') is True and good(F['heb'],'נחל עוג') is True and good(F['empty'],'Route') is True and F['raw']=='not a gpx', [good(F['tags'],'x'),good(F['heb'],'x'),good(F['empty'],'x'),F['raw']])
        # ---- the route file cannot be fetched: the page says so with a button, and does not sit on "Loading" ----
        await pg.evaluate("()=>{ window.__g=DB.hikeGpx; DB.hikeGpx=async()=>{ throw new Error('This hike has no route file yet.'); }; const h=S.demoHikes.find(x=>x.name==='Nahal Darga'); if(h&&!h.gpxFile) h.gpxFile={name:'route.gpx',body:'x',by:'a',at:new Date().toISOString()}; }")
        await open_hike(pg,'Nahal Darga'); await pg.wait_for_selector('#hkRouteBox [data-hgpx2]'); rb=await pg.inner_text('#hkRouteBox')
        check('android: when the route file cannot be fetched the page offers the file button and does not sit on "Loading"', 'Loading' not in rb and 'Open or save the route file' in rb and await pg.locator('#hkRouteBox .hkp-map').count()==0, rb)
        await pg.evaluate("()=>{ DB.hikeGpx=window.__g; }"); await pg.click('#closeS')
        await b.close()
        # ================= a small Android phone, 360 wide (the usual Samsung width) =================
        b,pg=await start(p,'android360',ANDROID,360,740); await page_checks(pg,'android 360')
        await pg.wait_for_timeout(500); await pg.screenshot(path=OUT+'hp_5_narrow_360.png'); await b.close()
        b,pg=await start(p,'android320',ANDROID,320,640); await page_checks(pg,'android 320'); await b.close()
        # ================= a bare Android in-app web view: it does not understand app links =================
        b,pg=await start(p,'webview',WEBVIEW,411,812); await open_hike(pg,'Nahal Og')
        pb=await pg.eval_on_selector_all('#sheetWrap .hkp-card .hkp-row > .hkp-btns a','els=>els.map(a=>[a.getAttribute("href").slice(0,8),a.getAttribute("target")])')
        check('web view: map links stay ordinary links in a new tab', pb and all(x==['https://','_blank'] for x in pb), pb); await b.close()
        # ================= an iPhone-like browser that passes files to apps =================
        b,pg=await start(p,'iphone',IPHONE,390,844, SHARE_OK); await page_checks(pg,'iphone')
        ends=await pg.eval_on_selector_all('#hkRouteBox .hkp-ends a','els=>els.map(a=>[a.textContent,a.getAttribute("href"),a.getAttribute("target")||"",a.getAttribute("rel")||""])')
        check('iphone: map links are ordinary links in a new tab', ends[:2]==[['Google Maps',G+s_ll]+NEW,['Waze','https://waze.com/ul?ll='+s_ll+'&navigate=yes']+NEW], ends[:2])
        await pg.click('[data-hgpx]'); await pg.wait_for_selector('#hkModal [data-g="share"]'); await pg.click('#hkModal [data-g="share"]'); await pg.wait_for_timeout(300)
        sh=await pg.evaluate('()=>window.__shared')
        check('iphone: Open in a hiking app passes the whole file, named after the hike', sh and sh['n']==1 and sh['name']=='Nahal-Og-lower-canyon.gpx' and sh['type']=='application/gpx+xml' and sh['text'].startswith('<?xml') and sh['text'].count('<trkpt')==48 and await pg.locator('#hkModal').count()==0, sh and {k:sh[k] for k in ('n','name','type')})
        await b.close()
        # ================= a browser that offers to pass files and then refuses =================
        b,pg=await start(p,'refused',IPHONE,390,844, SHARE_REFUSED); await open_hike(pg,'Nahal Og')
        await pg.click('[data-hgpx]'); await pg.wait_for_selector('#hkModal [data-g="share"]'); await pg.click('#hkModal [data-g="share"]'); await pg.wait_for_timeout(300)
        mt=await pg.inner_text('#hkModal')
        check('refused: when the phone will not pass the file, the box says so and shows the other way, with no dead button left', await pg.locator('#hkModal [data-g="share"]').count()==0 and 'would not pass the file' in mt and 'Save the file' in mt and 'open the file from there' in mt, mt)
        await b.close()
        # ================= a computer =================
        b,pg=await start(p,'desk',None,1154,700); await page_checks(pg,'desk')
        ends=await pg.eval_on_selector_all('#hkRouteBox .hkp-ends a','els=>els.map(a=>[a.getAttribute("href"),a.getAttribute("target")])')
        check('desk: map links are ordinary links in a new tab', ends[0]==[G+s_ll,'_blank'], ends[:2])
        await pg.wait_for_timeout(500); await pg.screenshot(path=OUT+'hp_desk_1_top.png'); await b.close()
    bad=[n for n,c in res if not c]
    for e in errs: print('ERR',e)
    print(f'\n{len(res)} checks, {len(bad)} failed, {len(errs)} page errors'); sys.exit(1 if bad or errs else 0)
asyncio.run(main())
