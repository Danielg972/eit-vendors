# Batch confirm (D-58): on a supplier's page Eretz Israel Tours opens "Confirm prices…", ticks prices (the unconfirmed ones are
# ticked to start), chooses one way and one kind, and every ticked price gets the same mark with today's date. Colleagues and
# organisations see no button. Preview mode only (sample data, no network).
#   python3 -m http.server 8765 &   then   python3 supabase/tests/confirmed_mark/batch_walk.py [folder for pictures]
import asyncio, os, sys, datetime
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/batch_mark').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]; JEEP='vendor_k3m9p2x'; BUS='vendor_p0lk5sd'
TODAY=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=3))).strftime('%d/%m/%Y')
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
async def page(p,w,h,tag,dark=False):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    return b,pg
async def open_vendor(pg,vid):
    await pg.click(f'#results .row[data-id="{vid}"]'); await pg.wait_for_selector('#pricesBox .pr-mk')
async def board_rows(pg):
    allg=pg.locator('#pricesBox [data-tpg]'); rows=[]
    for i in range(await allg.count()):
        await allg.nth(i).click(); await pg.wait_for_timeout(80)
        rows+=await pg.eval_on_selector_all('#pricesBox .tprow > summary','e=>e.map(x=>x.innerText.replace(/\\s+/g," ").trim())')
    return rows
async def admin(p,w,h,tag,dark=False):
    b,pg=await page(p,w,h,tag,dark)
    await open_vendor(pg,BUS)
    btn=pg.locator('#mkBatch')
    check(tag+': "Confirm prices…" shows beside the Prices heading', await btn.is_visible() and 'Confirm prices' in await btn.inner_text())
    await pg.screenshot(path=OUT+tag+'_page.png')
    await btn.click(); await pg.wait_for_selector('.bk-list')
    boxes=pg.locator('[data-bk]'); n=await boxes.count()
    ticked=[await boxes.nth(i).is_checked() for i in range(n)]
    ids=[await boxes.nth(i).get_attribute('data-bk') for i in range(n)]
    check(tag+': every price of the supplier is listed (4 sample prices)', n==4, n)
    check(tag+': the unconfirmed ones are ticked, the confirmed one is not', ticked==[i!='tb3' for i in ids], list(zip(ids,ticked)))
    check(tag+': the count and the button say 3', '3 of 4 ticked' in await pg.inner_text('#bkCount') and await pg.inner_text('#mkGo')=='Confirm 3 prices')
    check(tag+': the confirmed one shows its mark in the list', 'Confirmed · paid invoice' in await pg.inner_text('.bk-list'))
    await pg.screenshot(path=OUT+tag+'_sheet.png')
    await pg.click('#bkNone')
    check(tag+': None unticks all and the button cannot be pressed', await pg.inner_text('#mkGo')=='Tick a price first' and await pg.locator('#mkGo').is_disabled())
    await pg.click('#bkAll')
    check(tag+': Tick all ticks all four', await pg.inner_text('#mkGo')=='Confirm 4 prices')
    await boxes.nth(ids.index('tb3')).uncheck()
    check(tag+': unticking one makes it 3 again', await pg.inner_text('#mkGo')=='Confirm 3 prices')
    await pg.click('#mkGo'); await pg.wait_for_timeout(100)
    check(tag+': nothing is saved until a way is chosen', 'Choose how you know the prices.' in await pg.inner_text('#mkErr'))
    await pg.click('.mk-grid label:has-text("Official list")'); await pg.click('.mk-kind label:has-text("Tariff")')
    check(tag+': the warning goes once a way is chosen', (await pg.inner_text('#mkErr')).strip()=='')
    await pg.screenshot(path=OUT+tag+'_sheet_chosen.png')
    await pg.click('#mkGo'); await pg.wait_for_selector('#pricesBox .pr-mk')
    rows=await board_rows(pg)
    check(tag+': the three ticked prices now show Confirmed · official list · today · tariff', sum(('Confirmed · official list · '+TODAY+' · tariff') in r for r in rows)==3, rows)
    check(tag+': the unticked one keeps its own mark (paid invoice)', sum('Confirmed · paid invoice' in r for r in rows)==1, rows)
    await pg.locator('#pricesBox').screenshot(path=OUT+tag+'_after.png')
    # opening it again: nothing is ticked now (all confirmed), and re-confirming a ticked one replaces its mark
    await pg.click('#mkBatch'); await pg.wait_for_selector('.bk-list')
    check(tag+': once all are confirmed, nothing starts ticked', '0 of 4 ticked' in await pg.inner_text('#bkCount'), await pg.inner_text('#bkCount'))
    await pg.locator('[data-bk="tb3"]').check(); await pg.click('.mk-grid label:has-text("Conversation")'); await pg.click('#mkGo'); await pg.wait_for_selector('#pricesBox .pr-mk')
    rows=await board_rows(pg)
    check(tag+': re-confirming one replaces its mark with the new way and today', sum(('Confirmed · conversation with the supplier · '+TODAY) in r for r in rows)==1 and sum('paid invoice' in r for r in rows)==0, rows)
    # a supplier that is not transport
    await pg.click('#closeS'); await open_vendor(pg,JEEP)
    await pg.click('#mkBatch'); await pg.wait_for_selector('.bk-list')
    t=await pg.inner_text('.bk-list')
    check(tag+': on a jeep company the list names each price (adult, child, senior, group)', all(x in t for x in ['Adult','Child','Israeli senior','Private jeep']), t)
    check(tag+': no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    await b.close()
async def member(p,who,tag):
    b,pg=await page(p,390,844,tag)
    await pg.select_option('#demoAs', who); await pg.wait_for_timeout(200)
    await pg.click(f'#results .row[data-id="{JEEP}"]'); await pg.wait_for_selector('#pricesBox .prrow, #pricesBox .tprow, #pricesBox .hint'); await pg.wait_for_timeout(200)
    check(tag+': no "Confirm prices…" button', await pg.locator('#mkBatch').count()==0 or not await pg.locator('#mkBatch').is_visible())
    await b.close()
async def main():
    async with async_playwright() as p:
        await admin(p,390,844,'eit_phone'); await admin(p,390,844,'eit_phone_dark',True); await admin(p,1280,800,'eit_desktop')
        await member(p,'guide','guide'); await member(p,'agent','agent'); await member(p,'org','org')
    for e in errs: print('ERROR',e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
