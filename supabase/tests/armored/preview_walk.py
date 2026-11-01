# Armored (bulletproof) vehicles by size in Transport (D-70): the screens. Preview mode only (sample data, no network).
#   python3 -m http.server 8765 &   then   python3 supabase/tests/armored/preview_walk.py [folder for pictures]
# The logic itself is checked by logic.js.
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/armored').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]; BUS='vendor_g4l1c0a'
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
async def main():
  async with async_playwright() as p:
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':390,'height':844},device_scale_factor=2)
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1');localStorage.setItem('eitv_bk_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    await pg.click('[data-cat="Transport"]'); await pg.wait_for_selector('[data-tveh="arm_bus"]')
    chips=await pg.eval_on_selector_all('[data-tveh]','e=>e.map(x=>x.innerText.trim())')
    check('the size filter offers the four armored sizes', all(x in chips for x in ['Armored bus','Armored midibus','Armored van','Armored car']), chips)
    await pg.click('[data-tveh="arm_bus"]'); await pg.wait_for_timeout(200)
    ids=await pg.eval_on_selector_all('#results .row','e=>e.map(x=>x.dataset.id)')
    check('Armored bus shows only the supplier that has one', ids==[BUS], ids)
    await pg.screenshot(path=OUT+'1_list_armored_bus.png')
    await pg.click('[data-tveh="bus"]'); await pg.wait_for_timeout(200)
    check('the ordinary Bus filter still works', len(await pg.eval_on_selector_all('#results .row','e=>e.map(x=>x.dataset.id)'))>=1)
    await pg.click('[data-tveh="arm_bus"]'); await pg.wait_for_timeout(200)
    await pg.click(f'#results .row[data-id="{BUS}"]'); await pg.wait_for_timeout(300)
    t=await pg.inner_text('body')
    check('the supplier page lists its armored vehicles', 'Armored bus (36–60 seats)' in t and 'Armored van (up to 20 seats)' in t)
    fs=pg.locator('fieldset:has(legend:text-is("Vehicles"))').first; await fs.scroll_into_view_if_needed(); await fs.screenshot(path=OUT+'2_supplier_vehicles.png')
    await pg.click('#addBooking'); await pg.wait_for_selector('#b_svc')
    opts=await pg.eval_on_selector_all('#b_svc option','e=>e.map(x=>x.textContent)')
    check('the booking sheet offers the armored sizes', all(x in opts for x in ['Armored bus (36–60 seats)','Armored midibus (21–35 seats)','Armored van (up to 20 seats)','Armored car (up to 4 passengers)']), opts)
    await pg.fill('#b_pax','45'); await pg.fill('#b_seats','50'); await pg.select_option('#b_svc','arm_bus')
    await pg.locator('#b_pax').scroll_into_view_if_needed(); await pg.screenshot(path=OUT+'3_booking_form.png')
    check('no sideways scroll', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    # the company's page (sample), with the sample job switched to an armored 50-seat bus
    async def swap(route):
      r=await route.fetch(); body=(await r.text()).replace("service:'midibus',seats:'30'","service:'arm_bus',seats:'50'",1)
      await route.fulfill(response=r, body=body)
    await pg.route('**/b/index.html*', swap)
    await pg.goto('http://localhost:8765/b/index.html?demo=1'); await pg.wait_for_timeout(800)
    t=await pg.inner_text('body')
    check("the company's page says it in Hebrew and English", 'אוטובוס 50 מקומות ממוגן ירי' in t and '50-seat armored bus' in t, t[:400])
    el=pg.locator('text=ממוגן ירי').first
    if await el.count(): await el.scroll_into_view_if_needed()
    await pg.screenshot(path=OUT+'4_company_sheet.png')
    check('no page errors', not errs, errs)
    await b.close()
  print(f'{len(res)} checks, {res.count(False)} failed')
asyncio.run(main())
