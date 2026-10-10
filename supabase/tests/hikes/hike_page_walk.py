# Hike page (D-34, D-35): the page's sections, map links that ask Android for the app, the map at the head of the page
# with the route on it (the map library is served from vendor/, the map's pictures are stand-ins made here, since the
# test machine cannot reach OpenStreetMap), the same map full screen, and how a route file is handed over. Opens index.html in preview mode (sample data) as an Android phone (two widths), an
# iPhone-like browser that can pass files to apps, a browser that offers to pass files and then refuses, and a computer.
# It also calls the page's own helpers with made-up routes and places and checks the figures and links they give.
# Needs playwright with chromium; the page is handed to the browser from the file, so no server is needed. Pictures go to argv[1].
import asyncio, os, sys, json, math, io
from PIL import Image, ImageDraw
from urllib.parse import quote
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/hike_page').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]
PAGE=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','..','index.html'),encoding='utf-8').read()
END='\n})();\n</script>'; assert PAGE.count(END)==1
HOOKED=PAGE.replace(END,'\nObject.assign(window,{S,DB,hkTrack,hkSketchHtml,hkFiguresHtml,hkProfileHtml,hkMapData,hkPlaceLL,hkGpxFileText,hkPlaceRow,hkLinkProps,hkWaze,hkGmaps,hkLoadGpx,demoHikesInit,HK_GPX_HEAD,__inl:()=>hkMapNow,__full:()=>hkFullNow});'+END)
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','..')
def tile_png():   # a stand-in for a map picture: pale ground, a grid, the words "test tile"
    im=Image.new('RGB',(256,256),(236,232,220)); d=ImageDraw.Draw(im); d.rectangle([0,0,255,255],outline=(205,198,180)); d.line([0,128,255,128],fill=(222,216,200)); d.line([128,0,128,255],fill=(222,216,200)); d.text((8,8),'test tile',fill=(170,160,140))
    b=io.BytesIO(); im.save(b,'PNG'); return b.getvalue()
def trail_png():   # a stand-in for the marked-trails picture: see-through, with one green line across it
    im=Image.new('RGBA',(256,256),(0,0,0,0)); d=ImageDraw.Draw(im); d.line([0,40,255,200],fill=(46,139,61,255),width=4)
    b=io.BytesIO(); im.save(b,'PNG'); return b.getvalue()
TILE=tile_png(); TRAIL=trail_png(); TILES=[]; TRAILS=[]; OTHER=[]
def check(n,c,d=''):
    res.append((n,bool(c))); print(("PASS " if c else "FAIL ")+n+((" :: "+str(d)[:3000]) if not c else ''))
ANDROID='Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/154.0.0.0 Mobile Safari/537.36'
WEBVIEW='Mozilla/5.0 (Linux; Android 10; SM-G973F Build/QP1A; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/154.0.0.0 Mobile Safari/537.36'
IPHONE='Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'
G='https://www.google.com/maps/search/?api=1&query='; MAPS='com.google.android.apps.maps'; WAZE='com.waze'; NEW=['_blank','noopener noreferrer']
def intent(url, pkg): return 'intent://'+url[len('https://'):]+'#Intent;scheme=https;package='+pkg+';S.browser_fallback_url='+quote(url, safe="-_.!~*'()")+';end'
SHARE_OK="navigator.canShare=()=>true; navigator.share=async d=>{ window.__shared={n:d.files.length,name:d.files[0].name,type:d.files[0].type,text:await d.files[0].text()}; };"
SHARE_REFUSED="navigator.canShare=()=>true; navigator.share=async()=>{ const e=new Error('Permission denied'); e.name='NotAllowedError'; throw e; };"
HEAD='<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle">'
async def start(p, tag, ua, w, h, init='', opts=(), geo=None):
    b=await p.chromium.launch(); kw=dict(viewport={'width':w,'height':h}, device_scale_factor=2, accept_downloads=True)
    if ua: kw.update(user_agent=ua, has_touch=True, is_mobile=True)
    ctx=await b.new_context(**kw)
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}"+init)
    async def serve(route): await route.fulfill(body=HOOKED, content_type='text/html; charset=utf-8')
    await ctx.route('**/index.html', serve)
    async def vendor(route):
        if 'no_leaflet' in opts or ('no_css' in opts and route.request.url.endswith('.css')): await route.abort(); return
        f=route.request.url.split('/vendor/')[1]; assert '..' not in f
        await route.fulfill(body=open(os.path.join(ROOT,'vendor',f),'rb').read(), content_type='text/css' if f.endswith('.css') else 'application/javascript')
    await ctx.route('**/vendor/**', vendor)
    async def tile(route):
        TILES.append(route.request.url)
        if 'no_tiles' in opts: await route.abort()
        else: await route.fulfill(body=TILE, content_type='image/png')
    await ctx.route('https://tile.openstreetmap.org/**', tile)
    async def trail(route):
        TRAILS.append(route.request.url)
        if 'no_trails' in opts: await route.abort()
        else: await route.fulfill(body=TRAIL, content_type='image/png')
    await ctx.route('https://tile.waymarkedtrails.org/**', trail)
    if geo: await ctx.grant_permissions(['geolocation']); await ctx.set_geolocation({'latitude':geo[0],'longitude':geo[1],'accuracy':12})
    pg=await ctx.new_page(); pg.on('pageerror', lambda e: errs.append(tag+' pageerror: '+str(e)))
    pg.on('request', lambda r: OTHER.append(r.url) if not r.url.startswith(('http://localhost:8765/','https://tile.openstreetmap.org/','https://tile.waymarkedtrails.org/','https://fonts.','https://cdn.jsdelivr.net/','data:','blob:')) else None)
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('[data-tab="hikes"]')
    await pg.add_style_tag(content='#demoAs,.demo-bar{display:none!important}')   # the preview's own "View as" bar is wider than a small phone
    return b, pg
async def open_hike(pg, name):
    if not await pg.locator('#hkResults').count(): await pg.click('[data-tab="hikes"]')
    await pg.wait_for_selector('#hkResults .row'); await pg.click(f'#hkResults .row:has-text("{name}")'); await pg.wait_for_selector('#sheetWrap .hkp-card')
async def full_ends(pg):   # the open map: tap each of start and end, read what it offers, close the map
    await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull .leaflet-container'); out=[]
    for i in range(await pg.evaluate('()=>{ let n=0; __full().map.eachLayer(l=>{ if(l.getPopup&&l.getPopup()) n++; }); return n; }')):
        await pg.evaluate('i=>{ const a=[]; __full().map.eachLayer(l=>{ if(l.getPopup&&l.getPopup()) a.push(l); }); a[i].openPopup(); }', i); await pg.wait_for_selector('#hkMapFull .leaflet-popup-content a')
        out.append(await pg.evaluate('i=>{ const a=[]; __full().map.eachLayer(l=>{ if(l.getPopup&&l.getPopup()) a.push(l); }); const e=a[i].getPopup().getElement().querySelector(".leaflet-popup-content"); return [e.querySelector("b").textContent, ...[...e.querySelectorAll("a")].map(a=>[a.textContent,a.getAttribute("href"),a.getAttribute("target")||"",a.getAttribute("rel")||""])]; }', i))
    await pg.click('#hkMapFull [data-x]'); return out
over=lambda pg: pg.evaluate('()=>document.documentElement.scrollWidth>document.documentElement.clientWidth+1')
inside=lambda pg: pg.evaluate('()=>{ const s=document.querySelector(".sheet-body"), R=s.getBoundingClientRect(); return [...s.querySelectorAll("*")].filter(e=>!e.closest(".hkm-map")).filter(e=>{ const r=e.getBoundingClientRect(); return r.width>0&&(r.right>R.right+1||r.left<R.left-1); }).map(e=>e.className||e.tagName).slice(0,5); }')
async def page_checks(pg, tag):
    await open_hike(pg, 'Nahal Og')
    heads=await pg.eval_on_selector_all('#sheetWrap .hkp-h, #sheetWrap .panel h3','els=>els.map(e=>e.textContent)')
    check(tag+': the page is in sections, in this order', heads==['Getting there','The trail','Important notes','From colleagues who walked it','Before every trip'], heads)
    facts=await pg.eval_on_selector_all('#sheetWrap .hkp-fact','els=>els.map(e=>{ const b=e.querySelector("b"); return [e.querySelector("span").textContent,b.textContent,b.scrollWidth<=b.clientWidth+1&&b.getBoundingClientRect().height<50]; })')
    check(tag+': the key facts lead the page and none is cut off', facts==[['Distance','5 km',True],['Usual time','3–4 h',True],['Difficulty','Moderate',True]], facts)
    check(tag+': nothing runs off the side of the page', not await over(pg) and await inside(pg)==[], await inside(pg))
    await pg.wait_for_selector('#hkMap .leaflet-container'); await pg.wait_for_selector('#hkRouteBox .hkp-stats')
    first=await pg.evaluate('()=>{ const b=document.querySelector(".sheet-body"); return [b.firstElementChild.id, b.children[1].className, Math.round(document.querySelector("#hkMap").getBoundingClientRect().width)===Math.round(b.getBoundingClientRect().width)]; }')
    check(tag+': the map leads the page, edge to edge, with the key facts right under it', first==['hkMap','hkp-facts',True], first)
    side=await pg.eval_on_selector_all('#sheetWrap .hkp-card .hkp-row > .hkp-btns','els=>els.map(b=>{ const a=[...b.querySelectorAll("a")].map(x=>Math.round(x.getBoundingClientRect().top)); return a.length<2||a[0]===a[1]; })')
    check(tag+': the Google Maps and Waze buttons of a place sit side by side', side and all(side), side)
    small=await pg.eval_on_selector_all('#sheetWrap .hkp-go','els=>els.map(e=>[e.textContent.trim(),Math.round(e.getBoundingClientRect().height*10)/10]).filter(x=>x[1]<40)')
    check(tag+': every new button is tall enough to tap', small==[], small)
async def main():
    async with async_playwright() as p:
        # ================= an Android phone, 411 wide =================
        b,pg=await start(p,'android',ANDROID,411,812, SHARE_REFUSED, geo=(31.805,35.405)); await page_checks(pg,'android')
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
        check('android: the recording gives its own length, climb, descent, lowest and highest point', want in rt and 'A recorded route is on file' in rt, [want, rt])
        M=await pg.evaluate('''()=>{ const m=__inl(), L=window.L, lines=[], tips=[]; m.eachLayer(l=>{ if(l instanceof L.Polyline&&!(l instanceof L.Polygon)) lines.push([l.getLatLngs().length,l.options.color,m.getBounds().contains(l.getBounds())]); if(l.getTooltip&&l.getTooltip()) tips.push([l.getTooltip().getContent(), l.getLatLng().lat.toFixed(6)+','+l.getLatLng().lng.toFixed(6)]); });
          const box=document.querySelector('#hkMap'), c=box.querySelector('.leaflet-container'); const att=box.querySelector('.leaflet-control-attribution'), ar=att.getBoundingClientRect(), br=box.getBoundingClientRect();
          return {lines, tips, tiles:[...box.querySelectorAll('img.leaflet-tile')].map(i=>new URL(i.src).host).filter((x,i,a)=>a.indexOf(x)===i), loaded:[...box.querySelectorAll('img.leaflet-tile')].filter(i=>i.complete&&i.naturalWidth===256).length,
            att:att.textContent.trim(), attLink:att.querySelector('a').href, attSeen:ar.width>0&&ar.top>=br.top&&ar.bottom<=br.bottom+1&&ar.left>=br.left&&ar.right<=br.right+1&&[.1,.5,.9].every(f=>att.contains(document.elementFromPoint(ar.left+ar.width*f, ar.top+ar.height/2))),
            still:[m.dragging.enabled(), m.touchZoom.enabled(), m.scrollWheelZoom.enabled(), c.classList.contains('leaflet-touch-drag'), getComputedStyle(c).touchAction], zoom:m.getZoom(), cap:document.querySelector('#hkMapCap span').textContent, dots:[...box.querySelectorAll('.leaflet-tooltip')].map(t=>{ const r=t.getBoundingClientRect(); return box.querySelector('.hkm-map').contains(document.elementFromPoint(r.left+r.width/2, r.top+r.height/2))&&r.left>=br.left&&r.right<=br.right&&r.top>=br.top&&r.bottom<=br.bottom; })}; }''')
        s_ll='%.6f,%.6f'%(pts[0][0],pts[0][1]); e_ll='%.6f,%.6f'%(pts[-1][0],pts[-1][1])
        check('android: the map shows the whole recording as a line, every point of it, inside the frame', M['lines']==[[48,'#fff',True],[48,'#b5179e',True]], M['lines'])
        check('android: start and end are marked together on the map, at the first and the last point', M['tips']==[['Start',s_ll],['End',e_ll]], M['tips'])
        check('android: the map\'s pictures come from OpenStreetMap, the marked trails over them from Waymarked Trails, both load, and both are credited on the map with links', sorted(M['tiles'])==['tile.openstreetmap.org','tile.waymarkedtrails.org'] and M['loaded']>=8 and M['att']=='© OpenStreetMap contributors, marked trails: Waymarked Trails' and M['attLink']=='https://www.openstreetmap.org/copyright' and M['attSeen'], M)
        check('android: the map on the page stays still, so a finger on it scrolls the page', M['still'][:4]==[False,False,False,False] and M['still'][4]!='none', M['still'])
        check('android: nothing lies over the map: the names of start and end are whole and seen, and the line under the map says what it is', M['dots']==[True,True] and M['cap']=='The recorded route. Open the map to move around it and to see where you are on it.', [M['dots'],M['cap']])
        pr=await pg.eval_on_selector('#hkRouteBox .hkp-prof polyline','e=>e.getAttribute("points").trim().split(/\\s+/).map(p=>p.split(",").map(Number))')
        prt=' '.join((await pg.inner_text('#hkRouteBox .hkp-prof')).split())
        check('android: height along the walk is drawn from every point, inside its frame, with the lowest and highest height beside it', len(pr)==48 and all(0<=x<=320 and 0<=y<=80 for x,y in pr) and pr[0][0]==0 and pr[-1][0]==320 and prt==f'{round(max(q[2] for q in pts))} m {round(min(q[2] for q in pts))} m Start Height along the walk {L/1000:.2f} km', [len(pr), prt])
        await pg.screenshot(path=OUT+'hp_1_top.png')
        # ---- the same map, full screen ----
        ends=await full_ends(pg)
        check('android: on the open map, start and end each offer Waze and the Google Maps app, at the first and the last point of the recording', ends==[['Where the recording starts',['Waze',intent('https://waze.com/ul?ll='+s_ll+'&navigate=yes',WAZE),'',''],['Google Maps',intent(G+s_ll,MAPS),'','']],['Where the recording ends',['Waze',intent('https://waze.com/ul?ll='+e_ll+'&navigate=yes',WAZE),'',''],['Google Maps',intent(G+e_ll,MAPS),'','']]], ends)
        await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull .leaflet-container')
        F=await pg.evaluate('''()=>{ const f=__full(), el=f.el, r=el.getBoundingClientRect(), mid=document.elementFromPoint(innerWidth/2, innerHeight/2); return {covers:r.top===0&&r.left===0&&Math.round(r.width)===innerWidth&&Math.round(r.height)===innerHeight, onTop:el.contains(mid), moves:[f.map.dragging.enabled(), f.map.touchZoom.enabled()], bar:el.querySelector('.hkmf-bar').textContent.trim().replace(/\\s+/g,' '), tools:[...el.querySelectorAll('.hkmf-tools button')].map(b=>[b.textContent.trim(), Math.round(b.getBoundingClientRect().height)>=40]), att:el.querySelector('.leaflet-control-attribution').textContent.trim(), over:document.documentElement.scrollWidth>innerWidth+1}; }''')
        check('android: a tap on the map opens it over the whole screen, where it moves and zooms, with its credit', F=={'covers':True,'onTop':True,'moves':[True,True],'bar':'Nahal Og, lower canyonClose the map','tools':[['Where am I',True],['Whole route',True],['Marked trails: on',True]],'att':'© OpenStreetMap contributors, marked trails: Waymarked Trails','over':False}, F)
        mk=await pg.evaluate('''()=>{ const a=document.querySelector('#hkMapFull [data-mapeak]'), r=a.getBoundingClientRect(); return [a.textContent.trim(), a.getAttribute('href'), a.target, a.rel, Math.round(r.height)>=40, r.right<=innerWidth&&r.bottom<=innerHeight]; }''')
        check('android: the open map offers "Open in Mapeak", an ordinary link to Mapeak\'s own map at the start of the walk', mk==['Open in Mapeak','https://mapeak.com/map/15.00/%.4f/%.4f'%(pts[0][0],pts[0][1]),'_blank','noopener noreferrer',True,True], mk)
        tr=[await pg.evaluate('()=>document.querySelectorAll("#hkMapFull img.leaflet-tile[src*=waymarkedtrails]").length')]
        await pg.click('#hkMapFull [data-trails]'); await pg.wait_for_timeout(200)
        tr+=[await pg.evaluate('()=>document.querySelectorAll("#hkMapFull img.leaflet-tile[src*=waymarkedtrails]").length'), await pg.inner_text('#hkMapFull [data-trails]'), await pg.get_attribute('#hkMapFull [data-trails]','aria-pressed'), await pg.inner_text('#hkMapFull .leaflet-control-attribution')]
        await pg.click('#hkMapFull [data-trails]'); await pg.wait_for_timeout(300)
        tr+=[await pg.evaluate('()=>document.querySelectorAll("#hkMapFull img.leaflet-tile[src*=waymarkedtrails]").length>0'), await pg.inner_text('#hkMapFull [data-trails]')]
        check('android: "Marked trails" takes the trails off the map and puts them back, and the credit follows', tr[0]>0 and tr[1:5]==[0,'Marked trails: off','false','© OpenStreetMap contributors'] and tr[5:]==[True,'Marked trails: on'], tr)
        await pg.click('#hkMapFull [data-me]'); await pg.wait_for_function('()=>{ let n=0; __full().map.eachLayer(l=>{ if(l.getTooltip&&l.getTooltip()&&l.getTooltip().getContent()==="You") n++; }); return n===1; }')
        me=await pg.evaluate('()=>{ let p=null; const m=__full().map; m.eachLayer(l=>{ if(l.getTooltip&&l.getTooltip()&&l.getTooltip().getContent()==="You") p=l.getLatLng(); }); return [p.lat,p.lng,m.getBounds().contains(p)]; }')
        check('android: "Where am I" puts the member\'s own place on the map, with the route still in view', me==[31.805,35.405,True], me)
        await pg.wait_for_timeout(400); await pg.screenshot(path=OUT+'hp_2_map_open.png')
        await pg.keyboard.press('Escape'); await pg.wait_for_timeout(100)
        check('android: Escape closes the map first and leaves the hike\'s page open', await pg.locator('#hkMapFull').count()==0 and await pg.locator('#sheetWrap .hkp-card').count()>0 and await pg.evaluate('()=>__full()===null'))
        await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull'); await pg.click('#hkMapFull [data-x]')
        check('android: "Close the map" closes it', await pg.locator('#hkMapFull').count()==0)
        check('android: no part of the member\'s place, and nothing else, went anywhere but the map\'s own pictures', OTHER==[] and all(u.startswith('https://tile.openstreetmap.org/') and u.endswith('.png') and '?' not in u for u in TILES) and len(TILES)>0 and all(u.startswith('https://tile.waymarkedtrails.org/hiking/') and u.endswith('.png') and '?' not in u for u in TRAILS) and len(TRAILS)>0, [OTHER[:3], TILES[:2]])
        pb=await pg.eval_on_selector_all('#sheetWrap .hkp-card .hkp-row:not(#hkRoute) > .hkp-btns a','els=>els.map(a=>[a.textContent,a.getAttribute("href"),a.getAttribute("target")||""])')
        check('android: start and end each have a Google Maps and a Waze button that ask for the app, by the words of the place', pb==[['Google Maps',intent(G+quote('Og trailhead, by Almog',safe="-_.!~*'()"),MAPS),''],['Waze',intent('https://waze.com/ul?q='+quote('Og trailhead, by Almog',safe="-_.!~*'()")+'&navigate=yes',WAZE),''],['Google Maps',intent(G+quote('Road 90, north of the Dead Sea',safe="-_.!~*'()"),MAPS),''],['Waze',intent('https://waze.com/ul?q='+quote('Road 90, north of the Dead Sea',safe="-_.!~*'()")+'&navigate=yes',WAZE),'']], pb)
        tiles=await pg.eval_on_selector_all('#sheetWrap .actions a.act','els=>els.map(a=>[a.textContent.trim(),a.getAttribute("href").slice(0,9),a.getAttribute("target")||""])')
        check('android: the Waze and Google Maps tiles at the top ask for the app too, and say they lead to the start', tiles==[['Wazeto the start','intent://',''],['Google Mapsto the start','intent://','']], tiles)
        await pg.eval_on_selector('.hkp-top','e=>e.scrollIntoView({block:"start"})'); await pg.wait_for_timeout(300); await pg.screenshot(path=OUT+'hp_3_below_map.png')
        await pg.eval_on_selector('#hkRoute','e=>e.scrollIntoView({block:"start"})'); await pg.wait_for_timeout(300); await pg.screenshot(path=OUT+'hp_4_trail.png')
        await pg.click('[data-hgpx]'); await pg.wait_for_selector('#hkModal'); mt=await pg.inner_text('#hkModal')
        check('android: the route file box does not offer what Android refuses; it says how to do it', await pg.locator('#hkModal [data-g="share"]').count()==0 and 'Tap Save the file' in mt and 'Tap Open on it' in mt and 'Your phone asks which app to open it with. Choose Mapeak or Amud Anan.' in mt and 'Nothing can open the file until one is installed: Mapeak or Amud Anan' in mt and 'Mapeak is the new name of Israel Hiking Map' in mt and await pg.locator('#hkModal #hkMS').is_hidden() and [await pg.get_attribute('#hkModal .hkp-steps a >> nth=0','href'), await pg.get_attribute('#hkModal .hkp-steps a >> nth=1','href')]==['https://mapeak.com/','https://amudanan.co.il/'], mt)
        await pg.screenshot(path=OUT+'hp_5_route_file.png')
        async with pg.expect_download() as dl: await pg.click('#hkModal [data-g="save"]')
        d=await dl.value; body=open(await d.path(),encoding='utf-8').read()
        sv=[await pg.locator('#hkModal #hkMS').is_visible(), await pg.inner_text('#hkModal #hkMS')]
        check('android: once the file is saved the box says what to tap next, and it stays', sv==[True,"Saved. Now tap Open on Chrome's message at the bottom of the screen, then choose Mapeak or Amud Anan."], sv)
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
        pins=await pg.evaluate('()=>{ const tips=[]; __inl().eachLayer(l=>{ if(l.getTooltip&&l.getTooltip()) tips.push(l.getTooltip().getContent()); }); return tips; }') if await pg.locator('#hkMap .leaflet-container').count() else None
        await pg.wait_for_timeout(400); await pg.screenshot(path=OUT+'hp_6_link_only_places.png'); await pg.click('#closeS')
        # ---- no recording, but the start and end carry a point each: the map shows the two together ----
        await pg.evaluate("()=>{ const h=S.demoHikes.find(x=>x.name==='Nahal Darga'); h.start_place='Metzoke Dragot https://www.google.com/maps/@31.5903,35.3921,16z'; h.end_place='Road 90 https://waze.com/ul?ll=31.5975,35.4071&navigate=yes'; h.is_loop=false; h.gpxFile=null; }")
        await open_hike(pg,'Nahal Darga'); await pg.wait_for_selector('#hkMap .leaflet-container')
        two=await pg.evaluate('''()=>{ const m=__inl(), L=window.L, tips=[], lines=[]; m.eachLayer(l=>{ if(l.getTooltip&&l.getTooltip()) tips.push([l.getTooltip().getContent(), l.getLatLng().lat, l.getLatLng().lng, m.getBounds().contains(l.getLatLng())]); else if(l instanceof L.Polyline) lines.push(1); }); return {tips, lines:lines.length, cap:document.querySelector('#hkMapCap span').textContent}; }''')
        check('android: a hike with no recording shows its start and end together on the map, from the points their map links carry, and says no route is recorded', two=={'tips':[['Start',31.5903,35.3921,True],['End',31.5975,35.4071,True]],'lines':0,'cap':'Nobody has added a recorded route yet. The map shows the start and the end only.'}, two)
        await pg.wait_for_timeout(300); await pg.screenshot(path=OUT+'hp_7_start_end_only.png')
        await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull'); tl=await pg.eval_on_selector_all('#hkMapFull .hkmf-tools button','els=>els.map(b=>b.textContent.trim())'); await pg.click('#hkMapFull [data-x]')
        check('android: its open map offers "Start and end", not a route that is not there', tl==['Where am I','Start and end','Marked trails: on'], tl)
        check('android: closing the map puts the cursor back on the button that opened it', await pg.evaluate('()=>document.activeElement&&document.activeElement.hasAttribute("data-hmap")')); await pg.click('#closeS')
        # ---- only the end carries a point ----
        await pg.evaluate("()=>{ const h=S.demoHikes.find(x=>x.name==='Nahal Darga'); h.start_place='Metzoke Dragot car park'; h.end_place='Road 90 https://waze.com/ul?ll=31.5975,35.4071&navigate=yes'; }")
        await open_hike(pg,'Nahal Darga'); await pg.wait_for_selector('#hkMap .leaflet-container'); cap1=await pg.inner_text('#hkMapCap span'); e1=await full_ends(pg)
        check('android: a hike whose end alone carries a point shows that one point, says so, and the point offers the way there', cap1=='Nobody has added a recorded route yet. The map shows the end only.' and len(e1)==1 and e1[0][0]=='End' and e1[0][1][0]=='Waze' and 'll=31.597500,35.407100' in e1[0][1][1], [cap1,e1]); await pg.click('#closeS')
        await pg.evaluate("()=>{ const h=S.demoHikes.find(x=>x.name==='Nahal Darga'); h.start_place='Metzoke Dragot car park'; h.end_place=''; h.is_loop=true; }")
        await open_hike(pg,'Nahal Darga'); await pg.wait_for_timeout(300)
        check('android: a hike with no recording and no point has no map, and the page starts with its facts; short map links carry no point either', await pg.locator('#hkMap').count()==0 and await pg.locator('#hkMapCap').count()==0 and pins is None, pins); await pg.click('#closeS')
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
            lines:(()=>{ const d=document.createElement('div'); d.innerHTML=hkSketchHtml(hkTrack(H+'<trk><trkseg>'+p('31.000000','35.000000')+p('31.010000','35.000000')+'</trkseg><trkseg>'+p('32.000000','35.000000')+p('32.010000','35.000000')+'</trkseg></trk></gpx>')); return [d.querySelectorAll('polyline').length, /NaN|Infinity/.test(d.innerHTML)]; })(),
            same_pt:(()=>{ const t=hkTrack(H+'<trk><trkseg>'+p('31.000000','35.000000')+p('31.000000','35.000000')+'</trkseg></trk></gpx>'), d=document.createElement('div'); d.innerHTML=hkSketchHtml(t)+hkFiguresHtml(t); const md=hkMapData({},t); return [/NaN|Infinity/.test(d.innerHTML), d.querySelector('.hkp-map svg').querySelectorAll('circle').length, d.textContent.includes('Start and end'), md.end, md.same, d.querySelectorAll('.hkp-prof').length]; })(),
            data:(()=>{ const t=hkTrack(H+'<trk><trkseg>'+p('31.000000','35.000000','5')+p('31.010000','35.000000','6')+'</trkseg><trkseg>'+p('32.000000','35.000000','7')+p('32.010000','35.000000','8')+'</trkseg></trk></gpx>'), d=hkMapData({start_place:'https://www.google.com/maps/@1,2,3z'},t); return [d.segs.map(s=>s.length), d.segs[0][0].length, d.start, d.end, d.rec, hkProfileHtml(t)]; })(),
            ll:[hkPlaceLL('Gate https://www.google.com/maps/@31.5,35.4,15z'), hkPlaceLL('https://waze.com/ul?ll=31.6,35.5'), hkPlaceLL('https://maps.app.goo.gl/EnkUGVzWA2exJgkp6'), hkPlaceLL('Gate 31.5,35.4'), hkPlaceLL('https://evil.example/?q=31.5,35.4'), hkPlaceLL('https://www.google.com/maps/@0.0,0.0,3z'), hkPlaceLL(''), hkPlaceLL('https://www.google.com/maps/place/Ein+Gedi/@31.4601,35.3852,15z/data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d31.4675!4d35.3920'), hkPlaceLL('https://www.google.com/maps/place/Ein+Gedi/@31.4601,35.3852,15z')],
            nodata:[hkMapData({start_place:'car park',end_place:'gate'},null), hkMapData({start_place:'https://waze.com/ul?ll=31.6,35.5',is_loop:true,end_place:'https://waze.com/ul?ll=1.5,2.5'},null), hkMapData({end_place:'https://waze.com/ul?ll=31.6,35.5'},null)] }; }""")
        km=lambda a,b: round(hav(a,b))
        check('helpers: two points 0.01 of a degree apart are about 1,112 m, climbing 30 m', T['two']=={'segs':[2],'len':km((31,35),(31.01,35)),'up':30,'down':0,'lo':100,'hi':130,'start':'31.000000,35.000000','end':'31.010000,35.000000','same':False} and 1105<T['two']['len']<1120, T['two'])
        check('helpers: marked spots are not counted as points of the route, and no heights means no climb figures', T['wpt']['segs']==[2] and T['wpt']['start']=='31.000000,35.000000' and T['wpt']['up'] is None and T['wpt']['lo'] is None, T['wpt'])
        check('helpers: two parts of a track far apart are two lines; the gap between them is neither counted nor drawn', T['gap']['segs']==[2,2] and T['gap']['len']==2*km((31,35),(31.01,35)) and T['gap']['end']=='32.010000,35.000000' and T['lines']==[2,False], [T['gap'],T['lines']])
        check('helpers: a file with a track and a route uses the track only', T['rte_and_trk']['segs']==[2] and T['rte_and_trk']['len']==km((31,35),(31.01,35)), T['rte_and_trk'])
        check('helpers: a file with a route only is read, south and west of zero too', T['rte_only']['segs']==[2] and T['rte_only']['start']=='-31.000000,-35.000000' and T['rte_only']['len']==km((-31,-35),(-31.01,-35)), T['rte_only'])
        check('helpers: a flat walk whose height reading jumps 8 m back and forth shows no climb', T['noisy']['up']==0 and T['noisy']['down']==0 and T['noisy']['lo']==96 and T['noisy']['hi']==104, T['noisy'])
        check('helpers: a walk that comes back to within 80 m of its start is "starts and ends" in one place; one point or none is no route', T['loop']['same'] is True and T['two']['same'] is False and T['one'] is None and T['none'] is None and T['same_pt']==[False,1,True,None,True,0], [T['loop'],T['one'],T['none'],T['same_pt']])
        check('helpers: the map is given each part of a track as its own line, the first and last point of the recording, and never the point of a pasted link when there is a recording; heights that hardly differ draw no profile', T['data']==[[2,2],2,[31,35],[32.01,35],True,''], T['data'])
        check('helpers: a start or end gives a point only from a Google Maps or Waze link that carries one: not from a short link, bare numbers, another site, or 0,0', T['ll'][:7]==[[31.5,35.4],[31.6,35.5],None,None,None,None,None], T['ll'])
        check('helpers: a Google link to a named place gives the place\'s own point, never the middle of the screen it was copied from', T['ll'][7:]==[[31.4675,35.392],None], T['ll'][7:])
        check('helpers: with no recording the map gets the points of start and end; a loop has one; no points, no map', T['nodata']==[None,{'segs':[],'start':[31.6,35.5],'end':None,'same':True,'rec':False},{'segs':[],'start':None,'end':[31.6,35.5],'same':False,'rec':False}], T['nodata'])
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
        await pg.wait_for_timeout(200)
        check('android: when the route file cannot be fetched the page says so, offers the file button, does not sit on "Loading", and shows no empty map', 'Loading' not in rb and 'The route did not load just now.' in rb and 'Open or save the route file' in rb and await pg.locator('#hkRouteBox .hkp-prof').count()==0 and await pg.locator('#hkMap').count()==0, rb)
        await pg.evaluate("()=>{ DB.hikeGpx=window.__g; }"); await pg.click('#closeS')
        await b.close()
        # ================= a small Android phone, 360 wide (the usual Samsung width) =================
        b,pg=await start(p,'android360',ANDROID,360,740); await page_checks(pg,'android 360')
        await pg.wait_for_timeout(500); await pg.screenshot(path=OUT+'hp_10_narrow_360.png'); await b.close()
        b,pg=await start(p,'android320',ANDROID,320,640); await page_checks(pg,'android 320'); await b.close()
        # ================= a bare Android in-app web view: it does not understand app links =================
        b,pg=await start(p,'webview',WEBVIEW,411,812); await open_hike(pg,'Nahal Og')
        pb=await pg.eval_on_selector_all('#sheetWrap .hkp-card .hkp-row > .hkp-btns a','els=>els.map(a=>[a.getAttribute("href").slice(0,8),a.getAttribute("target")])')
        check('web view: map links stay ordinary links in a new tab', pb and all(x==['https://','_blank'] for x in pb), pb); await b.close()
        # ================= an iPhone-like browser that passes files to apps =================
        b,pg=await start(p,'iphone',IPHONE,390,844, SHARE_OK); await page_checks(pg,'iphone')
        ends=await full_ends(pg)
        check('iphone: map links are ordinary links in a new tab', ends[0]==['Where the recording starts',['Waze','https://waze.com/ul?ll='+s_ll+'&navigate=yes']+NEW,['Google Maps',G+s_ll]+NEW], ends[:1])
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
        ends=await full_ends(pg)
        check('desk: map links are ordinary links in a new tab', ends[0][2]==['Google Maps',G+s_ll]+NEW, ends[:1])
        await pg.wait_for_timeout(500); await pg.screenshot(path=OUT+'hp_desk_1_top.png'); await b.close()
        # ================= the map's pictures do not come (no connection to the map server) =================
        b,pg=await start(p,'no_tiles',ANDROID,411,812, opts=('no_tiles',)); await open_hike(pg,'Nahal Og'); await pg.wait_for_selector('#hkMap .leaflet-container'); await pg.wait_for_selector('#hkMap .hkm-note:not([hidden])')
        nt=await pg.evaluate('()=>{ const lines=[]; __inl().eachLayer(l=>{ if(l instanceof L.Polyline) lines.push(l.getLatLngs().length); }); const n=document.querySelector("#hkMap .hkm-note"), r=n.getBoundingClientRect(), o=document.querySelector("#hkMap .leaflet-control-attribution").getBoundingClientRect(); return [n.textContent, lines, r.bottom<=o.top]; }')
        check('no map pictures: the page says the map did not load, the line and its points are still drawn, and the note does not cover the credit', nt==['The map did not load. Check the connection.',[48,48],True], nt)
        await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull .hkm-note:not([hidden])')
        nf=await pg.evaluate('()=>{ const n=document.querySelector("#hkMapFull .hkm-note").getBoundingClientRect(), o=document.querySelector("#hkMapFull .leaflet-control-attribution").getBoundingClientRect(); return [n.left>=8, n.right<=o.left||n.bottom<=o.top||n.top>=o.bottom]; }')
        check('no map pictures: on the open map the note keeps clear of the credit too', nf==[True,True], nf); await pg.click('#hkMapFull [data-x]')
        await pg.screenshot(path=OUT+'hp_8_no_map_pictures.png'); await b.close()
        # ================= the map library itself cannot load =================
        b,pg=await start(p,'no_leaflet',ANDROID,411,812, opts=('no_leaflet',)); await open_hike(pg,'Nahal Og'); await pg.wait_for_selector('#hkMap.plain svg polyline'); await pg.wait_for_selector('#hkRouteBox .hkp-stats')
        fb=await pg.evaluate('()=>[document.querySelectorAll("#hkMap polyline").length, document.querySelector("#hkMap polyline").getAttribute("points").trim().split(/\\s+/).length, document.querySelector("#hkMap").textContent.includes("The map could not load. This is the line of the recording only."), !!document.querySelector("#hkMapCap"), !!document.querySelector("[data-hmap]"), document.querySelectorAll("script[src*=leaflet],link[href*=leaflet]").length]')
        check('no map library: the line of the recording is drawn in the map\'s place, with words that say so, and nothing dead is left', fb==[1,48,True,False,False,0] and not await over(pg) and await inside(pg)==[], [fb, await inside(pg)])
        await pg.screenshot(path=OUT+'hp_9_no_map_library.png'); await pg.click('#closeS')
        await pg.evaluate("()=>{ const h=S.demoHikes.find(x=>x.name==='Nahal Darga'); h.start_place='https://www.google.com/maps/@31.5903,35.3921,16z'; h.gpxFile=null; }")
        await open_hike(pg,'Nahal Darga'); await pg.wait_for_function('()=>!document.querySelector("#hkMap")')
        check('no map library: a hike with only a start point shows no map and no empty box', await pg.locator('#hkMapCap').count()==0); await b.close()
        # ================= the marked-trails pictures do not come, on a narrow phone =================
        b,pg=await start(p,'no_trails',ANDROID,320,640, opts=('no_trails',)); await open_hike(pg,'Nahal Og'); await pg.wait_for_selector('#hkMap .leaflet-container'); await pg.wait_for_timeout(600)
        n1=await pg.evaluate('()=>[document.querySelector("#hkMap .hkm-note").hidden, [...document.querySelectorAll("#hkMap img.leaflet-tile[src*=openstreetmap]")].filter(i=>i.complete&&i.naturalWidth===256).length>0]')
        await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull'); await pg.wait_for_timeout(400)
        n2=await pg.evaluate('()=>{ const els=[...document.querySelectorAll("#hkMapFull .hkmf-tools > *")].map(e=>e.getBoundingClientRect()); return [document.querySelector("#hkMapFull .hkm-note").hidden, els.length, els.every(r=>r.left>=0&&r.right<=innerWidth&&r.bottom<=innerHeight&&r.height>=40), document.documentElement.scrollWidth<=innerWidth+1, document.querySelector("#hkMapFull .hkmf-map").getBoundingClientRect().height>200]; }')
        check('no trail pictures: the map itself is unharmed and says nothing is wrong; at 320 wide the four buttons of the open map fit, and the map keeps its room', n1==[True,True] and n2==[True,4,True,True,True], [n1,n2])
        await pg.screenshot(path=OUT+'hp_13_open_map_320.png'); await b.close()
        # ================= the library's style sheet alone fails: still no half-drawn map =================
        b,pg=await start(p,'no_css',ANDROID,411,812, opts=('no_css',)); await open_hike(pg,'Nahal Og'); await pg.wait_for_selector('#hkMap.plain svg polyline')
        check('no style sheet: a map library that came without its style sheet is not used: the line is drawn in the map\'s place and no map picture is asked for', await pg.locator('.leaflet-container').count()==0 and await pg.locator('#hkMapCap').count()==0 and not [u for u in TILES if 'no_css' in u], None); await b.close()
        # ================= a phone that is slow to find itself, then refuses =================
        GEO="window.__w=[]; window.__c=[]; let id=0; Object.defineProperty(navigator,'geolocation',{value:{watchPosition:(ok,no)=>{ id++; window.__w.push(id); window.__no=no; window.__ok=ok; return id; }, clearWatch:i=>window.__c.push(i), getCurrentPosition:()=>{}}});"
        b,pg=await start(p,'slow_gps',ANDROID,411,812, GEO); await open_hike(pg,'Nahal Og'); await pg.wait_for_selector('#hkMap .leaflet-container'); await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull')
        await pg.click('#hkMapFull [data-me]'); await pg.evaluate('()=>window.__no({code:3,message:"Timeout expired"})'); await pg.wait_for_selector('.toast'); t1=await pg.inner_text('.toast')
        await pg.click('#hkMapFull [data-me]'); await pg.click('#hkMapFull [data-me]')
        await pg.evaluate('()=>window.__ok({coords:{latitude:31.806,longitude:35.404,accuracy:20},timestamp:Date.now()})'); await pg.wait_for_timeout(200)
        seen=await pg.evaluate('()=>{ let p=null; const m=__full().map; m.eachLayer(l=>{ if(l.getTooltip&&l.getTooltip()&&l.getTooltip().getContent()==="You") p=l.getLatLng(); }); return p&&m.getBounds().contains(p); }')
        await pg.click('#hkMapFull [data-x]'); w1=await pg.evaluate('()=>[window.__w, window.__c]')
        check('slow to find: the page says it is still looking, asks the phone once however often the button is tapped, shows the place when it comes, and stops asking when the map closes', t1.startswith('Still looking for where you are.') and seen is True and w1[0]==[1] and 1 in w1[1], [t1,seen,w1])
        await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull'); await pg.click('#hkMapFull [data-me]'); await pg.evaluate('()=>window.__no({code:1,message:"User denied Geolocation"})'); await pg.wait_for_selector('#hkLocModal'); t2=' '.join((await pg.inner_text('#hkLocModal')).split())
        box=await pg.evaluate('()=>{ const m=document.querySelector("#hkLocModal"), c=m.querySelector(".modal-card"), r=c.getBoundingClientRect(), mid=document.elementFromPoint(r.left+r.width/2, r.top+20); return [c.contains(mid), r.left>=0&&r.right<=innerWidth&&r.top>=0&&r.bottom<=innerHeight, document.activeElement.dataset.g, [...c.querySelectorAll("button")].every(b=>b.getBoundingClientRect().height>=40)]; }')
        check('refused: a box that stays says, for an Android phone in Chrome, the two switches that decide it, in order: Chrome\'s own Location switch, then the phone\'s permission for Chrome', all(x in t2 for x in ('Allow location','Your phone did not say where you are','Two switches decide this. Check both:','1. In Chrome','Tap the three dots at the top right of Chrome.','Tap Site settings, then Location, and turn the switch on.','If this site is listed there as blocked, tap it and choose Allow.','2. In the phone\'s Settings','Tap Apps, then Chrome, then Permissions, then Location.','Choose Allow only while using the app.','3. Back here','Tap Try again. When the phone asks, tap Allow.','A site sees where you are only after you tap Allow for that site.','It is not sent to Eretz Israel Tours or to anyone else.','Close')) and t2.index('1. In Chrome')<t2.index('2. In the phone')<t2.index('3. Back here') and 'iPhone' not in t2 and 'address bar' not in t2 and 'This app runs on Chrome' not in t2, t2)
        check('refused: the box lies over the map, fits the screen, and its buttons are tall enough', box==[True,True,'again',True], box)
        await pg.screenshot(path=OUT+'hp_11_allow_location.png')
        await pg.click('#hkLocModal [data-g="again"]'); await pg.wait_for_timeout(150); w2a=await pg.evaluate('()=>window.__w.slice()'); g2=await pg.locator('#hkLocModal').count()
        await pg.evaluate('()=>window.__no({code:1,message:"User denied Geolocation"})'); await pg.wait_for_selector('#hkLocModal'); await pg.keyboard.press('Escape'); await pg.wait_for_timeout(100)
        esc=[await pg.locator('#hkLocModal').count(), await pg.locator('#hkMapFull').count()]
        await pg.click('#hkMapFull [data-me]'); await pg.evaluate('()=>window.__no({code:1,message:"User denied Geolocation"})'); await pg.wait_for_selector('#hkLocModal'); await pg.evaluate('()=>document.querySelector("#hkMapFull [data-x]").click()'); await pg.wait_for_timeout(100)
        gone=[await pg.locator('#hkLocModal').count(), await pg.locator('#hkMapFull').count()]; w2=await pg.evaluate('()=>[window.__w, window.__c]')
        check('refused: "Try again" closes the box and asks the phone again; Escape closes the box and leaves the map; closing the map takes the box with it; no watch is left running', w2a==[1,2,3] and g2==0 and esc==[0,1] and gone==[0,0] and w2[0]==[1,2,3,4] and all(i in w2[1] for i in (1,2,3,4)), [w2a,g2,esc,gone,w2]); await b.close()
        ALONE="const mm=window.matchMedia.bind(window); window.matchMedia=q=>/display-mode:\\s*standalone/.test(q)?{matches:true,media:q,addListener(){},removeListener(){},addEventListener(){},removeEventListener(){}}:mm(q);"
        for tag,ua,want,wd,extra in (('iphone',IPHONE,'Privacy & Security, then Location Services',390,''),('desk',None,'Click the icon at the left of the address bar.',1154,''),('android320',ANDROID,'Tap the three dots at the top right of Chrome.',320,''),('android_on_home_screen',ANDROID,'This app runs on Chrome, so the switch is there. Open the Chrome browser itself, on any page.',360,ALONE)):
            b,pg=await start(p,'refused_'+tag,ua,wd,640 if wd<=360 else 800, GEO+extra); await open_hike(pg,'Nahal Og'); await pg.wait_for_selector('#hkMap .leaflet-container'); await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull')
            await pg.click('#hkMapFull [data-me]'); await pg.evaluate('()=>window.__no({code:1,message:"denied"})'); await pg.wait_for_selector('#hkLocModal'); tx=' '.join((await pg.inner_text('#hkLocModal')).split())
            top=await pg.evaluate('()=>{ const c=document.querySelector("#hkLocModal .modal-card"), h=c.querySelector("h3").getBoundingClientRect(), r=c.getBoundingClientRect(); return c.scrollTop===0&&h.top>=r.top&&h.bottom<=innerHeight; }')
            check('refused, '+tag+': the box opens at its first line, its title in view', top is True, top)
            fits=await pg.evaluate('()=>{ const c=document.querySelector("#hkLocModal .modal-card"), r=c.getBoundingClientRect(), bs=[...c.querySelectorAll("button")].map(b=>b.getBoundingClientRect()); c.scrollTop=c.scrollHeight; const b2=[...c.querySelectorAll("button")].map(b=>b.getBoundingClientRect()); return r.left>=0&&r.right<=innerWidth&&r.top>=0&&r.bottom<=innerHeight&&b2.every(x=>x.bottom<=innerHeight+1&&x.top>=0)&&document.documentElement.scrollWidth<=innerWidth+1; }')
            check('refused, '+tag+': the box gives the steps for that kind of device and fits the screen, its buttons within reach', want in tx and ('Two switches decide this' in tx)==(ua==ANDROID) and ('Tap the three dots at the top right of Chrome.' in tx)==(ua==ANDROID and not extra) and fits, [tx[:400],fits])
            if tag=='android_on_home_screen': await pg.screenshot(path=OUT+'hp_12_allow_location_installed.png')
            await b.close()
        # ================= far from the hike, and a phone that will not give its place =================
        b,pg=await start(p,'far',ANDROID,411,812, geo=(32.8,35.0)); await open_hike(pg,'Nahal Og'); await pg.wait_for_selector('#hkMap .leaflet-container'); await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull')
        await pg.click('#hkMapFull [data-me]'); await pg.wait_for_selector('.toast'); await pg.wait_for_timeout(600)
        fr=await pg.evaluate('()=>{ const m=__full().map, L=window.L, t=document.querySelector(".toast"), r=t.getBoundingClientRect(); let me=null, line=null; m.eachLayer(l=>{ if(l.getTooltip&&l.getTooltip()&&l.getTooltip().getContent()==="You") me=l.getLatLng(); else if(l instanceof L.Polyline&&!line) line=l.getBounds(); }); return [me&&[me.lat,me.lng], me&&m.getBounds().contains(me), m.getBounds().contains(line), t.textContent, document.elementFromPoint(r.left+r.width/2, r.top+r.height/2)===t]; }')
        import re as _re
        km=_re.match(r'You are about (\d+) km from this hike\. The map shows you and the hike\.$', fr[3])
        check('far away: "Where am I" still shows the member: the map widens to hold him and the hike, and says how far he is, in a message seen above the map', fr[0]==[32.8,35.0] and fr[1] is True and fr[2] is True and km and 110<=int(km.group(1))<=125 and fr[4] is True, fr)
        await pg.click('#hkMapFull [data-fit]'); await pg.wait_for_timeout(300)
        check('far away: "Whole route" brings the map back to the hike', await pg.evaluate('()=>__full().map.getZoom()>=13'), await pg.evaluate('()=>__full().map.getZoom()')); await b.close()
        b,pg=await start(p,'no_place',ANDROID,411,812); await open_hike(pg,'Nahal Og'); await pg.wait_for_selector('#hkMap .leaflet-container'); await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull'); await pg.click('#hkMapFull [data-me]'); await pg.wait_for_selector('#hkLocModal')
        check('no place given (a real refusal by the browser): the box that says how to allow it comes up', 'Allow location' in await pg.inner_text('#hkLocModal'), await pg.inner_text('#hkLocModal')); await b.close()
    bad=[n for n,c in res if not c]
    for e in errs: print('ERR',e)
    print(f'\n{len(res)} checks, {len(bad)} failed, {len(errs)} page errors'); sys.exit(1 if bad or errs else 0)
asyncio.run(main())
