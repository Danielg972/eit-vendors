# The Back button (D-41): a walk through the page's preview mode (sample data, no database, no network), pressing Back.
# Needs python3 with Playwright and Chromium. From the repository root:
#   python3 -m http.server 8765 &        then        python3 supabase/tests/back_button/back_walk.py
# Each run first opens another address (manifest.json), then the page, so "leaving the app" has somewhere to go.
# It checks, at phone size (390 x 844) and at desktop size (1280 x 800): Back closes a supplier's page, the form, a box on
# top of a page, the full-screen map, a step of the welcome tour; returns from another tab to Suppliers; with nothing open
# says "Press Back again to leave" and stays; a second press leaves; waiting instead keeps the member in the app; a page
# closed with its own × leaves nothing behind; the address never changes; Forward does not undo anything.
# WHAT THIS CANNOT SHOW: Back is pressed here from script (history.back()). Chrome treats its own Back button differently
# from that: it skips history entries a page added without a tap. Only a real phone or a real browser window shows that.
import asyncio, sys
from playwright.async_api import async_playwright
BASE='http://localhost:8765/'; APP=BASE+'index.html'; OUT=BASE+'manifest.json'
res=[]; errs=[]
def check(n,c,d=''):
    res.append((n,bool(c))); print(('PASS ' if c else 'FAIL ')+n+((' :: '+str(d)[:300]) if not c else ''))
async def run(p, w, h, tag, tour=False):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h})
    if not tour: await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page()
    pg.on('pageerror', lambda e: errs.append(tag+' pageerror: '+str(e)))
    pg.on('console', lambda m: errs.append(tag+' console: '+m.text) if m.type=='error' and 'Failed to load resource' not in m.text and 'net::' not in m.text else None)
    await pg.goto(OUT); await pg.goto(APP); await pg.wait_for_selector('#app')
    async def back(): await pg.evaluate('history.back()'); await pg.wait_for_timeout(250)
    async def state(): return await pg.evaluate("""()=>({url:location.href, sheet:!!document.getElementById('sheetWrap'), title:(document.querySelector('.sheet h2')||{}).textContent||'',
        modals:document.querySelectorAll('body > .modal').length, map:!!document.getElementById('hkMapFull'), tour:!!document.getElementById('tourWrap'),
        tab:(document.querySelector('.tab[aria-current="page"]')||{dataset:{}}).dataset.tab||'', toast:document.getElementById('toast').hidden?'':document.getElementById('toast').textContent})""")
    if tour:
        await pg.wait_for_selector('#tourWrap'); await pg.click('[data-t="next"]'); await pg.click('[data-t="next"]')
        n2=await pg.inner_text('.tour-n'); await back(); n1=await pg.inner_text('.tour-n'); s=await state()
        check(tag+': tour: Back goes one step back', n2.startswith('2 of') and n1.startswith('1 of') and s['tour'] and s['url']==APP, (n2,n1,s))
        await back(); s=await state(); first=await pg.locator('.tour-n').count()==0
        check(tag+': tour: Back again reaches its first screen', first and s['tour'] and s['url']==APP, s)
        await back(); s=await state()
        check(tag+': tour: on its first screen Back says how to leave and stays', s['tour'] and s['url']==APP and s['toast']=='Press Back again to leave', s)
        await pg.click('[data-t="next"]'); await pg.click('[data-t="skip"]'); await pg.click('[data-t="next"]'); s=await state()
        check(tag+': tour: it still finishes with its own buttons', not s['tour'], s)
        await b.close(); return
    await pg.wait_for_selector('#results .row')
    # a supplier's page
    await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#edit'); await back(); s=await state()
    check(tag+": Back closes a supplier's page and stays in the app", not s['sheet'] and s['url']==APP and s['tab']=='vendors' and not s['toast'], s)
    # the form: Back does what its Cancel does
    await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#edit'); await pg.click('#edit'); await pg.wait_for_selector('#saveBtn'); await back(); s=await state()
    check(tag+': Back on the form does what Cancel does', not s['sheet'] and s['url']==APP, s)
    # a box on top of a page
    await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#edit')
    await pg.evaluate("""()=>{ const m=document.createElement('div'); m.className='modal'; m.id='tBox'; m.innerHTML='<div class="modal-card"><button data-g="x" type="button" onclick="window.tX=1;this.closest(\\'.modal\\').remove()">Close</button></div>'; document.body.appendChild(m); }""")
    await pg.wait_for_timeout(100); await back(); s=await state(); used=await pg.evaluate('window.tX')
    check(tag+': Back closes the box on top with its own Close, and the page under it stays', s['modals']==0 and s['sheet'] and used==1 and s['url']==APP, (s,used))
    await back(); s=await state(); check(tag+': the next Back closes that page', not s['sheet'] and s['url']==APP and not s['toast'], s)
    # another tab
    await pg.click('.tab[data-tab="quotes"]'); await pg.wait_for_timeout(150); await back(); s=await state()
    check(tag+': Back from another tab returns to Suppliers', s['tab']=='vendors' and s['url']==APP and not s['toast'], s)
    # hikes: tab, a hike, its full-screen map, then Back four times without touching the page in between
    await pg.click('.tab[data-tab="hikes"]'); await pg.wait_for_selector('#hkResults .row'); await pg.click('#hkResults .row:has-text("Nahal Og")'); await pg.wait_for_selector('.sheet .hk-rep')
    hasmap=False
    try: await pg.wait_for_selector('#hkMapCap [data-hmap]', timeout=6000); await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull', timeout=6000); hasmap=True
    except Exception as e: pass
    if hasmap:
        await back(); s=await state(); check(tag+': Back closes the full-screen map, the hike stays', not s['map'] and s['sheet'] and s['url']==APP, s)
    else: check(tag+': the full-screen map opened in preview', False, 'no map')
    await back(); s=await state(); check(tag+": Back closes the hike's page, still on Hikes", not s['sheet'] and s['tab']=='hikes' and s['url']==APP, s)
    await back(); s=await state(); check(tag+': Back returns to Suppliers', s['tab']=='vendors' and not s['toast'] and s['url']==APP, s)
    await back(); s=await state(); check(tag+': with nothing open Back says how to leave, and stays', s['toast']=='Press Back again to leave' and s['url']==APP and s['tab']=='vendors', s)
    # waiting instead of pressing again keeps the member in the app
    await pg.wait_for_timeout(3000); await back(); s=await state()
    check(tag+': after waiting, Back says it again and stays', s['toast']=='Press Back again to leave' and s['url']==APP, s)
    await pg.wait_for_timeout(3000)
    # a page closed with its own ×, then Back: the message, not a silent press
    await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#closeS'); await pg.click('#closeS'); await pg.wait_for_timeout(100)
    await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#closeS'); await pg.click('#closeS'); await pg.wait_for_timeout(100)
    await back(); s=await state(); check(tag+': after pages closed with ×, one Back gives the message', s['toast']=='Press Back again to leave' and s['url']==APP and not s['sheet'], s)
    # Forward does not undo anything
    await pg.wait_for_timeout(3000); await pg.click('.tab[data-tab="quotes"]'); await pg.wait_for_timeout(150); await back(); await pg.evaluate('history.forward()'); await pg.wait_for_timeout(250); s=await state()
    check(tag+': Forward changes nothing', s['tab']=='vendors' and not s['sheet'] and s['url']==APP, s)
    # view as an organisation: the same
    await pg.select_option('#demoAs','org'); await pg.wait_for_selector('#results .row'); await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#closeS'); await back(); s=await state()
    check(tag+": as an organisation: Back closes a supplier's page", not s['sheet'] and s['url']==APP, s)
    over=await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"); check(tag+': no sideways scroll', not over)
    # leaving: the message, then a second press
    await back(); s=await state(); check(tag+': the message once more', s['toast']=='Press Back again to leave' and s['url']==APP, s)
    await pg.wait_for_timeout(400); await pg.evaluate('history.back()')
    try: await pg.wait_for_url(OUT, timeout=4000)
    except Exception: pass
    check(tag+': a second press leaves the app', pg.url==OUT, pg.url)
    await b.close()
async def main():
    async with async_playwright() as p:
        await run(p,390,844,'phone'); await run(p,1280,800,'desktop'); await run(p,390,844,'phone tour',tour=True)
    bad=[n for n,ok in res if not ok]
    for e in errs: print('ERR '+e)
    print(f'{len(res)} checks, {len(bad)} failed, {len(errs)} page errors'); sys.exit(1 if bad or errs else 0)
asyncio.run(main())
