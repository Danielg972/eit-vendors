# D-61, the supplier details form: preview walk (sample data, no network).
# Eretz Israel Tours sends the form from a supplier's page and from Add supplier, reviews the answers (ticks, Same ✓,
# Apply N ticked), applies them, creates a new entry from a form, discards one, and switches the form on for full
# members. A guide and an agent then see the button; an organisation never does. Then the supplier's page f/: only the
# business name is filled in, the required fields, the hours line, the thank-you. Phone, phone dark and desktop.
#   python3 -m http.server 8765 &   then   python3 supabase/tests/supplier_forms/preview_walk.py [folder for pictures]
import asyncio, os, sys, re
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/supplier_forms').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]; SW='vendor_sw00001'
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
async def page(p,w,h,tag,dark=False,path='index.html'):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto('http://localhost:8765/'+path)
    return b,pg
async def view_as(pg,k):
    await pg.select_option('#demoAs',k); await pg.wait_for_timeout(150)
async def open_vendor(pg,vid):
    await pg.click('.tab[data-tab="vendors"]'); await pg.wait_for_timeout(100)
    await pg.fill('#q',''); await pg.wait_for_timeout(50)
    row=pg.locator(f'#results .row[data-id="{vid}"]')
    await row.evaluate('e=>e.click()')   # the floating "+ Add supplier" can sit over a row on a phone
    await pg.wait_for_selector('.sheet-foot')
async def no_overflow(pg,tag):
    w=await pg.evaluate('()=>[document.documentElement.scrollWidth, window.innerWidth]')
    check(tag+': no sideways scroll', w[0]<=w[1], w)

async def admin(p,w,h,tag,dark=False):
    b,pg=await page(p,w,h,tag,dark); await pg.wait_for_selector('.tabs')
    rv=await pg.inner_text('.tab[data-tab="review"]')
    check(tag+': the Review tab counts the 2 answered forms in its badge', re.search(r'\d+',rv) is not None, rv)
    # 1 · send from a supplier's page
    await open_vendor(pg,SW)
    sf=pg.locator('#sendForm')
    check(tag+': "Send form to supplier" beside Edit on the supplier page', await sf.is_visible() and await pg.locator('.sheet-foot #edit').is_visible())
    await pg.screenshot(path=OUT+tag+'_1_page.png')
    await sf.click(); await pg.wait_for_selector('#sfMsg')
    msg=await pg.input_value('#sfMsg'); body=await pg.inner_text('.sheet-body')
    check(tag+': the sheet is "Send details form" for Sample Workshop', await pg.inner_text('.sheet-head h2')=='Send details form' and 'Sample Workshop' in body)
    check(tag+': the WhatsApp message, in English and Hebrew, with the form link', msg.startswith('Hi, this is Eretz Israel Tours. Could you fill in your business details') and 'שלום, נשמח אם תמלאו את פרטי העסק' in msg and 'f/index.html?demo=1' in msg, msg)
    check(tag+': the message carries no link to the app itself', '?k=' not in msg.replace('f/index.html?demo=1','') and 'vendors.eretzisraeltours.com/?' not in msg, msg)
    check(tag+': the warning never to send the app', 'Never send a supplier a link to the app itself.' in body)
    check(tag+': Send on WhatsApp and Copy link', await pg.locator('#sfWa').is_visible() and await pg.locator('#sfCopy').is_visible())
    await no_overflow(pg,tag+' send sheet')
    await pg.screenshot(path=OUT+tag+'_2_send.png')
    await pg.click('#sfBack'); await pg.wait_for_selector('#sendForm')
    # 2 · the review list
    await pg.click('#closeS'); await pg.click('.tab[data-tab="review"]'); await pg.wait_for_selector('#formsPanel')
    head=await pg.inner_text('#formsPanel h3')
    check(tag+': "Supplier forms" with "2 new"', 'Supplier forms' in head and '2 new' in head, head)
    card=pg.locator(f'#formsPanel .fm[data-fm="fm1"]'); t=await card.inner_text()
    check(tag+': the card says who sent it and when it was answered', 'Sample Workshop' in t and 'Sent by Sample Member · answered' in t, t)
    check(tag+': In the app beside From the supplier', 'In the app' in t.replace('IN THE APP','In the app') or 'IN THE APP' in t, t)
    ticks=await card.locator('.fm-tick').evaluate_all('e=>e.map(x=>[x.dataset.fk,x.checked])')
    check(tag+': address, hours, agent price and other details ticked; phone has no tick box', ticks==[['location',True],['hours',True],['price_agent',True],['details',True]], ticks)
    check(tag+': the same phone reads "Same ✓"', 'Same ✓' in t)
    old=await card.locator('.fm-old').all_inner_texts()
    check(tag+': the old address is struck through', 'Old City, Jerusalem' in old, old)
    check(tag+': the agent price shows from the supplier', '₪80' in t and 'from the supplier' in t)
    btn=card.locator('[data-fmapply]')
    check(tag+': "Apply 4 ticked"', await btn.inner_text()=='Apply 4 ticked', await btn.inner_text())
    await card.locator('.fm-tick[data-fk="hours"]').uncheck()
    check(tag+': unticking counts down to "Apply 3 ticked"', await btn.inner_text()=='Apply 3 ticked', await btn.inner_text())
    new=pg.locator('#formsPanel .fm[data-fm="fm2"]'); tn=await new.inner_text()
    check(tag+': a supplier new to the list reads "New: Sample Winery", "Not on the list yet"', 'New: Sample Winery' in tn and 'Not on the list yet' in tn, tn)
    check(tag+': with "Create entry from form"', await new.locator('[data-fmnew]').is_visible())
    await no_overflow(pg,tag+' review')
    await card.screenshot(path=OUT+tag+'_3_review_card.png'); await pg.screenshot(path=OUT+tag+'_3_review.png')
    await btn.click(); await pg.wait_for_timeout(300)
    check(tag+': applied, the card leaves the list', await pg.locator('#formsPanel .fm[data-fm="fm1"]').count()==0)
    await open_vendor(pg,SW); await pg.wait_for_selector('#pricesBox .pr-mk, #pricesBox .prl, #pricesBox'); await pg.wait_for_timeout(300)
    pt=await pg.inner_text('.sheet-body')
    check(tag+': the entry has the new address, the hours left as they were', '12 Sample St, Jerusalem' in pt and 'Sun–Thu 09:00–17:00' not in pt, pt[:400])
    check(tag+': the agent price line came in from the supplier', 'From the supplier: details form' in pt and '80' in pt, pt[-1500:])
    check(tag+': the other details came in as a note', 'Visit length: 1.5 hours' in pt)
    await pg.screenshot(path=OUT+tag+'_4_applied.png', full_page=True)
    await pg.click('#closeS')
    # 3 · a new supplier: create the entry from the form, then apply the rest
    await pg.click('.tab[data-tab="review"]'); await pg.wait_for_selector('#formsPanel [data-fmnew]')
    await pg.click('#formsPanel [data-fmnew]'); await pg.wait_for_selector('#f_name')
    check(tag+': the entry form is filled from the answers', await pg.input_value('#f_name')=='Sample Winery' and await pg.input_value('#f_phone')=='050-000-1111' and await pg.input_value('#f_category')=='Winery',
          [await pg.input_value('#f_name'), await pg.input_value('#f_phone'), await pg.input_value('#f_category')])
    check(tag+': it says where it came from, and no second "send form" box', 'From a supplier\'s details form' in await pg.inner_text('.sheet-body') and await pg.locator('#sfNew').count()==0)
    await pg.screenshot(path=OUT+tag+'_5_create.png')
    await pg.click('#saveBtn'); await pg.wait_for_selector('#formsPanel'); await pg.wait_for_timeout(200)
    c2=pg.locator('#formsPanel .fm[data-fm="fm2"]'); t2=await c2.inner_text()
    check(tag+': back in Review, the form now belongs to the entry', 'New:' not in t2 and 'Sample Winery' in t2, t2)
    ticks2=await c2.locator('.fm-tick').evaluate_all('e=>e.map(x=>[x.dataset.fk,x.checked])')
    check(tag+': what the entry already has reads Same ✓; the agent price is left to apply', ['price_agent',True] in ticks2 and 'Same ✓' in t2 and ['phone',True] not in ticks2, ticks2)
    await c2.screenshot(path=OUT+tag+'_6_after_create.png')
    # 4 · discard needs a second tap
    d=c2.locator('[data-fmdisc]'); await d.click()
    check(tag+': Discard asks for a second tap', await d.inner_text()=='Tap again to discard')
    await d.click(); await pg.wait_for_timeout(200)
    check(tag+': discarded, the list is empty', await pg.locator('#formsPanel .fm').count()==0)
    # 5 · Add supplier: send the form instead of typing
    await pg.click('.tab[data-tab="vendors"]'); await pg.click('#add'); await pg.wait_for_selector('#sfNew')
    await pg.click('#sfNew'); check(tag+': Add supplier: no name, no form', 'Write the business name first.' in await pg.inner_text('#sfNewMsg'))
    await pg.fill('#f_name','Sample Bakery'); await pg.click('#sfNew'); await pg.wait_for_selector('#sfMsg')
    check(tag+': Add supplier: the form goes out under the typed name', 'Sample Bakery' in await pg.inner_text('.sheet-body'))
    await pg.click('#closeS')
    # 6 · the switch in Team
    await pg.click('.tab[data-tab="team"]'); await pg.wait_for_selector('#sfAll')
    check(tag+': Team: "Open supplier forms to all full members", off', 'Open supplier forms to all full members' in await pg.inner_text('#view') and not await pg.is_checked('#sfAll'))
    await b.close()

async def members(p,w,h,tag):
    b,pg=await page(p,w,h,tag); await pg.wait_for_selector('.tabs')
    for k in ('guide','agent','org'):
        await view_as(pg,k); await open_vendor(pg,'vendor_k3m9p2x' if k!='org' else 'vendor_g4l1c0a')
        check(f'{tag}: {k}: no "Send form" while it is for Eretz Israel Tours only', await pg.locator('#sendForm').count()==0)
        await pg.click('#closeS')
    await view_as(pg,'admin'); await pg.click('.tab[data-tab="team"]'); await pg.wait_for_selector('#sfAll'); await pg.check('#sfAll'); await pg.wait_for_timeout(150)
    check(tag+': switched on for all full members', 'Open to all full members.' in await pg.inner_text('#sfAllNote'))
    for k,name in (('guide','Avi Mizrahi'),('agent','Rachel Amar')):
        await view_as(pg,k); await open_vendor(pg,'vendor_k3m9p2x')
        check(f'{tag}: {k}: "Send form to supplier" once it is on', await pg.locator('#sendForm').is_visible())
        await pg.click('#sendForm'); await pg.wait_for_selector('#sfMsg')
        check(f'{tag}: {k}: the message is signed with the member\'s own name', (await pg.input_value('#sfMsg')).startswith(f'Hi, this is {name}.'))
        check(f'{tag}: {k}: no Review tab', await pg.locator('.tab[data-tab="review"]').count()==0)
        await pg.click('#closeS'); await pg.click('#add'); await pg.wait_for_selector('#f_name')
        check(f'{tag}: {k}: Add supplier offers the form', await pg.locator('#sfNew').count()==1)
        await pg.click('#closeS')
    await view_as(pg,'org'); await open_vendor(pg,'vendor_g4l1c0a')
    check(tag+': organisation: never the button, even when on', await pg.locator('#sendForm').count()==0)
    await pg.click('#closeS'); await pg.click('#add'); await pg.wait_for_selector('#f_name')
    check(tag+': organisation: Add supplier does not offer the form', await pg.locator('#sfNew').count()==0)
    await b.close()

async def supplier(p,w,h,tag,dark=False):
    b,pg=await page(p,w,h,tag,dark,'f/index.html?demo=1'); await pg.wait_for_selector('#form')
    t=await pg.inner_text('body')
    check(tag+': brand and title', 'ERETZ ISRAEL TOURS' in t.upper() and 'Supplier details' in t and 'פרטי ספק' in t)
    check(tag+': only the business name is filled in ahead', await pg.input_value('#name')=='Sample Workshop' and all([await pg.input_value('#'+k)=='' for k in ('address','contact','phone','p_trade','hours_notes')]))
    hrefs=await pg.eval_on_selector_all('a','e=>e.map(x=>x.href)')
    check(tag+': no link into the app (only WhatsApp)', all('wa.me/' in x for x in hrefs) and len(hrefs)>=1, hrefs)
    check(tag+': no menu, tabs or sign-in', await pg.locator('.tabs, nav, #signOut').count()==0)
    await no_overflow(pg,tag)
    await pg.screenshot(path=OUT+tag+'_1_form.png')
    await pg.click('#send'); await pg.wait_for_timeout(100)
    check(tag+': contact and phone are asked for', 'Please add a contact name, a phone number' in await pg.inner_text('#err'), await pg.inner_text('#err'))
    await pg.fill('#address','12 Sample St'); await pg.fill('#city','Jerusalem'); await pg.fill('#contact','Sample Name'); await pg.fill('#phone','050-000-0000')
    for i in range(5): await pg.fill(f'#open_{i}','09:00'); await pg.fill(f'#close_{i}','17:00')
    await pg.fill('#open_5','09:00'); await pg.fill('#close_5','13:00'); await pg.check('#closed_6')
    await pg.select_option('#shabbat','closed'); await pg.fill('#p_trade','₪80 per person'); await pg.check('#consent')
    await pg.check('input[name=type][value="Activity"]')
    await pg.screenshot(path=OUT+tag+'_2_filled.png', full_page=True)
    await pg.click('#send'); await pg.wait_for_selector('.ban.ok')
    sent=await pg.evaluate('()=>window.__sent')
    a=(sent or {}).get('args',{}).get('p_answers',{})
    check(tag+': the hours go as one line, days run together', a.get('hours')=='Sun–Thu 09:00–17:00 · Fri 09:00–13:00 · Sat closed', a.get('hours'))
    check(tag+': answers sent with the app\'s own type and the consent', a.get('types')=='Activity' and a.get('consent') is True and a.get('shabbat')=='closed' and a.get('name')=='Sample Workshop', a)
    check(tag+': the thank-you, and the link closes', 'Thank you!' in await pg.inner_text('.ban.ok') and 'The link now closes.' in await pg.inner_text('.ban.ok'))
    await pg.screenshot(path=OUT+tag+'_3_thanks.png')
    await b.close()

async def main():
    async with async_playwright() as p:
        await admin(p,390,844,'phone'); await admin(p,390,844,'phone_dark',True); await admin(p,1280,900,'desktop')
        await members(p,390,844,'members')
        await supplier(p,390,844,'f_phone'); await supplier(p,390,844,'f_phone_dark',True); await supplier(p,1280,900,'f_desktop')
    for e in errs: print('PAGE ERROR', e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
