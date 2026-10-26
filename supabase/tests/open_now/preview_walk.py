# D-66: "Open now" / "Closed now" on places you visit, from their opening hours on Israel's clock.
# Preview mode only (sample data, no network). The sample suppliers get invented hours here.
#   python3 -m http.server 8765 &   then   python3 supabase/tests/open_now/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/open_now').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
SET="""()=>{ const {S,drawList,foodOk}=window.__t; const a=S.vendors.filter(v=>foodOk(v)&&v.category!=='Hotel').slice(0,3);
  a[0].hours='Winter: Sun–Thu 8:00–17:00, Fri & holiday eves 8:00–14:00. Summer: Sun–Thu 8:00–17:00, Fri & holiday eves 8:00–15:00. Closed Shabbat.';
  if(a[1]) a[1].hours='Sun–Thu 12:00–20:00, Fri 9:00–13:00. Closed Shabbat.';
  if(a[2]) a[2].hours='By appointment. Sun–Thu 9:00–17:00.';
  drawList(); return a.map(v=>v.id); }"""
async def run(p,w,h,tag,when,dark=False):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light',timezone_id='Asia/Jerusalem')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    # The app lives inside one function; this test copy hands its state out at the very end, nothing else changes.
    src=open('index.html',encoding='utf-8').read(); i=src.rindex('})();')
    body=src[:i]+'window.__t={S,drawList,foodOk};'+src[i:]
    await pg.route('**/index.html', lambda r: r.fulfill(status=200, content_type='text/html; charset=utf-8', body=body))
    await pg.clock.install(time=when)
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    ids=await pg.evaluate(SET); await pg.wait_for_timeout(200)
    pill=lambda i: pg.locator(f'#results .row[data-id="{i}"] .row-meta .pill.approved, #results .row[data-id="{i}"] .row-meta .pill.off')
    mark=lambda xs:[x for x in xs if x.startswith(('Open now','Closed now'))]   # the row also carries the review pill
    t0=mark(await pill(ids[0]).all_inner_texts()); t1=mark(await pill(ids[1]).all_inner_texts()); t2=mark(await pill(ids[2]).all_inner_texts()) if len(ids)>2 else []
    return pg,b,ids,t0,t1,t2,pill,mark
async def main():
    async with async_playwright() as p:
        # Wednesday 28 Oct 2026, 11:00 in Israel (winter clock)
        pg,b,ids,t0,t1,t2,pill,mark=await run(p,390,844,'phone','2026-10-28T09:00:00Z')
        check('Wed 11:00: winter hours 8–17 read as open', t0==['Open now · until 17:00'], t0)
        check('Wed 11:00: 12:00–20:00 read as closed', t1==['Closed now'], t1)
        check('by appointment: no mark', t2==[], t2)
        hotel=await pg.evaluate("()=>{ const {S,drawList}=window.__t; const h=S.vendors.find(v=>v.category==='Hotel'); if(!h) return null; h.hours='Sun–Thu 8:00–17:00'; drawList(); return h.id; }")
        if hotel: check('a hotel gets no mark', mark(await pill(hotel).all_inner_texts())==[])
        for k,i in enumerate(ids): await pg.locator(f'#results .row[data-id="{i}"]').screenshot(path=OUT+f'phone_row{k}.png')
        await pg.locator(f'#results .row[data-id="{ids[0]}"]').click(); await pg.wait_for_timeout(300)
        card=await pg.locator('.sheet-body .sec-head:has(legend:text("Opening hours")) .pill').all_inner_texts()
        check('supplier page: the mark sits beside "Opening hours"', card==['Open now · until 17:00'], card)
        check('no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
        await pg.locator('.sheet-body .sec-head:has(legend:text("Opening hours"))').locator('xpath=..').screenshot(path=OUT+'phone_hours.png'); await b.close()
        # Friday 30 Oct, 13:30: winter Friday closes 14:00
        pg,b,ids,t0,t1,t2,pill,mark=await run(p,390,844,'fri','2026-10-30T11:30:00Z',True)
        check('Fri 13:30: open until 14:00 (winter)', t0==['Open now · until 14:00'], t0)
        check('Fri 13:30: Fri 9–13 read as closed', t1==['Closed now'], t1)
        await pg.screenshot(path=OUT+'phone_dark_fri.png'); await b.close()
        # Saturday 31 Oct, 20:00: "Closed Shabbat" says nothing about Saturday night
        pg,b,ids,t0,t1,t2,pill,mark=await run(p,390,844,'sat','2026-10-31T18:00:00Z')
        check('Sat 20:00: no mark from "Closed Shabbat"', t0==[] and t1==[], (t0,t1)); await b.close()
        pg,b,ids,t0,t1,t2,pill,mark=await run(p,1280,800,'desktop','2026-10-28T09:00:00Z')
        check('desktop: open mark shows', t0==['Open now · until 17:00'], t0)
        await pg.screenshot(path=OUT+'desktop_list.png'); await b.close()
    for e in errs: print('ERROR',e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
