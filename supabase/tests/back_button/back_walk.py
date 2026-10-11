# The Back button (D-41): a walk through the page's preview mode (sample data, no database, no network), pressing Back.
# Needs python3 with Playwright and Chromium. From the repository root:
#   python3 -m http.server 8765 &        then        python3 supabase/tests/back_button/back_walk.py
# Each run first opens another address (manifest.json), then the page, so "leaving the app" has somewhere to go.
# The rule (the owner, 11 Oct 2026): "back should never leave the app".
# It checks, at phone size (390 x 844) and at desktop size (1280 x 800): Back closes a supplier's page, the form, a box on
# top of a page, the full-screen map, a step of the welcome tour; returns from another tab to Suppliers; with nothing open
# does nothing and stays, however many times it is pressed; a page closed with its own × leaves nothing behind; the address
# never changes; Forward does not undo anything.
# Then the same as an Android phone would have it (an Android user agent, so the page opens a CloseWatcher): a Back pressed
# before anything was tapped is heard and stays, and so is every press after it; three presses in a row close a map, a
# hike and the tab; a keyboard's Esc on a sheet closes only the sheet. There Back is the watcher's own requestClose(),
# reached through ONE line added to the page as it is served to this browser (the file in the repository is not touched).
# WHAT THIS CANNOT SHOW: Back is pressed here from script (history.back(), requestClose()). Chrome treats its own Back
# button differently from history.back(): it skips history entries a page added without a tap. And only a real Android
# phone shows that its Back button reaches the watcher. Only a real phone or a real browser window shows those.
import asyncio, os, sys
from playwright.async_api import async_playwright
BASE='http://localhost:8765/'; APP=BASE+'index.html'; OUT=BASE+'manifest.json'
res=[]; errs=[]
STATE="""()=>({url:location.href, sheet:!!document.getElementById('sheetWrap'), title:(document.querySelector('.sheet h2')||{}).textContent||'',
    modals:document.querySelectorAll('body > .modal').length, map:!!document.getElementById('hkMapFull'), tour:!!document.getElementById('tourWrap'),
    tab:(document.querySelector('.tab[aria-current="page"]')||{dataset:{}}).dataset.tab||'', toast:document.getElementById('toast').hidden?'':document.getElementById('toast').textContent,
    alive:window.bkTest?bkTest.alive():null})"""
def check(n,c,d=''):
    res.append((n,bool(c))); print(('PASS ' if c else 'FAIL ')+n+((' :: '+str(d)[:300]) if not c else ''))
def home(s): return s['url']==APP and s['tab']=='vendors' and not s['sheet'] and not s['map'] and s['modals']==0 and not s['toast']
async def run(p, w, h, tag, tour=False):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h})
    if not tour: await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page()
    pg.on('pageerror', lambda e: errs.append(tag+' pageerror: '+str(e)))
    pg.on('console', lambda m: errs.append(tag+' console: '+m.text) if m.type=='error' and 'Failed to load resource' not in m.text and 'net::' not in m.text else None)
    await pg.goto(OUT); await pg.goto(APP); await pg.wait_for_selector('#app')
    async def back(): await pg.evaluate('history.back()'); await pg.wait_for_timeout(250)
    async def state(): return await pg.evaluate(STATE)
    if tour:
        await pg.wait_for_selector('#tourWrap'); await pg.click('[data-t="next"]'); await pg.click('[data-t="next"]')
        n2=await pg.inner_text('.tour-n'); await back(); n1=await pg.inner_text('.tour-n'); s=await state()
        check(tag+': tour: Back goes one step back', n2.startswith('2 of') and n1.startswith('1 of') and s['tour'] and s['url']==APP, (n2,n1,s))
        await back(); s=await state(); first=await pg.locator('.tour-n').count()==0
        check(tag+': tour: Back again reaches its first screen', first and s['tour'] and s['url']==APP, s)
        for i in range(4): await back()
        s=await state(); first=await pg.locator('.tour-n').count()==0
        check(tag+': tour: on its first screen Back does nothing and stays, four presses', first and s['tour'] and s['url']==APP and not s['toast'], s)
        await pg.click('[data-t="next"]'); await pg.click('[data-t="skip"]'); await pg.click('[data-t="next"]'); s=await state()
        check(tag+': tour: it still finishes with its own buttons', not s['tour'], s)
        await b.close(); return
    await pg.wait_for_selector('#results .row')
    # a supplier's page
    await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#edit'); await back(); s=await state()
    check(tag+": Back closes a supplier's page and stays in the app", home(s), s)
    # the form: Back does what its Cancel does
    await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#edit'); await pg.click('#edit'); await pg.wait_for_selector('#saveBtn'); await back(); s=await state()
    check(tag+': Back on the form does what Cancel does', not s['sheet'] and s['url']==APP, s)
    # a box on top of a page
    await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#edit')
    await pg.evaluate("""()=>{ const m=document.createElement('div'); m.className='modal'; m.id='tBox'; m.innerHTML='<div class="modal-card"><button data-g="x" type="button" onclick="window.tX=1;this.closest(\\'.modal\\').remove()">Close</button></div>'; document.body.appendChild(m); }""")
    await pg.wait_for_timeout(100); await back(); s=await state(); used=await pg.evaluate('window.tX')
    check(tag+': Back closes the box on top with its own Close, and the page under it stays', s['modals']==0 and s['sheet'] and used==1 and s['url']==APP, (s,used))
    await back(); s=await state(); check(tag+': the next Back closes that page', home(s), s)
    # another tab
    await pg.click('.tab[data-tab="quotes"]'); await pg.wait_for_timeout(150); await back(); s=await state()
    check(tag+': Back from another tab returns to Suppliers', home(s), s)
    # hikes: tab, a hike, its full-screen map, then Back without touching the page in between
    await pg.click('.tab[data-tab="hikes"]'); await pg.wait_for_selector('#hkResults .row'); await pg.click('#hkResults .row:has-text("Nahal Og")'); await pg.wait_for_selector('.sheet .hk-rep')
    hasmap=False
    try: await pg.wait_for_selector('#hkMapCap [data-hmap]', timeout=6000); await pg.click('#hkMapCap [data-hmap]'); await pg.wait_for_selector('#hkMapFull', timeout=6000); hasmap=True
    except Exception as e: pass
    if hasmap:
        await back(); s=await state(); check(tag+': Back closes the full-screen map, the hike stays', not s['map'] and s['sheet'] and s['url']==APP, s)
    else: check(tag+': the full-screen map opened in preview', False, 'no map')
    await back(); s=await state(); check(tag+": Back closes the hike's page, still on Hikes", not s['sheet'] and s['tab']=='hikes' and s['url']==APP, s)
    await back(); s=await state(); check(tag+': Back returns to Suppliers', home(s), s)
    await back(); s=await state(); check(tag+': with nothing open Back does nothing, and stays', home(s), s)
    for i in range(10): await back()
    s=await state(); check(tag+': ten more presses in a row: still in the app', home(s), s)
    # a page closed with its own ×, then Back: nothing to close, nothing happens
    for i in range(2): await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#closeS'); await pg.click('#closeS'); await pg.wait_for_timeout(100)
    await back(); s=await state(); check(tag+': after pages closed with ×, Back does nothing and stays', home(s), s)
    # Forward does not undo anything
    await pg.click('.tab[data-tab="quotes"]'); await pg.wait_for_timeout(150); await back(); await pg.evaluate('history.forward()'); await pg.wait_for_timeout(250); s=await state()
    check(tag+': Forward changes nothing', home(s), s)
    # view as an organisation: the same
    await pg.select_option('#demoAs','org'); await pg.wait_for_selector('#results .row'); await pg.locator('#results .row').first.click(); await pg.wait_for_selector('#closeS'); await back(); s=await state()
    check(tag+": as an organisation: Back closes a supplier's page", not s['sheet'] and s['url']==APP, s)
    over=await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"); check(tag+': no sideways scroll', not over)
    for i in range(6): await back()
    s=await state(); check(tag+': six more presses: still in the app, the address unchanged', s['url']==APP and not s['sheet'], s)
    await b.close()
async def droid(p, tag):
    PAGE=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','..','index.html'),encoding='utf-8').read()
    END='\n})();\n</script>'; assert PAGE.count(END)==1
    HOOKED=PAGE.replace(END,'\nwindow.bkTest={alive:()=>!!bkW,back:()=>{ if(bkW){ bkW.requestClose(); return "watcher"; } history.back(); return "history"; }};'+END)
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':390,'height':844}, has_touch=True, is_mobile=True,
        user_agent='Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    async def serve(route): await route.fulfill(body=HOOKED, content_type='text/html; charset=utf-8')
    await ctx.route('**/index.html', serve)
    pg=await ctx.new_page()
    pg.on('pageerror', lambda e: errs.append(tag+' pageerror: '+str(e)))
    await pg.goto(OUT); await pg.goto(APP); await pg.wait_for_selector('#results .row'); await pg.wait_for_timeout(200)
    async def back(): how=await pg.evaluate('bkTest.back()'); await pg.wait_for_timeout(250); return how
    async def state(): return await pg.evaluate(STATE)
    # nothing tapped at all
    s=await state(); check(tag+': the page is listening before anything is tapped', s['alive'], s)
    how=await back(); s=await state()
    check(tag+': Back before any tap is heard, does nothing and stays', how=='watcher' and home(s) and s['alive'], (how,s))
    hows=[await back() for i in range(8)]; s=await state()
    check(tag+': eight more presses with still nothing tapped: every one heard, still in the app', hows==['watcher']*8 and home(s) and s['alive'], (hows,s))
    # a supplier's page
    await pg.locator('#results .row').first.tap(); await pg.wait_for_selector('#edit'); how=await back(); s=await state()
    check(tag+": Back closes a supplier's page", how=='watcher' and home(s) and s['alive'], (how,s))
    # hikes tab, a hike, its map: three presses in a row, nothing touched in between
    await pg.locator('.tab[data-tab="hikes"]').tap(); await pg.wait_for_selector('#hkResults .row'); await pg.locator('#hkResults .row:has-text("Nahal Og")').tap(); await pg.wait_for_selector('.sheet .hk-rep')
    await pg.wait_for_selector('#hkMapCap [data-hmap]', timeout=8000); await pg.locator('#hkMapCap [data-hmap]').tap(); await pg.wait_for_selector('#hkMapFull', timeout=8000)
    h1=await back(); s1=await state(); h2=await back(); s2=await state(); h3=await back(); s3=await state()
    check(tag+': three presses in a row close the map, then the hike, then return to Suppliers',
        (h1,h2,h3)==('watcher','watcher','watcher') and not s1['map'] and s1['sheet'] and not s2['sheet'] and s2['tab']=='hikes' and home(s3), (h1,h2,h3,s1,s2,s3))
    h4=await back(); s4=await state(); check(tag+': the fourth does nothing and stays', h4=='watcher' and home(s4) and s4['alive'], (h4,s4))
    # a keyboard's Esc on a sheet: only the sheet closes
    await pg.locator('.tab[data-tab="hikes"]').tap(); await pg.wait_for_selector('#hkResults .row')
    await pg.locator('#hkResults .row:has-text("Nahal Og")').tap(); await pg.wait_for_selector('.sheet .hk-rep'); await pg.keyboard.press('Escape'); await pg.wait_for_timeout(400); s=await state()
    check(tag+": a keyboard's Esc closes the sheet and nothing more", not s['sheet'] and s['tab']=='hikes' and not s['toast'] and s['alive'], s)
    await b.close()
async def main():
    async with async_playwright() as p:
        await run(p,390,844,'phone'); await run(p,1280,800,'desktop'); await run(p,390,844,'phone tour',tour=True); await droid(p,'android')
    bad=[n for n,ok in res if not ok]
    for e in errs: print('ERR '+e)
    print(f'{len(res)} checks, {len(bad)} failed, {len(errs)} page errors'); sys.exit(1 if bad or errs else 0)
asyncio.run(main())
