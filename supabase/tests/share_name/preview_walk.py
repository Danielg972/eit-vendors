# D-67: a shared link carries the entry's name. Preview mode only (sample data, no network).
#   python3 -m http.server 8765 &   then   python3 supabase/tests/share_name/preview_walk.py [folder for pictures]
import asyncio, os, sys
from playwright.async_api import async_playwright
OUT=(sys.argv[1] if len(sys.argv)>1 else '/tmp/share_name').rstrip('/')+'/'; os.makedirs(OUT, exist_ok=True)
res=[]; errs=[]
def check(n,c,d=''): res.append(c); print(('PASS ' if c else 'FAIL ')+n+('' if c else ' :: '+str(d)[:300]))
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch()
        for tag,w,h,dark in [('phone',390,844,False),('phone_dark',390,844,True),('desktop',1280,900,False)]:
            ctx=await b.new_context(viewport={'width':w,'height':h},device_scale_factor=2,color_scheme='dark' if dark else 'light')
            await ctx.add_init_script("try{localStorage.setItem('eitv_tour_seen','1');localStorage.setItem('eitv_share_warned','1')}catch(e){}")
            pg=await ctx.new_page(); pg.on('pageerror',lambda e: errs.append(tag+': '+str(e)))
            src=open('index.html',encoding='utf-8').read(); i=src.rindex('})();')
            body=src[:i]+'window.__t={S,shareLink};'+src[i:]
            await pg.route('**/index.html', lambda r: r.fulfill(status=200, content_type='text/html; charset=utf-8', body=body))
            await pg.goto('http://localhost:8765/index.html'); await pg.wait_for_selector('.tabs')
            if tag=='phone':
                L=lambda *a: pg.evaluate("a=>window.__t.shareLink(...a)", list(a))
                l1=await L('s','vendor_abc','Sample Tours')
                check('English name goes in the link', l1.endswith('#s=vendor_abc&n=Sample+Tours'), l1)
                l2=await L('s','vendor_abc',"Sample's Farm (north)")
                check('apostrophe and brackets are coded', l2.endswith("&n=Sample%27s+Farm+%28north%29"), l2)
                l3=await L('s','vendor_abc','חוות דוגמה')
                check('Hebrew name stays out of the link', l3.endswith('#s=vendor_abc'), l3)
                l4=await L('h','hike_1','')
                check('no name, no tail', l4.endswith('#h=hike_1'), l4)
            vid=await pg.evaluate("()=>window.__t.S.vendors.find(v=>!v.hidden&&/^[\\x20-\\x7E]+$/.test(v.name)).id")
            name=await pg.evaluate("id=>window.__t.S.vendors.find(v=>v.id===id).name", vid)
            await pg.locator(f'#results .row[data-id="{vid}"]').click(); await pg.wait_for_timeout(300)
            await pg.locator('.sheet-head .shr').click(); await pg.wait_for_timeout(300)
            box=await pg.locator('#shLink').input_value(); msg=await pg.locator('#shTxt').input_value()
            check(tag+': copy box starts with the name', box.startswith(name+': http'), box)
            check(tag+': copy box label', await pg.locator('label[for=shLink]').inner_text()=='Name and link')
            check(tag+': message link carries the name', '&n=' in msg and name in msg, msg)
            await pg.locator('.sheet').last.screenshot(path=OUT+tag+'_share.png')
            if tag=='phone':
                link=box.split(': ',1)[1]; ctx2=await b.new_context(viewport={'width':w,'height':h})
                await ctx2.add_init_script("try{localStorage.setItem('eitv_tour_seen','1')}catch(e){}")
                pg2=await ctx2.new_page(); pg2.on('pageerror',lambda e: errs.append('open: '+str(e)))
                # Served as it is on disk (no test hook), so the app's own new-version check does not reload it.
                await pg2.goto(link.replace(link.split('#')[0],'http://localhost:8765/index.html')); await pg2.wait_for_timeout(1500)
                head=await pg2.locator('.sheet-head').first.inner_text()
                check('the named link opens that supplier', name in head, head)
                check('address is cleaned after opening', '#' not in pg2.url, pg2.url)
                old=link.split('&n=')[0]; await pg2.goto('about:blank')
                await pg2.goto(old.replace(old.split('#')[0],'http://localhost:8765/index.html')); await pg2.wait_for_timeout(1200)
                check('an old link without a name still opens', name in await pg2.locator('.sheet-head').first.inner_text())
                await ctx2.close()
            await ctx.close()
        await b.close()
    check('no page errors', not errs, errs)
    print(f'{sum(res)}/{len(res)}')
asyncio.run(main())
