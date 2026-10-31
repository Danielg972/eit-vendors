# D-68: job board — a line for each day of a multi-day job, "Jerusalem Old City" as a region, the WhatsApp message
# in English first, then Hebrew. Preview mode only (sample data, no network).
#   python3 -m http.server 8765 &   then   python3 supabase/tests/job_days/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/job_days').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))

async def walk(p,w,h,tag,dark=False):
    b=await p.chromium.launch(); ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light',timezone_id='Asia/Jerusalem')
    await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
    await pg.click('.tab[data-tab="jobs"]'); await pg.wait_for_selector('.jobcard')
    # 1. the sample two-day job shows its days
    await pg.locator('.jobcard:has-text("Galilee and Golan")').click(); await pg.wait_for_selector('.sheet-body')
    body=await pg.locator('.sheet-body').inner_text()
    check(tag+': two-day job shows "Day by day"', 'day by day' in body.lower(), body[:200])
    check(tag+': day 1 and day 2 lines', 'Day 1 ·' in body and 'Day 2 ·' in body and 'Gamla' in body, body)
    await pg.locator('.sheet').screenshot(path=OUT+tag+'_job_days.png')
    await pg.click('#closeS')
    # 2. post a three-day job in the Old City
    await pg.click('#addJ'); await pg.wait_for_selector('#jfTitle')
    opts=await pg.locator('#jfRegion option').all_inner_texts()
    check(tag+': region list has Jerusalem Old City after Jerusalem', 'Jerusalem Old City' in opts and opts.index('Jerusalem Old City')==opts.index('Jerusalem')+1, opts)
    check(tag+': no day boxes before dates', await pg.locator('#jfDaysF').is_hidden())
    await pg.fill('#jfTitle','Sample: Old City and Jerusalem, 3 days')
    d0=await pg.evaluate("()=>{ const x=new Date(); x.setDate(x.getDate()+12); return String(x.getDate()).padStart(2,'0')+'/'+String(x.getMonth()+1).padStart(2,'0')+'/'+x.getFullYear(); }")
    d2=await pg.evaluate("()=>{ const x=new Date(); x.setDate(x.getDate()+14); return String(x.getDate()).padStart(2,'0')+'/'+String(x.getMonth()+1).padStart(2,'0')+'/'+x.getFullYear(); }")
    await pg.fill('#jfFrom_il',d0); await pg.locator('#jfFrom_il').blur()
    await pg.fill('#jfTo_il',d2); await pg.locator('#jfTo_il').blur(); await pg.wait_for_timeout(150)
    n=await pg.locator('#jfDays [data-day]').count()
    check(tag+': three day boxes appear', n==3, n)
    check(tag+': hours label changes', (await pg.inner_text('#jfHoursL'))=='Hours, if the same every day')
    await pg.fill('#jfD0','Sample: Jewish Quarter, Kotel tunnels'); await pg.fill('#jfDH0','08:00 to 15:00')
    await pg.fill('#jfD2','Sample: Yad Vashem and the Machane Yehuda shuk')
    # typed text survives a change of the last day
    d3=await pg.evaluate("()=>{ const x=new Date(); x.setDate(x.getDate()+15); return String(x.getDate()).padStart(2,'0')+'/'+String(x.getMonth()+1).padStart(2,'0')+'/'+x.getFullYear(); }")
    await pg.fill('#jfTo_il',d3); await pg.locator('#jfTo_il').blur(); await pg.wait_for_timeout(150)
    check(tag+': four boxes after moving the last day, text kept', await pg.locator('#jfDays [data-day]').count()==4 and (await pg.input_value('#jfD0'))=='Sample: Jewish Quarter, Kotel tunnels')
    await pg.fill('#jfTo_il',d2); await pg.locator('#jfTo_il').blur(); await pg.wait_for_timeout(150)
    await pg.select_option('#jfRegion','Jerusalem Old City')
    await pg.fill('#jfPrice','1500')
    await pg.locator('#jfDaysF').scroll_into_view_if_needed()
    await pg.locator('.sheet').screenshot(path=OUT+tag+'_form_days.png')
    check(tag+': no sideways scroll on the form', not await pg.evaluate("()=>{ const b=document.querySelector('.sheet-body'); return b.scrollWidth>b.clientWidth+1; }"))
    await pg.click('#jfNext'); await pg.wait_for_selector('#jsPost:not([disabled])')
    await pg.click('#jsPost'); await pg.wait_for_selector('#jmTxt')
    msg=await pg.input_value('#jmTxt')
    check(tag+': message starts in English', msg.startswith('New job on The Inner Circle'), msg[:80])
    check(tag+': Hebrew comes after English', msg.find('עבודה חדשה')>msg.find('New job'), msg)
    check(tag+': message has the day lines', 'Day 1 ·' in msg and 'Kotel tunnels, 08:00 to 15:00' in msg and 'Day 3 ·' in msg and 'Day 2 ·' not in msg, msg)
    check(tag+': message has the Old City', 'Jerusalem Old City' in msg, msg)
    await pg.locator('.sheet').screenshot(path=OUT+tag+'_message.png')
    print('--- message ---\n'+msg+'\n---')
    await pg.click('#jmDone')
    # 3. the posted job shows its days to its poster, and again after "Change it"
    await pg.locator('.jobcard:has-text("Old City and Jerusalem, 3 days")').first.click(); await pg.wait_for_selector('.sheet-body')
    body=await pg.locator('.sheet-body').inner_text()
    check(tag+': posted job shows its days', 'day by day' in body.lower() and 'Yad Vashem' in body, body[:300])
    await pg.click('#jEd'); await pg.wait_for_selector('#jfD0')
    check(tag+': "Change it" brings the days back', (await pg.input_value('#jfD0'))=='Sample: Jewish Quarter, Kotel tunnels' and (await pg.input_value('#jfD2')).startswith('Sample: Yad Vashem'))
    await b.close()

async def main():
    async with async_playwright() as p:
        await walk(p,390,844,'phone')
        await walk(p,390,844,'phone_dark',True)
        await walk(p,1280,800,'desktop')
    for e in errs: print('ERROR',e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
