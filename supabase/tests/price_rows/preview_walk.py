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
    await pg.click(f'#results .row[data-id="{V}"]'); await pg.wait_for_selector('#pricesBox .pl')
    full=await pg.eval_on_selector_all('#pricesBox > .prices > .pl .who3','e=>e.map(x=>x.textContent)')
    rows=await pg.eval_on_selector_all('#pricesBox details.prone > summary','e=>e.map(x=>x.innerText.replace(/\\s+/g," ").trim())')
    check(tag+': adult and child lines show in full', len(full)==2 and all('jeep' in x for x in full), full)
    check(tag+': the two agent rates for adult and child are visible', await pg.locator('#pricesBox > .prices .tag.agent').count()==2)
    check(tag+': senior and group are closed rows with name and price', len(rows)==2 and any('Israeli senior' in r and '₪300' in r for r in rows) and any('₪2,100' in r for r in rows), rows)
    check(tag+': closed rows hide their details', await pg.locator('#pricesBox details.prone[open]').count()==0 and not await pg.locator('#pricesBox details.prone .pl').first.is_visible())
    await pg.screenshot(path=OUT+tag+'_closed.png',full_page=True)
    await pg.click('#pricesBox details.prone >> nth=0'); await pg.wait_for_timeout(100)
    check(tag+': a tap opens the full card with its buttons', await pg.locator('#pricesBox details.prone[open] [data-pedit]').count()==1)
    check(tag+': no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    await pg.screenshot(path=OUT+tag+'_open.png',full_page=True); await b.close()
async def main():
    async with async_playwright() as p:
        await run(p,390,844,'phone'); await run(p,390,844,'phone_dark',True); await run(p,1280,800,'desktop')
    for e in errs: print('ERROR',e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
