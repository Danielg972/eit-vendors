# Collapsible price rows (D-44): on a supplier that is not Transport, adult and child lines show in full (agent rates included),
# every other line is a single row with its name and price that opens on a tap. Preview mode only (sample data, no network).
#   python3 -m http.server 8765 &   then   python3 supabase/tests/price_rows/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/price_rows').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]; V='vendor_k3m9p2x'
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
async def run(p,w,h,tag,dark=False):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    await pg.click(f'#results .row[data-id="{V}"]'); await pg.wait_for_selector('#pricesBox .prlist')
    vis=await pg.eval_on_selector_all('#pricesBox .prlist > .prrow > summary','e=>e.map(x=>x.innerText.replace(/\\s+/g," ").trim())')
    check(tag+': only adult and child rows show, each with its agent tag and price', len(vis)==2 and all('agent' in x.lower() for x in vis) and '₪360' in vis[0] and '₪250' in vis[1], vis)
    check(tag+': no details or buttons until a row is tapped', not await pg.locator('#pricesBox [data-pedit]').first.is_visible())
    more=pg.locator('#pricesBox .prmore > summary')
    check(tag+': one "Show 2 more prices" line', await more.count()==1 and 'Show 2 more prices' in await more.inner_text())
    await pg.screenshot(path=OUT+tag+'_closed.png',full_page=True); await pg.locator('#pricesBox').screenshot(path=OUT+tag+'_box1.png')
    await more.click(); await pg.wait_for_timeout(100)
    rows=await pg.eval_on_selector_all('#pricesBox .prmore > .prrow > summary','e=>e.map(x=>x.innerText.replace(/\\s+/g," ").trim())')
    check(tag+': it opens the senior and group rows with name and price', len(rows)==2 and 'Israeli senior' in rows[0] and '₪300' in rows[0] and '₪2,100' in rows[1], rows)
    await pg.click('#pricesBox .prmore > .prrow >> nth=0'); await pg.wait_for_timeout(100)
    d=await pg.inner_text('#pricesBox .prmore > .prrow[open] .pr-d')
    check(tag+': tapping a row shows its details and buttons, without repeating name and price', 'Teudat Ezrach Vatik' in d and 'Edit' in d and '₪300' not in d, d)
    check(tag+': no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    await pg.locator('#pricesBox').screenshot(path=OUT+tag+'_box2.png')
    await pg.screenshot(path=OUT+tag+'_open.png',full_page=True); await b.close()
async def main():
    async with async_playwright() as p:
        await run(p,390,844,'phone'); await run(p,390,844,'phone_dark',True); await run(p,1280,800,'desktop')
    for e in errs: print('ERROR',e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
