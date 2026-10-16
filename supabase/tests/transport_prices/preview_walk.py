# Transport prices (D-54): walk the preview (sample data, no network) at phone and desktop size, light and dark,
# as Eretz Israel Tours, as a guide and as an organisation. Takes pictures of the supplier page, the price form and the Quotes tab.
#   python3 -m http.server 8765 &   then   python3 supabase/tests/transport_prices/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/transport_prices').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]; V='vendor_v4n0001'
def check(n,c,d=''): c=bool(c); res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
async def open_app(p,w,h,tag,dark=False,who=None):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    if who: await pg.select_option('#demoAs', who); await pg.wait_for_timeout(200)
    return b,pg
async def supplier(p,w,h,tag,dark=False):
    b,pg=await open_app(p,w,h,tag,dark)
    await pg.click(f'#results .row[data-id="{V}"]'); await pg.wait_for_selector('#pricesBox .tp-tiles')
    tiles=await pg.eval_on_selector_all('#pricesBox .tp-tile','e=>e.map(x=>x.innerText.replace(/\\s+/g," "))')
    check(tag+': tabs for airport transfers and full day', len(tiles)==2 and 'Airport transfers' in tiles[0] and 'Full day' in tiles[1], tiles)
    rows=await pg.eval_on_selector_all('#pricesBox .tprow > summary','e=>e.map(x=>x.innerText.replace(/\\s+/g," "))')
    check(tag+': 4 airport rows, with passengers and luggage on the 12-seat one', len(rows)==4 and any('12 passengers' in r and 'luggage' in r and '₪750' in r for r in rows), rows)
    sm=await pg.inner_text('#pricesBox .tp-sum') if await pg.locator('#pricesBox .tp-sum').count() else ''
    check(tag+': lowest, average and highest', 'Lowest' in sm and 'Average of 4' in sm and 'Highest' in sm, sm)
    await pg.locator('#pricesBox').screenshot(path=OUT+tag+'_supplier.png')
    await pg.click('#pricesBox [data-tpv="van16"]'); await pg.wait_for_timeout(100)
    rows=await pg.eval_on_selector_all('#pricesBox .tprow','e=>e.length')
    check(tag+': the 11–16 seat chip leaves the two van prices', rows==2, rows)
    await pg.click('#pricesBox .tprow >> nth=0'); await pg.wait_for_timeout(100)
    d=await pg.inner_text('#pricesBox .tprow[open] .pr-d')
    check(tag+': a row opens with Edit and its source', 'Edit' in d and 'WhatsApp' in d, d)
    await pg.locator('#pricesBox').screenshot(path=OUT+tag+'_supplier_van16.png')
    await pg.click('#pricesBox [data-tpg="day"]'); await pg.wait_for_timeout(100)
    r=await pg.inner_text('#pricesBox .tplist')
    check(tag+': full day shows hours, km and extras', '10 hours and 250 km included' in r and 'extra hour' in r and 'Kvish 6 extra' in r, r)
    check(tag+': no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    # the form
    await pg.click('#addPrice'); await pg.wait_for_selector('#pf.trf')
    await pg.select_option('#tr_what','from'); await pg.select_option('#tr_citySel','Jerusalem'); await pg.fill('#tr_pax','12')
    await pg.click('[data-tg="bags"][data-val="yes"]'); await pg.fill('#pl_price','800'); await pg.click('[data-tg="paid"][data-val="quoted"]')
    show=await pg.inner_text('#trShowWrap')
    check(tag+': form shows the line as it will appear', 'Ben Gurion → Jerusalem' in show and '12 passengers' in show, show)
    hidden=await pg.evaluate("()=>[document.querySelector('#trDayFs').hidden, document.querySelector('#trXferFs').hidden]")
    check(tag+': transfer form hides the day fields and shows waiting time', hidden==[True,False], hidden)
    await pg.locator('.sheet').first.screenshot(path=OUT+tag+'_form.png')
    await pg.click('#ps'); await pg.wait_for_selector('#pricesBox .tp-tiles')
    await pg.click('#pricesBox [data-tpv="*"]') if await pg.locator('#pricesBox [data-tpv="*"]').count() else None
    await pg.wait_for_timeout(100); r=await pg.inner_text('#pricesBox .tplist')
    check(tag+': saved, and back on the page under airport transfers with its details', '₪800' in r and r.count('12 passengers')>=2, r)
    await b.close()
async def quotes(p,w,h,tag,dark=False,who=None):
    b,pg=await open_app(p,w,h,tag,dark,who)
    await pg.click('.tab[data-tab="quotes"]'); await pg.wait_for_selector('#qtBody .tp-tiles')
    tiles=await pg.eval_on_selector_all('#qtBody .tp-tile b','e=>e.map(x=>x.innerText)')
    check(tag+': Quotes tab has the same tabs', 'Airport transfers' in tiles and 'Full day' in tiles, tiles)
    t=await pg.inner_text('#qtBody .tplist')
    check(tag+': prices from several suppliers, each named', 'Eli Dahan' in t and ('Shomron Bus Lines' in t or who), t[:300])
    if who=='org': check(tag+': an organisation sees no agent tag', 'AGENT' not in t.upper().replace('AGENT OR','') , t[:400])
    await pg.screenshot(path=OUT+tag+'_quotes.png',full_page=True)
    if await pg.locator('#qtBody [data-tpg="day"]').count():
        await pg.click('#qtBody [data-tpg="day"]'); await pg.wait_for_timeout(150)
        await pg.screenshot(path=OUT+tag+'_quotes_day.png',full_page=True)
    check(tag+': no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    await b.close()
async def main():
    async with async_playwright() as p:
        await supplier(p,390,844,'phone'); await supplier(p,390,844,'phone_dark',True); await supplier(p,1280,800,'desktop')
        await quotes(p,390,844,'q_phone'); await quotes(p,1280,800,'q_desktop'); await quotes(p,390,844,'q_phone_dark',True)
        await quotes(p,390,844,'q_guide',who='guide'); await quotes(p,390,844,'q_org',who='org')
    for e in errs: print('ERROR',e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
