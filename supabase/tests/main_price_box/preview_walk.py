# D-64: the old single "Main price" (the R5 agent/listed price) is taken off a supplier's page once that supplier has
# price lines; max people and payment terms stay, under "Booking terms". A supplier with no price lines keeps it.
# Preview mode only (sample data, no network).
#   python3 -m http.server 8765 &   then   python3 supabase/tests/main_price_box/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/main_price_box').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
async def page_of(pg, vid, name):
    row=pg.locator(f'#results .row[data-id="{vid}"]')
    if not await row.count(): await pg.fill('#q', name); await pg.keyboard.press('Enter'); await pg.wait_for_timeout(300)
    await row.first.click(); await pg.wait_for_selector('#pricesBox > *'); await pg.wait_for_timeout(150)
    legends=await pg.eval_on_selector_all('.sheet-body fieldset > legend','e=>e.map(x=>x.textContent.trim())')
    terms=await pg.eval_on_selector_all('.sheet-body fieldset .dl dt','e=>e.map(x=>x.innerText.trim())')
    return legends, terms
async def run(p,w,h,tag,dark=False):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    lg,dt=await page_of(pg,'vendor_k3m9p2x','Golan Heights Jeep')
    check(tag+': supplier with price lines has no "Main price" box', not any(l.startswith('Main price') for l in lg), lg)
    check(tag+': no agent/listed/basis rows left from it', not any(x in dt for x in ('Agent price','Listed price','Basis')), dt)
    check(tag+': max people / payment terms kept under "Booking terms"', 'Booking terms' in lg and ('Payment terms' in dt or 'Max people' in dt), (lg,dt))
    check(tag+': price lines still show', await pg.locator('#pricesBox .prrow').count()>0)
    check(tag+': nothing says R5', 'R5' not in await pg.inner_text('.sheet-body'))
    await pg.screenshot(path=OUT+tag+'_with_lines.png',full_page=True)
    await pg.keyboard.press('Escape'); await pg.wait_for_timeout(200)
    if await pg.locator('#sheetWrap').count(): await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    lg,dt=await page_of(pg,'vendor_wn00001','Sample Hilltop Winery')
    check(tag+': supplier without price lines keeps "Main price"', 'Main price' in lg and 'Listed price' in dt, (lg,dt))
    check(tag+': no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    await pg.screenshot(path=OUT+tag+'_no_lines.png',full_page=True); await b.close()
async def main():
    async with async_playwright() as p:
        await run(p,390,844,'phone'); await run(p,390,844,'phone_dark',True); await run(p,1280,800,'desktop')
    for e in errs: print('ERROR',e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
