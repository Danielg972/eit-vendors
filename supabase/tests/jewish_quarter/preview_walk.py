# Jewish Quarter under Attraction / Site (D-74). Preview mode only (sample data, no network).
#   python3 -m http.server 8765 &   then   python3 supabase/tests/jewish_quarter/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/jewish_quarter').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:400]))
async def fresh(p, hash='', w=390, h=844):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2)
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','2');localStorage.setItem('eitv_share_warned','1');localStorage.setItem('eitv_sort','az');}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(str(e)))
    await pg.goto('http://localhost:8765/index.html'+hash); await pg.wait_for_selector('.tabs'); await pg.wait_for_timeout(300)
    return b,pg
async def subs(pg): return await pg.eval_on_selector_all('[data-sub="Attraction / Site"]','e=>e.map(x=>x.innerText.replace("✓ ","").trim())')
async def ids(pg): return await pg.eval_on_selector_all('#results .row','e=>e.map(x=>x.dataset.id)')
async def main():
  async with async_playwright() as p:
    for w,h,tag in ((390,844,'phone'),(1280,900,'desktop')):
        b,pg=await fresh(p,w=w,h=h)
        await pg.click('[data-cat="Attraction / Site"]'); await pg.wait_for_timeout(200)
        s=await subs(pg); check(f'{tag}: Attraction / Site opens a row with Jewish Quarter', 'Jewish Quarter' in s and s[0]=='All sites', s)
        allsites=await ids(pg)
        await pg.screenshot(path=OUT+f'1_{tag}_row.png')
        await pg.click('[data-sub="Attraction / Site"][data-subv="Jewish Quarter"]'); await pg.wait_for_timeout(200)
        got=await ids(pg); check(f'{tag}: Jewish Quarter shows the main page and its site only', sorted(got)==['vendor_jq0main','vendor_jq0site'], got)
        await pg.screenshot(path=OUT+f'2_{tag}_jewish_quarter.png')
        await pg.click('[data-sub="Attraction / Site"][data-subv=""]'); await pg.wait_for_timeout(200)
        check(f'{tag}: All sites brings the full list back', await ids(pg)==allsites)
        await b.close()
    b,pg=await fresh(p)
    await pg.click('[data-cat="Restaurant"]'); await pg.wait_for_timeout(200)
    r=await pg.eval_on_selector_all('[data-sub="Restaurant"]','e=>e.map(x=>x.innerText.replace("✓ ","").trim())')
    check('Restaurant row unchanged (no Jewish Quarter there)', 'Jewish Quarter' not in r, r)
    await pg.click('[data-cat="Restaurant"]'); await pg.click('[data-cat="Attraction / Site"]'); await pg.click('[data-sub="Attraction / Site"][data-subv="Jewish Quarter"]'); await pg.wait_for_timeout(200)
    await pg.click('#listShare'); await pg.wait_for_selector('#shLink'); link=await pg.input_value('#shLink')
    check('Share list carries the Jewish Quarter filter', 'Jewish' in link, link)
    await b.close()
    b,pg=await fresh(p, link[link.index('#'):])
    got=await ids(pg); check('opening that link shows the same two', sorted(got)==['vendor_jq0main','vendor_jq0site'], got)
    await pg.click('[data-id="vendor_jq0main"]'); await pg.wait_for_timeout(400)
    t=await pg.inner_text('body'); check('the main page links to its site', 'Sample Quarter Lookout' in t)
    await pg.screenshot(path=OUT+'3_main_page.png', full_page=False)
    await b.close()
    check('no page errors', not errs, errs)
  print(f'{sum(res)}/{len(res)} passed'); sys.exit(0 if all(res) else 1)
asyncio.run(main())
