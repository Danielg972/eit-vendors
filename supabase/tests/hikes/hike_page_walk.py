# Hike page (D-34): the page's sections, map links that ask Android for the app, the route drawn on the page, and how
# a route file is handed over. Opens index.html in preview mode (sample data) in three kinds of browser:
# an Android phone, an iPhone-like browser that can pass files to apps, and a computer.
# Needs playwright with chromium; the page is handed to the browser from the file, so no server is needed. Pictures go to argv[1].
import asyncio, os, sys, json
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/hike_page').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]
PAGE=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','..','index.html'),encoding='utf-8').read()
def check(n,c,d=''):
    res.append((n,bool(c))); print(('PASS ' if c else 'FAIL ')+n+((' :: '+str(d)[:400]) if not c else ''))
ANDROID='Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Mobile Safari/537.36'
IPHONE='Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'
G='https://www.google.com/maps/search/?api=1&query='
def intent(url, pkg):
    from urllib.parse import quote
    rest=url[len('https://'):]
    return 'intent://'+rest+'#Intent;scheme=https;package='+pkg+';S.browser_fallback_url='+quote(url, safe="-_.!~*'()")+';end'
SHARE_OK="navigator.canShare=()=>true; navigator.share=async d=>{ window.__shared={n:d.files.length,name:d.files[0].name,type:d.files[0].type,text:await d.files[0].text()}; };"
SHARE_REFUSED="navigator.canShare=()=>true; navigator.share=async()=>{ const e=new Error('Permission denied'); e.name='NotAllowedError'; throw e; };"
async def open_hike(pg, name):
    await pg.click('[data-tab="hikes"]'); await pg.wait_for_selector('#hkResults .row')
    await pg.click(f'#hkResults .row:has-text("{name}")'); await pg.wait_for_selector('#sheetWrap .hkp-card')
async def run(p, tag, ua, w, h, init=''):
    b=await p.chromium.launch(); kw=dict(viewport={'width':w,'height':h}, device_scale_factor=2, accept_downloads=True)
    if ua: kw.update(user_agent=ua, has_touch=True, is_mobile=True)
    ctx=await b.new_context(**kw)
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}"+init)
    async def serve(route): await route.fulfill(body=PAGE, content_type='text/html; charset=utf-8')
    await ctx.route('**/index.html', serve)
    pg=await ctx.new_page(); pg.on('pageerror', lambda e: errs.append(tag+' pageerror: '+str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('[data-tab="hikes"]')
    over=lambda: pg.evaluate('()=>document.documentElement.scrollWidth>document.documentElement.clientWidth+1')
    inside=lambda: pg.evaluate('()=>{ const s=document.querySelector(".sheet-body"); return [...s.querySelectorAll("*")].filter(e=>e.getBoundingClientRect().right>s.getBoundingClientRect().right+1).map(e=>e.className||e.tagName).slice(0,5); }')
    # ---- the page's sections, on a hike with everything: a park, markers, a route file, reports ----
    await open_hike(pg, 'Nahal Og')
    heads=await pg.eval_on_selector_all('#sheetWrap .hkp-h, #sheetWrap .panel h3','els=>els.map(e=>e.textContent)')
    check(tag+': the page is in sections, in this order', heads==['Getting there','The trail','Important notes','From colleagues who walked it','Before every trip'], heads)
    facts=await pg.eval_on_selector_all('#sheetWrap .hkp-fact','els=>els.map(e=>[e.querySelector("span").textContent,e.querySelector("b").textContent,e.querySelector("b").scrollWidth<=e.querySelector("b").clientWidth+1])')
    check(tag+': the key facts lead the page, each on one line', facts==[['Distance','5 km',True],['Usual time','3–4 h',True],['Difficulty','Moderate',True]], facts)
    check(tag+': nothing runs off the side of the page', not await over() and await inside()==[], await inside())
    await pg.wait_for_selector('#hkRouteBox svg polyline')
    rt=await pg.inner_text('#hkRoute')
    check(tag+': the route is drawn on the page with its length and climb', all(x in rt for x in ('A recorded route is on file','Length of the recording','Climb','Descent','A sketch of the recording, not a map','Where the recording starts','Where the recording ends')), rt)
    pts=await pg.eval_on_selector('#hkRouteBox polyline','e=>e.getAttribute("points").trim().split(/\\s+/).map(p=>p.split(",").map(Number))')
    check(tag+': the line stays inside its frame', len(pts)>=40 and all(0<=x<=320 and 0<=y<=200 for x,y in pts), pts[:3])
    ends=await pg.eval_on_selector_all('#hkRouteBox .hkp-ends a','els=>els.map(a=>[a.textContent,a.getAttribute("href"),a.getAttribute("target")||"",a.getAttribute("rel")||""])')
    return b, ctx, pg, ends, over, inside
async def main():
    async with async_playwright() as p:
        # ===== an Android phone =====
        b,ctx,pg,ends,over,inside=await run(p,'android',ANDROID,411,812, SHARE_REFUSED)
        s_ll='31.800000,35.400000'
        check('android: the recording\'s start opens the Google Maps app and Waze themselves, with the web address as the way out', len(ends)==4 and ends[0]==['Google Maps',intent(G+s_ll,'com.google.android.apps.maps'),'',''] and ends[1]==['Waze',intent('https://waze.com/ul?ll='+s_ll+'&navigate=yes','com.waze'),'',''], ends[:2])
        pl=await pg.eval_on_selector_all('#sheetWrap .hkp-card .hkp-btns a','els=>els.map(a=>[a.textContent,a.getAttribute("href").slice(0,9),a.getAttribute("target")||""])')
        check('android: start and end each have a Google Maps and a Waze button that ask for the app', pl[:4]==[['Google Maps','intent://',''],['Waze','intent://',''],['Google Maps','intent://',''],['Waze','intent://','']], pl)
        tiles=await pg.eval_on_selector_all('#sheetWrap .actions a.act','els=>els.map(a=>[a.textContent.trim(),a.getAttribute("href").slice(0,9),a.getAttribute("target")||""])')
        check('android: the Waze and Google Maps tiles at the top ask for the app too', tiles==[['Waze','intent://',''],['Google Maps','intent://','']], tiles)
        other=await pg.eval_on_selector_all('#sheetWrap .panel a.hk-link','els=>els.map(a=>[a.getAttribute("href").slice(0,8),a.target])')
        check('android: a link that is not a map stays an ordinary link in a new tab', other and all(o==['https://','_blank'] for o in other), other)
        await pg.screenshot(path=OUT+'hp_1_top.png')
        await pg.eval_on_selector('#hkRoute','e=>e.scrollIntoView({block:"start"})'); await pg.wait_for_timeout(300); await pg.screenshot(path=OUT+'hp_2_route.png')
        await pg.click('[data-hgpx]'); await pg.wait_for_selector('#hkModal')
        mt=await pg.inner_text('#hkModal')
        check('android: the route file box does not offer what Android refuses; it says how to do it', await pg.locator('#hkModal [data-g="share"]').count()==0 and 'Save the file' in mt and 'open the file from there' in mt and 'Nothing can open the file until one is installed' in mt and 'Israel Hiking Map' in mt and 'Amud Anan' in mt, mt)
        await pg.screenshot(path=OUT+'hp_3_route_file.png')
        async with pg.expect_download() as dl: await pg.click('#hkModal [data-g="save"]')
        d=await dl.value; body=open(await d.path(),encoding='utf-8').read()
        check('android: the saved file is named after the hike and is a whole GPX file', d.suggested_filename=='Nahal-Og-lower-canyon.gpx' and body.startswith('<?xml version="1.0" encoding="UTF-8"?>\n<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle"><metadata><name>Nahal Og, lower canyon</name></metadata>') and '<trk><name>Nahal Og, lower canyon</name><trkseg>' in body and body.rstrip().endswith('</trkseg></trk></gpx>') and body.count('<trkpt')==48, body[:260])
        import xml.dom.minidom as md
        try: doc=md.parseString(body.encode('utf-8')); ok=doc.documentElement.tagName=='gpx' and len(doc.getElementsByTagName('trkpt'))==48
        except Exception as e: ok=False
        check('android: the saved file reads as correct XML with every point', ok)
        await pg.click('#hkModal [data-g="x"]'); await pg.click('#closeS')
        # a hike whose start and end are only pasted Google Maps links (as the owner's first hike is)
        await pg.evaluate("()=>0")
        await b.close()
        # ===== an iPhone-like browser that passes files to apps =====
        b,ctx,pg,ends,over,inside=await run(p,'iphone',IPHONE,390,844, SHARE_OK)
        check('iphone: map links are ordinary links in a new tab', ends[0][1]==G+s_ll and ends[0][2]=='_blank' and ends[1][1]=='https://waze.com/ul?ll='+s_ll+'&navigate=yes', ends[:2])
        await pg.click('[data-hgpx]'); await pg.wait_for_selector('#hkModal [data-g="share"]'); await pg.click('#hkModal [data-g="share"]'); await pg.wait_for_timeout(300)
        sh=await pg.evaluate('()=>window.__shared')
        check('iphone: Open in a hiking app passes the whole file, named after the hike', sh and sh['n']==1 and sh['name']=='Nahal-Og-lower-canyon.gpx' and sh['type']=='application/gpx+xml' and sh['text'].startswith('<?xml') and sh['text'].count('<trkpt')==48 and await pg.locator('#hkModal').count()==0, sh and {k:sh[k] for k in ('n','name','type')})
        await b.close()
        # ===== a browser that offers to pass files and then refuses (what Android did before this change) =====
        b,ctx,pg,ends,over,inside=await run(p,'refused',IPHONE,390,844, SHARE_REFUSED)
        await pg.click('[data-hgpx]'); await pg.wait_for_selector('#hkModal [data-g="share"]'); await pg.click('#hkModal [data-g="share"]'); await pg.wait_for_timeout(300)
        mt=await pg.inner_text('#hkModal')
        check('refused: when the phone will not pass the file, the box says so and shows the other way, with no dead button left', await pg.locator('#hkModal [data-g="share"]').count()==0 and 'would not pass the file' in mt and 'Save the file' in mt and 'open the file from there' in mt, mt)
        await b.close()
        # ===== a computer =====
        b,ctx,pg,ends,over,inside=await run(p,'desk',None,1154,700)
        check('desk: map links are ordinary links in a new tab', ends[0][1]==G+s_ll and ends[0][2]=='_blank', ends[:2])
        await pg.screenshot(path=OUT+'hp_desk_1_top.png')
        await b.close()
    bad=[n for n,c in res if not c]
    for e in errs: print('ERR',e)
    print(f'\n{len(res)} checks, {len(bad)} failed, {len(errs)} page errors'); sys.exit(1 if bad or errs else 0)
asyncio.run(main())
