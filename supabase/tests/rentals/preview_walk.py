# Eshkol / Midbari rentals (D-42) and wineries under Restaurant and Attraction / Site (D-43): a walk through the new screens
# in the page's preview mode (sample data, no database, no network).
# Needs python3 with Playwright and Chromium. From the repository root:
#   python3 -m http.server 8765 &        then        python3 supabase/tests/rentals/preview_walk.py [folder for pictures]
# It opens index.html at phone size (390 x 844) and desktop size (1280 x 800), light and dark, as Eretz Israel Tours, then
# as a guide and as two organisations ("View as"), and checks what each sees and can do: the category button, the vehicles on
# the list, the rental company's page, a vehicle's page with its calendar and reviews, adding a vehicle, the Back button, the
# Wineries buttons under Restaurant and Attraction / Site, and the two switches in the Team tab.
# Prints the failures, any page error, and the total. Pictures are saved in the folder given (default /tmp/rentals_preview).
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/rentals_preview').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]
RC, RD = 'vendor_rt4x401', 'vendor_rt4x402'   # the sample rental companies in index.html
def check(n,c,d=''):
    res.append((n,bool(c))); print(('PASS ' if c else 'FAIL ')+n+((' :: '+str(d)[:300]) if not c else ''))
async def names(pg): return await pg.eval_on_selector_all('#results .row .row-name','els=>els.map(e=>e.textContent)')
async def chips(pg, label): return await pg.eval_on_selector_all(f'.chips[aria-label="{label}"] .chip','els=>els.map(e=>e.textContent.replace("✓ ","").trim())')
async def tap_cat(pg, c): await pg.click(f'[data-cat="{c}"]'); await pg.wait_for_timeout(80)
async def clear(pg): await pg.click('[data-cat="All"]'); await pg.wait_for_timeout(80)
async def sheet_text(pg): return await pg.inner_text('#sheetWrap .sheet')
async def view_as(pg, k):
    await pg.select_option('#demoAs', k); await pg.wait_for_timeout(150)
async def run(p, w, h, tag, dark=False, full=True):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h}, device_scale_factor=2, color_scheme='dark' if dark else 'light')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page()
    pg.on('pageerror', lambda e: errs.append(tag+' pageerror: '+str(e)))
    pg.on('console', lambda m: errs.append(tag+' console: '+m.text) if m.type=='error' and 'Failed to load resource' not in m.text and 'net::' not in m.text else None)
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    async def shot(n):   # the whole page; with a sheet open, the viewport is stretched to the sheet's full height for the picture
        tall=await pg.evaluate("()=>{const b=document.querySelector('#sheetWrap .sheet-body'); return b?b.scrollHeight-b.clientHeight:0}")
        if tall>0: await pg.set_viewport_size({'width':w,'height':h+tall}); await pg.wait_for_timeout(150)
        await pg.evaluate("()=>{ window.scrollTo(0,0); const t=document.getElementById('toast'); if(t) t.hidden=true; }"); await pg.wait_for_timeout(80)
        await pg.screenshot(path=f'{OUT}{tag}_{n}.png', full_page=not tall)
        if tall>0: await pg.set_viewport_size({'width':w,'height':h}); await pg.wait_for_timeout(100)
    top=await chips(pg, 'Filter by category')
    check(tag+': the top row has an "Eshkol / Midbari rental" button and no Winery button', 'Eshkol / Midbari rental' in top and 'Winery' not in top, top)
    check(tag+': no sideways scroll on the first screen', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    # D-42: the list
    await tap_cat(pg, 'Vehicle Rental'); n=await names(pg)
    check(tag+': the rental button shows the two sample rental companies', sorted(n)==['Sample Desert Wheels','Sample Hills 4x4 Rentals'], n)
    row=await pg.inner_text(f'#results .row[data-id="{RC}"]')
    check(tag+': the list shows each vehicle with licence, car, seats, tomorrow and price per day',
        all(x in row for x in ['Eshkol','Toyota Land Cruiser 2022','7 seats','Free tomorrow','₪850/day','Midbari','Jeep Wrangler 2019','Booked tomorrow','₪600/day']), row)
    row2=await pg.inner_text(f'#results .row[data-id="{RD}"]')
    check(tag+': a vehicle whose calendar nobody keeps says so', 'Calendar not kept' in row2 and '₪950/day' in row2, row2)
    await shot('1_rentals_list')
    # the company's page and a vehicle's page
    await pg.click(f'#results .row[data-id="{RC}"]'); await pg.wait_for_selector('#rentBox .rt-card')
    t=await sheet_text(pg)
    check(tag+': the rental company\'s page lists its vehicles and offers "Add a vehicle"', 'vehicles for rent' in t.lower() and t.count('Free tomorrow')+t.count('Booked tomorrow')==2 and await pg.locator('#rtAdd').count()==1)
    check(tag+': the company\'s page carries no drivers tab, no booking sheets and no food nearby', await pg.locator('[data-vt="drivers"]').count()==0 and await pg.locator('#bookingsBox').count()==0 and await pg.locator('#foodWrap').count()==0)
    check(tag+': a review that names a vehicle says which one', 'About the Toyota Land Cruiser 2022' in await pg.inner_text('#notesBox') if await pg.locator('#notesBox .note').count() else False)
    await pg.click('.rt-card[data-rt="rt-v1"]'); await pg.wait_for_selector('#rtCal .cal-g'); await pg.wait_for_selector('#rtRevs .note')
    t=await sheet_text(pg)
    check(tag+': the vehicle\'s page shows the car, seats, pick-up, cost, km, extra km, VAT, source and date, terms and notes',
        all(x in (t if x[0].isupper() or x[0] in '₪7' else t.lower()) for x in ['Toyota Land Cruiser, 2022, white','7','Sample industrial zone','₪850','Plus VAT','200 km/day','₪1.80/km','their price list (sample), checked 09/10/2026','other terms','notes for the renter']), t[:600])
    check(tag+': and the two reviews that name it', t.count('Sample review')==2)
    check(tag+': and who changed the calendar last', 'Last changed by Eretz Israel Tours' in t)
    await shot('2_vehicle_page')
    days=pg.locator('#rtCal .cal-g button:not([disabled])')
    first=days.nth(10); before=await first.get_attribute('class'); d=await first.get_attribute('data-d')
    await first.click(); await pg.wait_for_timeout(120); after=await pg.locator(f'#rtCal [data-d="{d}"]').get_attribute('class')
    nxt={'unknown':'free','free':'booked','booked':'unknown'}
    check(tag+': tapping a day moves it on: not known, free, booked, not known', after.split()[0]==nxt[before.split()[0]], (before, after))
    for _ in range(2): await pg.locator(f'#rtCal [data-d="{d}"]').click(); await pg.wait_for_timeout(80)
    check(tag+': three taps bring it back', (await pg.locator(f'#rtCal [data-d="{d}"]').get_attribute('class')).split()[0]==before.split()[0])
    check(tag+': a day before today cannot be tapped', await pg.locator('#rtCal .cal-g button[disabled]').count()==await pg.evaluate("()=>new Date().getDate()-1"))
    await pg.click('#rtNext'); m2=await pg.inner_text('#rtCal .cal-h b'); await pg.click('#rtPrev')
    check(tag+': the calendar moves to the next month and back', m2!=await pg.inner_text('#rtCal .cal-h b'))
    # Back closes the vehicle and returns to the company (D-41)
    await pg.go_back(); await pg.wait_for_timeout(250)
    check(tag+': Back from a vehicle returns to its company\'s page', await pg.locator('#rentBox').count()==1 and await pg.locator('#rtCal').count()==0)
    if full:
        # adding a vehicle
        await pg.click('#rtAdd'); await pg.wait_for_selector('#rtF')
        await shot('3_add_vehicle')
        await pg.click('[data-lic="both"]'); await pg.fill('#rt_mk','Sample Pajero'); await pg.fill('#rt_yr','2020'); await pg.fill('#rt_seats','5'); await pg.fill('#rt_cost','700'); await pg.fill('#rt_src','')
        await pg.click('#rtS'); await pg.wait_for_selector('#rtErr .msg')
        check(tag+': a price without its source is refused (E4)', 'where the price is from' in await pg.inner_text('#rtErr'))
        await pg.fill('#rt_src','Sample WhatsApp'); await pg.click('#rtS'); await pg.wait_for_selector('#rtCal')
        t=await sheet_text(pg)
        check(tag+': the new vehicle opens on its own page, its calendar not known', 'Sample Pajero 2020' in t and 'Nobody has marked this calendar yet' in t and 'Eshkol' in t and 'Midbari' in t)
        await pg.click('#rtArch'); await pg.click('#rtArch'); await pg.wait_for_selector('#rentBox')
        check(tag+': archiving it takes it off for colleagues and shows it archived to Eretz Israel Tours', 'Archived' in await pg.inner_text('#rentBox'))
    await pg.click('#closeS'); await clear(pg)
    # D-43: wineries under Attraction / Site and Restaurant
    await tap_cat(pg, 'Attraction / Site'); sub=await chips(pg, 'Attraction / Site: narrow by type'); n=await names(pg)
    check(tag+': Attraction / Site gets a second row with Wineries, and alone it includes the wineries', 'Wineries' in sub and {'Sample Hilltop Winery','Sample Valley Cellars','Sataf'}<=set(n), (sub, n))
    await pg.click('[data-sub="Attraction / Site"][data-subv="Wineries"]'); await pg.wait_for_timeout(80); n=await names(pg)
    check(tag+': Wineries under Attraction / Site shows the wineries only', sorted(n)==['Sample Hilltop Winery','Sample Valley Cellars'], n)
    await shot('4_wineries_under_sites')
    await tap_cat(pg, 'Restaurant'); n=await names(pg); sub=await chips(pg, 'Restaurant: narrow by type')
    check(tag+': Restaurant gets Meat, Dairy, Mehadrin and Wineries', all(x in sub for x in ['Meat','Dairy','Mehadrin','Wineries']), sub)
    check(tag+': with both buttons on, each winery is listed once', n.count('Sample Hilltop Winery')==1 and n.count('Sample Valley Cellars')==1 and {'Sample Grill House','Sample Dairy Café'}<=set(n), n)
    await pg.click('[data-sub="Restaurant"][data-subv="Meat"]'); await pg.wait_for_timeout(80); n=await names(pg)
    check(tag+': Meat under Restaurant narrows the restaurants; the wineries stay through Attraction / Site', 'Sample Grill House' in n and 'Sample Dairy Café' not in n and 'Sample Hilltop Winery' in n, n)
    await shot('5_restaurant_row')
    await clear(pg); await tap_cat(pg, 'Restaurant'); n=await names(pg)
    check(tag+': Restaurant alone includes the wineries', {'Sample Grill House','Sample Hilltop Winery','Sample Valley Cellars'}<=set(n), n)
    await clear(pg)
    await pg.fill('#q','Wine'); await pg.wait_for_timeout(120)
    opts=await pg.eval_on_selector_all('#sugList button','els=>els.map(e=>e.textContent)')
    if any(o.startswith('Winery') for o in opts):
        await pg.click('#sugList button:has-text("Winery")'); await pg.wait_for_timeout(120); n=await names(pg)
        check(tag+': choosing the category Winery in the search opens the wineries under a category', sorted(n)==['Sample Hilltop Winery','Sample Valley Cellars'], n)
    await pg.fill('#q',''); await clear(pg)
    if full:
        await pg.click('.tab[data-tab="team"]'); await pg.wait_for_selector('#rtAll')
        t=await pg.inner_text('#view')
        check(tag+': the Team tab has the two switches', 'Open Eshkol / Midbari rentals to all colleagues' in t and 'Put wineries under Restaurant and Attraction / Site for all colleagues' in t)
        await pg.locator('#rtAll').scroll_into_view_if_needed(); await shot('6_team_switches')
        await pg.click('.tab[data-tab="vendors"]'); await pg.wait_for_selector('#results')
        # a guide
        await view_as(pg, 'guide'); await tap_cat(pg, 'Vehicle Rental')
        row=await pg.inner_text(f'#results .row[data-id="{RC}"]')
        check(tag+' as a guide: the agent day price shows', '₪600/day' in row and '₪850/day' in row, row)
        await pg.click(f'#results .row[data-id="{RC}"]'); await pg.wait_for_selector('.rt-card'); await pg.click('.rt-card[data-rt="rt-v1"]'); await pg.wait_for_selector('#rtCal .cal-g')
        check(tag+' as a guide: a vehicle Eretz Israel Tours added has no Edit or Archive', await pg.locator('#rtEdit').count()==0 and await pg.locator('#rtArch').count()==0)
        await pg.click('#rtCal .cal-g button:not([disabled]) >> nth=12'); await pg.wait_for_timeout(120)
        check(tag+' as a guide: he marks a day, and the page names him', 'Last changed by Avi Mizrahi' in await pg.inner_text('#rtLast'))
        await pg.click('#rtRevOpen'); await pg.fill('#rtRevText','Sample review by the walk.'); await pg.click('#rtStars [data-n="4"]'); await pg.click('#rtRevAdd'); await pg.wait_for_timeout(300)
        check(tag+' as a guide: he writes a review naming the vehicle, and it shows on the vehicle', 'Sample review by the walk.' in await pg.inner_text('#rtRevs'))
        await pg.click('#closeS')
        # an organisation that sees transport, sites and food
        await view_as(pg, 'org'); top=await chips(pg, 'Filter by category')
        check(tag+' as an organisation: the rental button is there (with Transportation)', 'Eshkol / Midbari rental' in top, top)
        await tap_cat(pg, 'Vehicle Rental'); row=await pg.inner_text(f'#results .row[data-id="{RC}"]')
        check(tag+' as an organisation: no agent day price, "Ask for rate" instead', '₪600' not in row and 'Ask for rate' in row and '₪850/day' in row, row)
        await pg.click(f'#results .row[data-id="{RC}"]'); await pg.wait_for_selector('.rt-card'); await pg.click('.rt-card[data-rt="rt-v2"]'); await pg.wait_for_selector('#rtCal .cal-g')
        t=await sheet_text(pg)
        check(tag+' as an organisation: the agent vehicle\'s page holds no price, no source and no extra-km price', '600' not in t and '₪2' not in t and 'Ask for rate' in t, t[:500])
        await shot('7_org_agent_vehicle')
        await pg.click('#closeS'); await clear(pg)
        await tap_cat(pg, 'Attraction / Site'); n=await names(pg)
        check(tag+' as an organisation with sites: the wineries are under Attraction / Site', 'Sample Hilltop Winery' in n, n)
        await clear(pg)
        # an organisation without sites or restaurants
        await view_as(pg, 'org2'); top=await chips(pg, 'Filter by category')
        check(tag+' as an organisation with transport and hotels only: rentals yes, wineries no', 'Eshkol / Midbari rental' in top and 'Restaurant' not in top and 'Attraction / Site' not in top, top)
        await pg.fill('#q','Winery'); await pg.wait_for_timeout(120)
        check(tag+' as that organisation: no winery anywhere on the list', not [x for x in await names(pg) if 'Winery' in x or 'Cellars' in x])
        await pg.fill('#q','')
        check(tag+': no sideways scroll at the end', not await pg.evaluate("()=>document.documentElement.scrollWidth>innerWidth+1"))
    await b.close()
async def main():
    async with async_playwright() as p:
        await run(p, 390, 844, 'phone')
        await run(p, 1280, 800, 'desktop')
        await run(p, 390, 844, 'phone_dark', dark=True, full=False)
        await run(p, 1280, 800, 'desktop_dark', dark=True, full=False)
asyncio.run(main())
for e in errs: print('ERROR', e)
print(f"\n{len(res)} checks, {sum(1 for _,ok in res if not ok)} failed, {len(errs)} page errors")
