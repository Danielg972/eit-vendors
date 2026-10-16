# Food courts, kosher choice, map pins and "Problem?" (D-55): walk the preview (sample data, no network) at phone and
# desktop size, light and dark, as Eretz Israel Tours, as a guide and as an organisation.
# The alert box (showAlerts) cannot be reached from here, since the page keeps its state inside one closed function;
# what it shows is checked in checks.sql (my_alerts).
#   python3 -m http.server 8765 &   then   python3 supabase/tests/food_courts/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/food_courts').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]; PARK='vendor_p4avd01'
def check(n,c,d=''): c=bool(c); res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
async def open_app(p,w,h,tag,dark=False,who=None):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    if who: await pg.select_option('#demoAs', who); await pg.wait_for_timeout(200)
    return b,pg
async def open_food(pg):
    await pg.click(f'#results .row[data-id="{PARK}"]'); await pg.wait_for_selector('#foodWrap')
    await pg.evaluate("()=>{document.getElementById('foodWrap').open=true}"); await pg.wait_for_selector('#fdAdd')
async def walk(p,w,h,tag,dark=False,who=None):
    b,pg=await open_app(p,w,h,tag,dark,who); await open_food(pg)
    kos=await pg.eval_on_selector_all('#fdKos option','e=>e.map(x=>x.textContent)')
    check(tag+': "Kosher, certificate not checked" is offered', 'Kosher, certificate not checked' in kos, kos)
    check(tag+': "Kosher, no certificate" only for Eretz Israel Tours', ('Kosher, no certificate' in kos)==(who in (None,'admin')), kos)
    check(tag+': never not kosher', not any(k.startswith('Not kosher') or k.startswith('Kosher-style') for k in kos), kos)
    # one place, pin from a Waze share link (geohash for a spot in Jerusalem)
    await pg.fill('#fdName','Sample Falafel'); await pg.select_option('#fdKos','Kosher, certificate not checked'); await pg.fill('#fdNote','Sample note')
    await pg.click('#fdPinPaste'); await pg.fill('#ppIn','https://waze.com/ul/hsv9hdx7q2'); await pg.click('#ppS')
    t=await pg.inner_text('#fdPinNow'); check(tag+': a Waze link sets the pin', 'Exact spot set' in t, t)
    await pg.click('#fdAdd'); await pg.wait_for_selector('#foodBox .note')
    href=await pg.get_attribute('#foodBox .note >> nth=0 >> a[data-track="waze"]','href')
    check(tag+': Waze goes to the pin', href and 'll=31.7' in href and 'navigate=yes' in href, href)
    href=await pg.get_attribute('#foodBox .note >> nth=0 >> a[data-track="maps"]','href')
    check(tag+': Google Maps goes to the pin', href and 'query=31.7' in href, href)
    # a short Google link is explained
    await pg.click('#fdPinPaste'); await pg.fill('#ppIn','https://maps.app.goo.gl/abc123'); await pg.click('#ppS')
    e=await pg.inner_text('#ppErr'); check(tag+': a short Google link says to set it on the map', "doesn't hold the spot" in e, e)
    await pg.click('#ppC')
    # the map picker opens (the map pictures do not load offline; the library is a file of the site)
    await pg.click('#fdPinMap'); await pg.wait_for_selector('#pkMap')
    await pg.wait_for_timeout(1500)
    ok=await pg.locator('#pkMap .leaflet-container, #pkMap.leaflet-container').count()
    check(tag+': the map opens', ok>0)
    if ok:
        box=await pg.locator('#pkMap').bounding_box(); await pg.mouse.click(box['x']+box['width']/2, box['y']+box['height']/2); await pg.wait_for_timeout(200)
        check(tag+': a tap drops the pin', await pg.locator('#pkMap .pin-ico').count()==1)
        await pg.screenshot(path=OUT+tag+'_pin_picker.png')
        await pg.click('#pkS'); t=await pg.inner_text('#fdPinNow'); check(tag+': the pin is kept', 'Exact spot set' in t, t)
    else:
        await pg.click('#pkC')
    # a food court with two places
    await pg.click('[data-fmode="court"]'); await pg.wait_for_selector('#fdRows .fc-row')
    await pg.fill('#fdName','Sample Junction Food Court'); await pg.fill('#fdNote','Covered seating')
    await pg.fill('#fdRows .fc-row >> nth=0 >> [data-pn]','Sample Shawarma'); await pg.select_option('#fdRows .fc-row >> nth=0 >> [data-pk]','Rabbanut')
    await pg.fill('#fdRows .fc-row >> nth=1 >> [data-pn]','Sample Pizza'); await pg.select_option('#fdRows .fc-row >> nth=1 >> [data-pk]','Kosher, certificate not checked'); await pg.fill('#fdRows .fc-row >> nth=1 >> [data-pd]','Dairy')
    await pg.locator('#foodBox').screenshot(path=OUT+tag+'_court_form.png')
    await pg.click('#fdAdd'); await pg.wait_for_selector('#foodBox .note.court')
    c=await pg.inner_text('#foodBox .note.court'); check(tag+': the tip shows the food court with its two places', 'food court · 2 places' in c.lower() and 'Sample Pizza' in c and 'Kosher, certificate not checked' in c, c)
    await pg.locator('#foodBox').screenshot(path=OUT+tag+'_food_nearby.png')
    check(tag+': no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    # Problem? on the tip
    await pg.click('#foodBox .note.court >> [data-fflag]'); await pg.wait_for_selector('#flS')
    await pg.screenshot(path=OUT+tag+'_problem.png'); await pg.click('[data-fk="Not kosher"]'); await pg.click('#flS'); await pg.wait_for_timeout(200)
    t=await pg.inner_text('#toast'); check(tag+': the report is sent', 'Sent' in t and await pg.locator('#flS').count()==0, t)
    # the food court's own page
    await pg.click('#foodBox .note.court >> [data-fopen]'); await pg.wait_for_selector('#placesBox .fc-places')
    pl=await pg.eval_on_selector_all('#placesBox .fc-places li .n','e=>e.map(x=>x.textContent)')
    check(tag+': its page lists the places', pl==['Sample Shawarma','Sample Pizza'], pl)
    head=await pg.inner_text('.sheet-body'); check(tag+': the food court is its own page under Restaurant, in the park\'s region', 'restaurant' in head.lower() and 'Negev & Arava' in head, head[:300])
    await pg.fill('#fpName','Sample Burger'); await pg.select_option('#fpKos','Rabbanut Mehadrin'); await pg.click('#fpAdd'); await pg.wait_for_timeout(200)
    pl=await pg.eval_on_selector_all('#placesBox .fc-places li .n','e=>e.map(x=>x.textContent)')
    if 'Sample Burger' not in pl: print('  debug:', await pg.evaluate("()=>[document.querySelectorAll('#fpName').length, document.querySelectorAll('#placesBox').length, document.getElementById('plName').value, document.querySelectorAll('.modal').length]"))
    check(tag+': a place is added on its page', 'Sample Burger' in pl, pl)
    await pg.fill('#fpName','sample burger'); await pg.click('#fpAdd'); await pg.wait_for_timeout(200)
    pl2=await pg.eval_on_selector_all('#placesBox .fc-places li .n','e=>e.length'); check(tag+': the same place twice is refused', pl2==len(pl), pl2)
    await pg.locator('#placesWrap').screenshot(path=OUT+tag+'_court_page.png')
    check(tag+': the food court page has Food nearby too', await pg.locator('#foodWrap').count()==1)
    await pg.close(); await b.close()
async def form(p):
    b,pg=await open_app(p,390,844,'form')
    await pg.click(f'#results .row[data-id="{PARK}"]'); await pg.wait_for_selector('#edit'); await pg.click('#edit'); await pg.wait_for_selector('#mapPinBtn')
    check('form: Set on map sits next to I\'m here', await pg.locator('#hereBtn').count()==1)
    check('form: no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    await pg.locator('#f_maps_link').scroll_into_view_if_needed(); await pg.screenshot(path=OUT+'form_pin.png')
    await pg.close(); await b.close()
async def main():
    async with async_playwright() as p:
        await walk(p,390,844,'phone_admin')
        await walk(p,390,844,'phone_guide_dark',True,'guide')
        await walk(p,1280,900,'desktop_agent',False,'agent')
        await walk(p,390,844,'phone_org',False,'org')
        await form(p)
    for e in errs: check('page error', False, e)
    print(f'{sum(res)} passed, {len(res)-sum(res)} failed')
asyncio.run(main())
