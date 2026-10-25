# D-62 (online links) and D-63 (Hebrew name and contact): preview walk (sample data, no network).
# The sample supplier "Sample Olive Press" has six invented links, a Hebrew name and a Hebrew contact. Checks the supplier
# page (the Online section: plain names, handles, an external-link icon, new tab, rel="noopener", no other company's logo),
# the Hebrew name under the title and on the list card, search in Hebrew, the edit form (Name in Hebrew, Contact person in
# Hebrew, Online links, locked for a colleague like the English name), the split-out suggestion from a bracketed name, the
# links box refusing a non-web link, and the organisation's view. Phone 390 px, phone dark and desktop.
#   python3 -m http.server 8765 &   then   python3 supabase/tests/online_links_hebrew/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/online_links_hebrew').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]; OL='vendor_ol00001'
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
async def page(p,w,h,tag,dark=False):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    return b,pg
async def view_as(pg,k):
    await pg.select_option('#demoAs',k); await pg.wait_for_timeout(150)
async def open_vendor(pg,vid):
    await pg.click('.tab[data-tab="vendors"]'); await pg.wait_for_timeout(100)
    await pg.fill('#q',''); await pg.wait_for_timeout(50)
    await pg.locator(f'#results .row[data-id="{vid}"]').evaluate('e=>e.click()')
    await pg.wait_for_selector('.sheet-foot'); await pg.wait_for_timeout(400)
async def no_overflow(pg,tag):
    w=await pg.evaluate('()=>[document.documentElement.scrollWidth, window.innerWidth]')
    check(tag+': no sideways scroll', w[0]<=w[1], w)
async def sheet_no_overflow(pg,tag):
    w=await pg.evaluate('()=>{const b=document.querySelector(".sheet-body"); return [b.scrollWidth, b.clientWidth]}')
    check(tag+': nothing wider than the sheet', w[0]<=w[1], w)

async def page_checks(pg,tag,who):
    rows=await pg.locator('.online .orow').all()
    names=[await r.locator('.oname').inner_text() for r in rows]
    check(f'{tag}: {who}: Online lists the six links by plain name', names==['Instagram','Facebook','TripAdvisor','Google business page','YouTube','TikTok'], names)
    subs=[(await r.locator('.osub').inner_text()) if await r.locator('.osub').count() else '' for r in rows]
    check(f'{tag}: {who}: handles where easy (@sample_olive_press from instagram.com/sample_olive_press)', subs[0]=='@sample_olive_press' and subs[1]=='sampleolivepress' and subs[2]=='' and subs[4]=='@sampleolivepress' and subs[5]=='@sample_olive_press', subs)
    attrs=await pg.eval_on_selector_all('.online .orow','e=>e.map(a=>[a.getAttribute("target"),a.getAttribute("rel"),a.href.slice(0,8)])')
    check(f'{tag}: {who}: every link opens in a new tab with rel="noopener", https only', all(t=='_blank' and 'noopener' in (r or '') and h=='https://' for t,r,h in attrs), attrs)
    check(f'{tag}: {who}: an external-link icon on each row, no image or logo', await pg.locator('.online .oext svg').count()==6 and await pg.locator('.online img').count()==0)
    he=pg.locator('.he-title')
    check(f'{tag}: {who}: the Hebrew name under the title, right to left', await he.inner_text()=='בית בד לדוגמה' and await he.get_attribute('dir')=='rtl')
    body=await pg.inner_text('.sheet-body')
    check(f'{tag}: {who}: the Hebrew contact beside the contact', 'Sample Host · מארח לדוגמה' in body, body[-800:])
    dd=pg.locator('.dl dd span[dir="rtl"]', has_text='מארח לדוגמה')
    check(f'{tag}: {who}: the Hebrew contact is marked right to left', await dd.count()==1)

async def admin(p,w,h,tag,dark=False):
    b,pg=await page(p,w,h,tag,dark)
    # list card and search
    await pg.fill('#q','בית בד'); await pg.wait_for_timeout(300)
    ids=await pg.eval_on_selector_all('#results .row','e=>e.map(x=>x.dataset.id)')
    check(tag+': searching the Hebrew name finds the supplier', ids==[OL], ids)
    card=pg.locator(f'#results .row[data-id="{OL}"] .he-name')
    check(tag+': the list card shows the Hebrew name beside the English one, right to left', await card.inner_text()=='בית בד לדוגמה' and await card.get_attribute('dir')=='rtl')
    await pg.locator(f'#results .row[data-id="{OL}"]').screenshot(path=OUT+tag+'_0_card.png')
    await pg.fill('#q','מארח'); await pg.wait_for_timeout(300)
    ids=await pg.eval_on_selector_all('#results .row','e=>e.map(x=>x.dataset.id)')
    check(tag+': searching the Hebrew contact finds the supplier', ids==[OL], ids)
    await no_overflow(pg,tag+' list')
    await open_vendor(pg,OL)
    await page_checks(pg,tag,'Eretz Israel Tours')
    await no_overflow(pg,tag+' page'); await sheet_no_overflow(pg,tag+' page')
    await pg.screenshot(path=OUT+tag+'_1_page.png')
    # a supplier with no links has no Online section
    await pg.click('#closeS'); await open_vendor(pg,'vendor_k3m9p2x')
    check(tag+': a supplier with no links has no Online section, no Hebrew line', await pg.locator('.online').count()==0 and await pg.locator('.he-title').count()==0)
    await pg.click('#closeS')
    # the edit form
    await open_vendor(pg,OL); await pg.click('#edit'); await pg.wait_for_selector('#vf'); await pg.wait_for_timeout(300)
    nh=pg.locator('#f_name_he'); ch=pg.locator('#f_contactPerson_he')
    check(tag+': form: "Name in Hebrew" under the name, right to left, filled', await nh.input_value()=='בית בד לדוגמה' and await nh.get_attribute('dir')=='rtl')
    check(tag+': form: "Contact person in Hebrew" beside the contact, right to left', await ch.input_value()=='מארח לדוגמה' and await ch.get_attribute('dir')=='rtl')
    order=await pg.evaluate('()=>{const a=[...document.querySelectorAll("#vf input")].map(e=>e.id); return [a.indexOf("f_name"),a.indexOf("f_name_he"),a.indexOf("f_contactPerson"),a.indexOf("f_contactPerson_he")]}')
    check(tag+': form: each Hebrew box comes right after its English twin', order[1]==order[0]+1 and order[3]==order[2]+1, order)
    check(tag+': form: no lock for Eretz Israel Tours', await pg.locator('label[for="f_name_he"] .lock').count()==0)
    lk=await pg.eval_on_selector_all('#lnkRows .lnk-row input','e=>e.map(x=>x.value)')
    check(tag+': form: one box per link, six of them', len(lk)==6 and lk[0].startswith('https://www.instagram.com/'), lk)
    kinds=await pg.eval_on_selector_all('#lnkRows .lnk-k','e=>e.map(x=>x.textContent)')
    check(tag+': form: each box says what it is', kinds==['Instagram','Facebook','TripAdvisor','Google business page','YouTube','TikTok'], kinds)
    await nh.scroll_into_view_if_needed(); await pg.wait_for_timeout(100)
    await no_overflow(pg,tag+' form'); await sheet_no_overflow(pg,tag+' form')
    await pg.screenshot(path=OUT+tag+'_2_form_names.png')
    await pg.locator('#lnkWrap').scroll_into_view_if_needed(); await pg.wait_for_timeout(100)
    await pg.screenshot(path=OUT+tag+'_3_form_links.png')
    # add a link, paste two at once, remove one, a bad one refused
    await pg.click('#lnkMore'); await pg.wait_for_timeout(50)
    check(tag+': form: "+ Add another link" adds a box', await pg.locator('#lnkRows .lnk-row').count()==7)
    last=pg.locator('#lnkRows .lnk-row input').last
    await last.fill('sample-place.example/visit https://www.linkedin.com/company/sample-place'); await pg.wait_for_timeout(100)
    vals=await pg.eval_on_selector_all('#lnkRows .lnk-row input','e=>e.map(x=>x.value)')
    check(tag+': form: two links pasted into one box become two boxes', len(vals)==8 and vals[6]=='sample-place.example/visit' and vals[7].startswith('https://www.linkedin.com/'), vals)
    kinds=await pg.eval_on_selector_all('#lnkRows .lnk-k','e=>e.map(x=>x.textContent)')
    check(tag+': form: a plain website is named by its address', kinds[6]=='sample-place.example' and kinds[7]=='LinkedIn', kinds)
    await pg.locator('#lnkRows .lnk-row').nth(7).locator('.x').click()
    check(tag+': form: × removes a box', await pg.locator('#lnkRows .lnk-row').count()==7)
    await pg.click('#lnkMore'); await pg.locator('#lnkRows .lnk-row input').last.fill('javascript:alert(1)'); await pg.wait_for_timeout(50)
    check(tag+': form: a non-web link says "Not a link"', (await pg.locator('#lnkRows .lnk-k').last.inner_text())=='Not a link')
    await pg.click('#saveBtn'); await pg.wait_for_timeout(200)
    check(tag+': form: saving with a non-web link is refused', 'Only web links can be saved as online links' in await pg.inner_text('#formErr'), await pg.inner_text('#formErr'))
    await pg.locator('#lnkRows .lnk-row').last.locator('.x').click()
    await pg.click('#saveBtn'); await pg.wait_for_selector('.online'); await pg.wait_for_timeout(300)
    names=await pg.eval_on_selector_all('.online .oname','e=>e.map(x=>x.textContent)')
    check(tag+': saved: the new website shows by its host name, https added', names[-1]=='sample-place.example' and len(names)==7 and await pg.locator('.online .orow').last.get_attribute('href')=='https://sample-place.example/visit', names)
    await pg.click('#closeS')
    # the bracket helper on a new supplier
    await pg.click('.tab[data-tab="vendors"]'); await pg.click('#add'); await pg.wait_for_selector('#f_name')
    await pg.fill('#f_name','Sample Tractor Rides (טרקטורונים לדוגמה)'); await pg.wait_for_timeout(100)
    sug=pg.locator('#heUse')
    check(tag+': new supplier: a bracketed Hebrew name is offered for "Name in Hebrew"', await sug.is_visible() and 'טרקטורונים לדוגמה' in await sug.inner_text())
    check(tag+': new supplier: nothing is copied until tapped', await pg.input_value('#f_name_he')=='')
    await sug.click(); await pg.wait_for_timeout(50)
    check(tag+': new supplier: tapping copies it, the offer goes away', await pg.input_value('#f_name_he')=='טרקטורונים לדוגמה' and await pg.locator('#heUse').count()==0)
    await pg.click('#closeS')
    await b.close()

async def members(p,w,h,tag,dark=False):
    b,pg=await page(p,w,h,tag,dark)
    await view_as(pg,'guide'); await open_vendor(pg,OL)
    await page_checks(pg,tag,'guide')
    await pg.click('#edit'); await pg.wait_for_selector('#vf'); await pg.wait_for_timeout(200)
    check(tag+': guide: the Hebrew name and contact carry the lock, like the English ones', await pg.locator('label[for="f_name_he"] .lock').count()==1 and await pg.locator('label[for="f_contactPerson_he"] .lock').count()==1 and await pg.locator('label[for="f_name"] .lock').count()==1)
    check(tag+': guide: online links carry no lock', await pg.locator('#lnkWrap .lock').count()==0)
    check(tag+': guide: the lock bar names the Hebrew name', 'Name (English and Hebrew)' in await pg.inner_text('.lockbar'))
    await pg.fill('#f_name_he','בית בד אחר'); await pg.click('#saveBtn'); await pg.wait_for_timeout(200)
    check(tag+': guide: changing the Hebrew name asks why', 'Name in Hebrew' in await pg.inner_text('#formErr') and 'Say briefly why' in await pg.inner_text('#formErr'), await pg.inner_text('#formErr'))
    await pg.click('#closeS')
    await view_as(pg,'org'); await open_vendor(pg,OL)
    await page_checks(pg,tag,'organisation')
    body=await pg.inner_text('.sheet-body')
    check(tag+': organisation: no agent price on the page', 'Agent price' not in body and '₪45' not in body, body[:600])
    await no_overflow(pg,tag+' organisation'); await sheet_no_overflow(pg,tag+' organisation')
    await pg.screenshot(path=OUT+tag+'_org_page.png')
    await pg.click('#closeS'); await pg.fill('#q','בית בד'); await pg.wait_for_timeout(300)
    ids=await pg.eval_on_selector_all('#results .row','e=>e.map(x=>x.dataset.id)')
    check(tag+': organisation: searching the Hebrew name finds it', ids==[OL], ids)
    await b.close()

async def supplier_form(p,w,h,tag):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2)
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto('http://localhost:8765/f/index.html?demo=1'); await pg.wait_for_selector('#form')
    check(tag+': supplier form: a links box and "Name in Hebrew" for the contact', await pg.locator('#links').count()==1 and await pg.get_attribute('#contact_he','dir')=='rtl' and await pg.locator('#social').count()==0)
    await pg.fill('#contact','Sample Name'); await pg.fill('#contact_he','שם לדוגמה'); await pg.fill('#phone','050-000-0000')
    await pg.fill('#links','https://www.instagram.com/sample_place\nhttps://www.tripadvisor.com/Sample'); await pg.check('#consent')
    await no_overflow(pg,tag)
    await pg.click('#send'); await pg.wait_for_selector('.ban.ok')
    a=((await pg.evaluate('()=>window.__sent')) or {}).get('args',{}).get('p_answers',{})
    check(tag+': supplier form: sends links and the Hebrew contact', a.get('links')=='https://www.instagram.com/sample_place\nhttps://www.tripadvisor.com/Sample' and a.get('contact_he')=='שם לדוגמה', a)
    await b.close()

async def main():
    async with async_playwright() as p:
        await admin(p,390,844,'phone'); await admin(p,390,844,'phone_dark',True); await admin(p,1280,900,'desktop')
        await members(p,390,844,'members_phone'); await members(p,1280,900,'members_desktop')
        await supplier_form(p,390,844,'f_phone')
    for e in errs: print('PAGE ERROR', e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
