# D-69: job alerts (phone and email), the jobs WhatsApp group, colleagues' jobs for the group. Preview mode only (sample
# data, no network): the banner once, the iPhone steps, the switches in My days, the unsubscribe page without sign-in,
# the group card for a guide and not for an organisation, the "For the jobs group" list, the "Send to Eretz Israel Tours"
# button, the preview list of who a job would alert, #contact, the service worker, no sideways scroll, no page errors.
#   python3 -m http.server 8765 &   then   python3 supabase/tests/job_alerts/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/job_alerts').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
URL='http://localhost:8765/index.html'
IPHONE='Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1'
res=[]; errs=[]
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
NOSCROLL="()=>document.documentElement.scrollWidth>document.documentElement.clientWidth+1||[...document.querySelectorAll('.sheet-body')].some(b=>b.scrollWidth>b.clientWidth+1)"

async def ctx_for(b,w,h,dark=False,ua=None,tour_seen=True):
    o=dict(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light',timezone_id='Asia/Jerusalem')
    if ua: o['user_agent']=ua
    ctx=await b.new_context(**o)
    if tour_seen: await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
    return ctx
async def page(ctx,tag,url=URL):
    pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
    await pg.goto(url); return pg
async def shot(pg,path,loc=None):
    await pg.evaluate("()=>{ const t=document.getElementById('toast'); if(t) t.hidden=true; }"); await pg.wait_for_timeout(350)
    await (loc or pg).screenshot(path=path)
async def view_as(pg,k):
    await pg.select_option('#demoAs',k); await pg.wait_for_timeout(150)

async def walk(p,w,h,tag,dark=False):
    b=await p.chromium.launch(); ctx=await ctx_for(b,w,h,dark); pg=await page(ctx,tag); await pg.wait_for_selector('.tabs')
    # 1. the banner, once; "Not now" hides it, and it stays hidden
    await pg.click('.tab[data-tab="jobs"]'); await pg.wait_for_selector('.jobcard')
    check(tag+': banner "Get job alerts on this phone"', await pg.locator('#alBan').count()==1 and 'Get job alerts on this phone' in await pg.locator('#alBan').inner_text())
    check(tag+': group card for Eretz Israel Tours', await pg.locator('#alGroup').count()==1)
    await shot(pg,OUT+tag+'_banner.png')
    await pg.click('#alNot'); await pg.wait_for_timeout(100)
    check(tag+': "Not now" hides the banner', await pg.locator('#alBan').count()==0)
    await pg.reload(); await pg.wait_for_selector('.tabs'); await pg.click('.tab[data-tab="jobs"]'); await pg.wait_for_selector('.jobcard')
    check(tag+': banner stays hidden after a reload', await pg.locator('#alBan').count()==0)
    check(tag+': no sideways scroll on Jobs', not await pg.evaluate(NOSCROLL))
    # 2. My days: the switches and the line
    await pg.click('[data-jv="days"]'); await pg.wait_for_selector('#alSec')
    sec=await pg.locator('#alSec').inner_text()
    check(tag+': My days has "Job alerts"', 'job alerts' in sec.lower() and 'Email me jobs that fit me' in sec and 'Phone alerts on this phone' in sec, sec)
    check(tag+': the line about Shabbat, Yom Tov and night', 'Alerts go only for jobs that fit what you take, and not for days you marked busy. Nothing is sent over Shabbat and Yom Tov, or from 23:00 to 07:00.' in sec, sec)
    check(tag+': email switch on by default', await pg.is_checked('#alEmail'))
    await pg.click('#alEmail'); await pg.wait_for_timeout(100)
    check(tag+': email switch turns off', not await pg.is_checked('#alEmail'))
    await pg.click('#alEmail'); await pg.wait_for_timeout(100)
    await pg.click('#alPhone'); await pg.wait_for_timeout(150)
    check(tag+': phone switch turns on (preview)', await pg.is_checked('#alPhone') and 'On for this phone' in await pg.inner_text('#alPhoneH'))
    await pg.locator('#alSec').scroll_into_view_if_needed(); await shot(pg,OUT+tag+'_my_days_alerts.png')
    check(tag+': no sideways scroll on My days', not await pg.evaluate(NOSCROLL))
    # 3. Eretz Israel Tours: the "For the jobs group" list
    await pg.click('[data-jv="mine"]'); await pg.wait_for_selector('#grpH')
    check(tag+': "For the jobs group" has a count badge', (await pg.locator('#grpH .pill').inner_text()).strip()=='1')
    check(tag+': one colleague job waiting, with both buttons', await pg.locator('[data-gshare]').count()==1 and await pg.locator('[data-gskip]').count()==1)
    await pg.locator('#grpH').scroll_into_view_if_needed(); await shot(pg,OUT+tag+'_group_list.png')
    if tag!='desktop':
        await pg.click('[data-gshare]'); await pg.wait_for_selector('#gmTxt')
        msg=await pg.input_value('#gmTxt')
        check(tag+': group message English first, then Hebrew', msg.startswith('New job on The Inner Circle') and msg.find('עבודה חדשה')>msg.find('New job'), msg[:120])
        check(tag+': group message has the link and no poster name', '#job=jd1' in msg and 'Tamar' not in msg and 'Levy' not in msg, msg)
        await shot(pg,OUT+tag+'_group_share.png',pg.locator('.sheet'))
        await ctx.grant_permissions(['clipboard-read','clipboard-write'])
        await pg.click('#gmCopy'); await pg.wait_for_timeout(300); await pg.click('#closeS'); await pg.wait_for_timeout(100)
        check(tag+': after sharing the list is empty', await pg.locator('[data-gshare]').count()==0)
    else:
        await pg.click('[data-gskip]'); await pg.wait_for_timeout(300)
        check(tag+': "Not for the group" takes it off the list', await pg.locator('[data-gskip]').count()==0)
    # 4. the preview list of who a posted job alerts (Eretz Israel Tours only)
    await pg.click('[data-jv="open"]'); await pg.wait_for_selector('.jobcard')
    await view_as(pg,'admin')
    await pg.click('.tab[data-tab="jobs"]'); await pg.click('[data-jv="mine"]'); await pg.wait_for_timeout(150)
    await pg.click('#addJ'); await pg.wait_for_selector('#jfTitle')
    await pg.fill('#jfTitle','Sample: Old City, full day')
    d0=await pg.evaluate("()=>{ const x=new Date(); x.setDate(x.getDate()+21); while(x.getDay()>3) x.setDate(x.getDate()+1); return String(x.getDate()).padStart(2,'0')+'/'+String(x.getMonth()+1).padStart(2,'0')+'/'+x.getFullYear(); }")
    await pg.fill('#jfFrom_il',d0); await pg.locator('#jfFrom_il').blur(); await pg.fill('#jfPrice','1400')
    await pg.click('#jfNext'); await pg.wait_for_selector('#jsPost:not([disabled])'); await pg.click('#jsPost'); await pg.wait_for_selector('#jmTxt')
    prev=await pg.locator('.al-prev').inner_text() if await pg.locator('.al-prev').count() else ''
    check(tag+': preview list of who the job would alert', 'who this job would alert' in prev, prev)
    await pg.locator('.al-prev summary').click(); await pg.wait_for_timeout(100); body=await pg.locator('.al-prev').inner_text()
    check(tag+': licensed guides alerted, "takes no jobs" and non-guides not', 'Tamar Levy' in body and 'takes no jobs' in body and 'not a licensed guide' in body, body)
    check(tag+': Eretz Israel Tours sees no "Send to Eretz Israel Tours" button', await pg.locator('#jmEit').count()==0)
    await pg.click('#jmDone')
    await b.close()

async def guide_and_org(p):
    tag='guide'; b=await p.chromium.launch(); ctx=await ctx_for(b,390,844); pg=await page(ctx,tag); await pg.wait_for_selector('.tabs')
    await view_as(pg,'guide'); await pg.click('.tab[data-tab="jobs"]'); await pg.wait_for_selector('.jobcard'); await pg.wait_for_timeout(150)
    card=await pg.locator('#alGroup').inner_text() if await pg.locator('#alGroup').count() else ''
    check('guide: group card shown', 'Join the Inner Circle – Jobs WhatsApp group' in card and 'only admins post' in card and 'Join (opens WhatsApp)' in card, card)
    check('guide: card links to the sample group', await pg.get_attribute('#alJoin','href')=='https://chat.whatsapp.com/SAMPLE')
    await shot(pg,OUT+'guide_group_card.png',pg.locator('#alGroup')); await shot(pg,OUT+'guide_jobs_tab.png')
    check('guide: no "For the jobs group" list', await pg.locator('#grpH').count()==0)
    await pg.click('#alGroupX'); await pg.wait_for_timeout(100)
    check('guide: dismiss hides the card', await pg.locator('#alGroup').count()==0)
    # posting: the Send to Eretz Israel Tours button, with the message and no name
    await pg.click('#addJ'); await pg.wait_for_selector('#jfTitle'); await pg.fill('#jfTitle','Sample: Masada sunrise')
    d0=await pg.evaluate("()=>{ const x=new Date(); x.setDate(x.getDate()+30); while(x.getDay()>3) x.setDate(x.getDate()+1); return String(x.getDate()).padStart(2,'0')+'/'+String(x.getMonth()+1).padStart(2,'0')+'/'+x.getFullYear(); }")
    await pg.fill('#jfFrom_il',d0); await pg.locator('#jfFrom_il').blur(); await pg.fill('#jfPrice','1200')
    await pg.click('#jfNext'); await pg.wait_for_selector('#jsPost:not([disabled])'); await pg.click('#jsPost'); await pg.wait_for_selector('#jmTxt')
    href=await pg.get_attribute('#jmEit','href') if await pg.locator('#jmEit').count() else ''
    check('guide: "Send to Eretz Israel Tours for the jobs group" button', href.startswith('https://wa.me/972500000000?text='), href[:80])
    from urllib.parse import unquote
    t=unquote(href.split('text=',1)[-1]) if href else ''
    check('guide: its message is English then Hebrew, with the link, no name', t.startswith('New job on The Inner Circle') and 'עבודה חדשה' in t and '#job=' in t and 'Avi' not in t and 'Mizrahi' not in t, t[:200])
    hint=await pg.locator('.sheet-body').inner_text()
    check('guide: the hint line under it', 'Eretz Israel Tours shares approved jobs in the Inner Circle – Jobs WhatsApp group.' in hint)
    check('guide: no preview alert list for a colleague', await pg.locator('.al-prev').count()==0)
    await shot(pg,OUT+'guide_send_to_eit.png',pg.locator('.sheet'))
    await pg.click('#jmDone')
    # the welcome tour has the group line for a guide
    await pg.click('#meBtn'); await pg.wait_for_selector('#myTour'); await pg.click('#myTour'); await pg.wait_for_selector('#tourWrap')
    found=False
    for i in range(12):
        if await pg.locator('#tourWrap .tour-grp').count(): found=True; break
        await pg.click('#tourWrap [data-t="next"]'); await pg.wait_for_timeout(80)
    check('guide: the welcome tour has the jobs group line', found)
    if found: await pg.locator('#tourWrap .tour-grp').scroll_into_view_if_needed(); await shot(pg,OUT+'guide_tour_group.png')
    await b.close()
    # an organisation: no Jobs tab, no group card anywhere
    tag='org'; b=await p.chromium.launch(); ctx=await ctx_for(b,390,844); pg=await page(ctx,tag); await pg.wait_for_selector('.tabs')
    await view_as(pg,'org')
    check('org: no Jobs tab', await pg.locator('.tab[data-tab="jobs"]').count()==0)
    check('org: no group card and no group link anywhere on the page', await pg.locator('#alGroup').count()==0 and 'chat.whatsapp.com' not in await pg.evaluate("()=>[...document.body.children].filter(e=>e.tagName!=='SCRIPT').map(e=>e.innerHTML).join('')"))
    await b.close()
    # a travel agent (full member, not a licensed guide): no group card
    tag='agent'; b=await p.chromium.launch(); ctx=await ctx_for(b,390,844); pg=await page(ctx,tag); await pg.wait_for_selector('.tabs')
    await view_as(pg,'agent'); await pg.click('.tab[data-tab="jobs"]'); await pg.wait_for_selector('.jobcard'); await pg.wait_for_timeout(150)
    check('agent: no group card for a travel agent', await pg.locator('#alGroup').count()==0)
    await b.close()

async def iphone(p):
    tag='iphone'; b=await p.chromium.launch(); ctx=await ctx_for(b,390,844,ua=IPHONE); pg=await page(ctx,tag); await pg.wait_for_selector('.tabs')
    await pg.click('.tab[data-tab="jobs"]'); await pg.wait_for_selector('#alBan')
    await pg.click('#alOn'); await pg.wait_for_selector('.al-steps')
    t=await pg.locator('.sheet').inner_text()
    check('iphone: two steps with the Share button and Add to Home Screen', 'two steps' in t and 'Share' in t and 'square with an arrow up' in t and 'Add to Home Screen' in t and 'tap Turn on again' in t.replace('\n',' '), t)
    await shot(pg,OUT+'iphone_steps.png')
    check('iphone: no sideways scroll', not await pg.evaluate(NOSCROLL))
    await pg.click('#alGot'); await pg.wait_for_timeout(100)
    check('iphone: banner stays (not turned on)', await pg.locator('#alBan').count()==1)
    await pg.click('[data-jv="days"]'); await pg.wait_for_selector('#alPhoneH'); await pg.wait_for_timeout(150)
    check('iphone: My days says add to home screen first', 'home screen' in await pg.inner_text('#alPhoneH'))
    await b.close()

async def signed_out(p):
    for tag,dark in (('unsub',False),('unsub_dark',True)):
        b=await p.chromium.launch(); ctx=await ctx_for(b,390,844,dark); pg=await page(ctx,tag,URL+'#unsub=SAMPLE'); await pg.wait_for_selector('#unsubCard')
        t=await pg.inner_text('#unsubCard')
        check(tag+': unsubscribe page says done', "Done. You won't get job emails any more. You can turn them back on in My days." in t.replace('\n',' '), t)
        check(tag+': no tabs, no sign-in asked', await pg.locator('.tabs').count()==0 and await pg.locator('#gateForm').count()==0)
        check(tag+': address cleaned', '#unsub' not in pg.url, pg.url)
        await shot(pg,OUT+tag+'_page.png'); await b.close()
    b=await p.chromium.launch(); ctx=await ctx_for(b,390,844); pg=await page(ctx,'contact',URL+'#contact'); await pg.wait_for_selector('.tabs')
    await pg.wait_for_timeout(200)
    check('contact: #contact opens the Feedback sheet', await pg.locator('#fbMsg').count()==1)
    await b.close()

async def service_worker(p):
    tag='sw'; b=await p.chromium.launch(); ctx=await ctx_for(b,390,844); pg=await page(ctx,tag); await pg.wait_for_selector('.tabs')
    r=await pg.evaluate("""async()=>{ const reg=await navigator.serviceWorker.register('sw.js',{scope:'./'}); await navigator.serviceWorker.ready;
      const fresh=await fetch(location.pathname+'?fresh=1',{cache:'no-store'}); const t=await fresh.text();
      return {scope:reg.scope, active:!!reg.active, fresh:fresh.ok&&t.includes('const UP_SELF=')}; }""")
    check('sw: registers at the app folder', r['active'] and r['scope']=='http://localhost:8765/', r)
    check('sw: the self-update check still fetches the page fresh', r['fresh'], r)
    await pg.evaluate("()=>navigator.serviceWorker.dispatchEvent(new MessageEvent('message',{data:{type:'eitv-open',url:location.origin+'/#job=jd1'}}))")
    await pg.wait_for_timeout(400)
    check('sw: a tapped notification opens the job', await pg.locator('.sheet-head h2').count()==1 and 'Old City' in await pg.locator('.sheet-body').inner_text())
    await b.close()

async def main():
    async with async_playwright() as p:
        await walk(p,390,844,'phone')
        await walk(p,390,844,'phone_dark',True)
        await walk(p,1280,800,'desktop')
        await guide_and_org(p)
        await iphone(p)
        await signed_out(p)
        await service_worker(p)
    for e in errs: print('ERROR',e)
    print(f'{sum(res)}/{len(res)} passed, {len(errs)} page errors')
asyncio.run(main())
