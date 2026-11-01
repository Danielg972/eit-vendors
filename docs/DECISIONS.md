# The Inner Circle – Israel Guide: decisions

*Called the Israel Suppliers Master List until 2 October 2026 (D-6).*

Decisions that bind this project. Newest first. Each entry says who decided, when, and on what evidence.

*D-12, D-14 and D-16 were built on the branch `guide-for-clients` at the same time as D-15, and rebuilt on top of it before anything of theirs touched production. See the note under D-15.*

*D-15 (limited members) was first recorded as D-12 by mistake, for a few minutes on 3 Oct; D-12 was already taken on that branch.*

---

## D-70 · Armored (bulletproof) and stone-proof vehicles in Transport, by size (live 1 Nov 2026)

**Owner, 1 Nov 2026, 11:18:** "on transport bus all transport add armored / bulletproof with bus size options".
**Owner, 11:32**, shown the preview and asked (1) go live, including the database change, and (2) stone-proof as its own option too: "1 yes 2 yes".

**Built (branch `armored-d70`):** four new vehicle sizes, everywhere Transport uses sizes (the list's size filter, a supplier's
"Vehicles", the vehicles a company offers when editing, quote options, transport prices, the quotes board and booking sheets):
Armored bus (36–60 seats), Armored midibus (21–35), Armored van (up to 20), Armored car (up to 4). Keys `arm_bus`,
`arm_midibus`, `arm_van`, `arm_car`. The booking sheet the company gets says it in Hebrew and English ("אוטובוס 50 מקומות ממוגן ירי"
· "50-seat armored bus").

**Stone-proof (owner, 11:32):** its own family with the same four sizes: Stone-proof bus, midibus, van, car (keys `stone_bus`,
`stone_midibus`, `stone_van`, `stone_car`; Hebrew "ממוגן אבנים").

**Implementation choices (not owner decisions):** armored means bulletproof (ממוגן ירי); stone-proof is never counted as armored. A seat count alone never makes a vehicle armored: it is chosen, or written in a tag or an option name
("armored", "armoured", "bulletproof", "ממוגן ירי"). Van sizes are not split for armored vans. Database: migration
`2026-11-01_armored_vehicles.sql` adds the four keys to the vehicle lists in `_quote_kind`, `quote_save`, `booking_save` and the
label in `_booking_to_quote` by editing their live text, and widens the check on `bookings.service` (drop and add again; no row changes).

**Live (owner, 11:36: "do it for me"):** migration `armored_vehicles_2026_11_01` applied to production at about 11:37; the four
functions on production match the tested copy (fingerprints; `_booking_to_quote` differs only in line endings); check widened;
219 functions, 0 grants, 0 policies. Pull request #98 merged (main 26dae8f), site deployed 11:38. A rolled-back write probe on
production was refused by a safety check and not run.

---

## D-69 · Job alerts by phone and email; the jobs WhatsApp group (live 31 Oct 2026, alerts to Eretz Israel Tours only at first)

**Owner, 31 Oct 2026, 20:29:** "can we do Free and automatic: the app sends each colleague a phone notification and an email when a job fits them". **20:41**, his answers: email on for everyone with an unsubscribe link, telling them it is for the jobs board; skip colleagues who marked those days busy; price shown in the alert; English then Hebrew; nothing over Shabbat and Yom Tov, candle lighting to havdalah, Jerusalem times; nothing at night "from 11 - 7"; also alert the colleague a job is given to and those who said available when a job closes, not on edits; alert the poster when someone says "I'm available"; email by Resend; no replies, "they click link and have a contact admin option"; a terms line is fine and every member accepts again. **20:44:** "(b) Guide jobs alert only guides, but a driver job alerts drivers". **21:28:** "add it to the job board when they sign up" (the jobs WhatsApp group). **21:57:** "It comes to me to approve the post and send it as admin." **21:58:** both ways for a colleague's job to reach him for the group (a list in the app with an alert, and a "Send to Eretz Israel Tours" button on WhatsApp).

**Who gets a new-job alert:** approved full members only, never an organisation (C4), never the poster, nobody busy on the job's dates (My days). A job for picked colleagues: only them. A job for everyone it fits: a guide or guide-with-vehicle job only to licensed tour guides, and not one who said he takes no jobs or set what he takes without that kind; a van-driver or jeep-driver job only to members who ticked that kind in "Jobs I take"; a "someone else" job only to those who ticked "Other work". Must-haves count as on the Jobs tab. The Jobs tab itself is unchanged.

**Also alerted:** the colleague a job is given to ("The job is yours"); everyone who said available when a job is closed; the poster when someone taps "I'm available" ("Someone is available"); Eretz Israel Tours when a colleague posts ("A colleague posted a job: share to the jobs group?"). No alert on edits. An alert never names the poster.

**When:** nothing from candle lighting (40 minutes before sunset, Jerusalem) to havdalah on Shabbat and Yom Tov in Israel, and nothing from 23:00 to 07:00 Israel time; held alerts go when the hold ends. Times from `@hebcal/core` with the Israel holiday schedule.

**How:** email through Resend from "The Inner Circle – Israel Guide <jobs@eretzisraeltours.com>", English then Hebrew, a "See the job and answer" button, a one-tap "Stop job emails" link that works without signing in, and "Contact Eretz Israel Tours", which opens the app's Feedback sheet (`#contact`); replies are not read. Phone notifications by free web push (VAPID) through `sw.js` at the site root; a tap opens the job (`#job=<id>`). A one-time banner on the Jobs tab, "Get job alerts on this phone", with Turn on / Not now; on an iPhone not yet on the home screen it shows the two steps. In My days, "Job alerts": "Email me jobs that fit me", "Phone alerts on this phone", and the line about fit, busy days, Shabbat, Yom Tov and night.

**The jobs WhatsApp group:** app setting `jobs_group_link` (Eretz Israel Tours sets it in the admin settings; only `https://chat.whatsapp.com/...` or empty). The database gives it only to approved licensed tour guides and Eretz Israel Tours; it is never in the code. Shown as a card on the Jobs tab (with Dismiss) and as one line in the welcome tour's jobs screen. A colleague's job goes on Eretz Israel Tours' "For the jobs group" list (My posts), with "Approve and share" (WhatsApp share without the poster's name, then marked shared) and "Not for the group" (marked skipped); both recorded with who and when (`jobs.group_status`, `group_at`, `group_by`, through `job_group_mark`). On the poster's "Posted" sheet, a colleague also gets "Send to Eretz Israel Tours for the jobs group", which opens WhatsApp to the number in app setting `admin_whatsapp` (given only to approved full members; never in the code; the button is hidden when it is empty).

**Terms:** one paragraph in 6d (job alerts: on for everyone, by email and, if allowed, on the phone; switch off any time; only for the job board). Terms version `2026-10-31a`; every member accepts again.

**Implementation choices (not decided by the owner):**
- A colleague's job is not held back for Eretz Israel Tours' approval: it reaches colleagues in the app and by alerts as before. The approval is only for the WhatsApp group.
- A new setting `alerts_for` ('admin' by default = only Eretz Israel Tours gets alerts; 'all' = every colleague a job fits), in the admin settings next to "Jobs between colleagues", so the feature opens to Eretz Israel Tours first (G2).
- Eretz Israel Tours gets the "share to the jobs group?" alert for a colleague's job, not the ordinary new-job alert.
- A guide who has not said what jobs he takes gets guide jobs (as the Jobs tab offers him everything); a driver or "other" job needs the kind ticked.
- The busy check is made when the alert is queued and again when it is sent.
- An alert older than 7 days that was never sent is skipped; a "busy" answer from the push or email service is tried again up to 6 times.
- Up to 10 phones per member. A phone the push service says is gone is switched off.
- The email's Hebrew block is one line of the job plus the button text; the day-by-day lines go once, under the English (as D-68's message).
- The notification's Hebrew line says "עבודה חדשה ל<kind> · <price>".
- The welcome tour gets one line (not a new screen), shown only when the member has the group link.

**Database** (`supabase/migrations/2026-10-31b_job_alerts.sql`): adds `members.alerts_email`, `members.alerts_key`, `jobs.group_status/group_at/group_by`, tables `push_subs` and `alert_queue` (RLS on, no grants to anon or authenticated, no policies), three triggers on `jobs` and `job_offers` (created only if missing), RPCs `alerts_state`, `alerts_set`, `push_subscribe`, `push_unsubscribe`, `alerts_unsubscribe` (no sign-in, by key), `job_alerts_list` and `job_group_mark` (Eretz Israel Tours), and service-key functions `_alerts_due`, `_alert_mark`, `_push_mark` for the sender. Replaces `set_setting` (keys `jobs_group_link`, `admin_whatsapp`, `alerts_for`) and `_job_json` (`group_status`, `group_at` for Eretz Israel Tours only); neither holds DELETE. Not replaced: `job_save`, `job_set_status`, `job_delete`, `my_days_set`, `whoami`. No DELETE or DROP outside comments. The pg_cron schedule is a commented last section, run by the go-live session.

**Sender:** Edge Function `job-alerts` (`supabase/functions/job-alerts`), called every 5 minutes; refuses callers without the shared secret or the service key. Email rows wait while `RESEND_API_KEY` is missing; push rows wait while the VAPID keys are missing.

**Checked (by the session that built it):** `supabase/tests/job_alerts/preview_walk.py` 81/81 in preview (phone, phone dark, desktop; guide, organisation, travel agent; iPhone Safari; the unsubscribe page signed out; `#contact`; the service worker and the self-update check); `recipients_probe.sql` 23/23 and `sender_probe.sql` 12/12 on a local database built from `schema.sql`; the limited-member checks 98/98 with this change; `holds_test.ts` 13/13 and `messages_test.ts` 4/4 (Deno). The D-68 walk still passes 42/42. Not checked: a real phone notification, a real email, anything on production.


**Live (31 Oct 2026, 23:19: "Go. Live").** Applied through the connector: `job_alerts_2026_10_31` (the 2026-10-31b file without its last commented section). Production read first: `set_setting` and `_job_json` matched the record. `recipients_probe.sql` run on production as a rolled-back transaction: 23/23; nothing left behind; 0 table grants, 0 policies; 199 to 219 functions. Edge Function `job-alerts` deployed (verify_jwt false), version 1, the files in supabase/functions/job-alerts. Settings: `alerts_for` = admin (only Eretz Israel Tours gets alerts until the owner switches it), `jobs_group_link` and `admin_whatsapp` set (values only in the database).
**Keys (implementation choice at go-live).** The keys are no longer typed in: `2026-10-31c_job_alerts_keys.sql` makes the shared secret inside the database's Vault, the Edge Function makes the phone-notification key pair on its first run and keeps it in the Vault (`_alerts_set_vapid`), and the app takes the public key from `alerts_state` (`vapid_public`). The builder's earlier key pair was discarded, never used. Writing to the Vault was refused to the master agent by a safety check, so the owner runs that file (with the pg_cron schedule) himself in the SQL editor.

## D-68 · Job board: a line for each day, Jerusalem Old City, message in English first (live 31 Oct 2026)

**Owner, 31 Oct 2026, 19:56:** "job board is not good. i need to message each person one by one in whatsapp and that is annoying. also it doesnt have a Jerusalem Old City option. also if more than one day each day should get its own description - also it should have english first in message andf then hebrew". **20:16**, after the preview pictures: "yes make it live".

- A job of more than one day gets a box for each date when posting ("Day 1 · Thu 12 Nov"): what happens that day, and hours that day (optional). Colleagues see the lines under "Day by day" on the job, in the calendar entry and in the WhatsApp message. The general Hours box stays, labelled "Hours, if the same every day" on a multi-day job.
- "Jerusalem Old City" is a region choice for jobs. Implementation choice: jobs only; suppliers keep "Jerusalem".
- The WhatsApp message is English first, then Hebrew. Implementation choice: the day lines go once, under the English, as the poster wrote them.

**Database** (`supabase/migrations/2026-10-31_job_days.sql`, applied through the connector as `job_days_2026_10_31`): adds `jobs.days`, adds `job_set_days` (poster or Eretz Israel Tours, open jobs only; keeps only days inside the job's dates, one per day, in order), replaces `_job_json` to send `days`. Adds and replaces only; no table grant or policy. The day lines are the poster's own words about the work; no name, phone or email goes in them.

**Checked:** `supabase/tests/job_days/preview_walk.py` 42/42 in preview (phone, phone dark, desktop). On production, a rolled-back probe as Eretz Israel Tours: lines sorted, a day outside the dates and an empty day dropped, clearing works, `jobs_list` carries the lines; nothing left behind. Production `_job_json` was read first and matched the record. Built and checked by the same session.

**Not decided:** how a job reaches colleagues without messaging each one. Put to the owner: send once to a WhatsApp group from the share sheet (free, works today); phone notification and email from the app (free, each colleague allows it once); automatic WhatsApp from an Eretz Israel Tours business number (Meta charges per message; his money decision).

## D-66 · "Open now" on places you visit (live 26 Oct 2026)

**Owner, 26 Oct 2026, 21:02:** "I like the open now idea. I like how city of David looks, so forget revamping." (The idea was in a mock-up of a restyled list, 15:56; the restyle itself is dropped.) **21:29**, after a picture of it in the app's own style: "Go live"

On the supplier list and beside "Opening hours" on a supplier's page, a place you visit (sites, parks, wineries, restaurants, activities; not hotels, guides, transport, jeeps) shows "Open now · until 17:00" or "Closed now", worked out from its hours on Israel's clock today, using the season the clock is on (D-65). Implementation choices, all toward showing nothing rather than something wrong: holiday eves and festivals are left out; a part of a site with its own name, a row with a remark, a time past midnight or a day it cannot read gives no mark; hours whose sources disagree, or visits only by appointment or arrangement, give no mark; days not listed are not taken as closed; "Closed Shabbat" gives no mark on a Saturday from 16:00. Front end only, no database change. Checked: supabase/tests/open_now/preview_walk.py 10/10 in preview.

## D-65 · Winter or summer hours come first by themselves, with the D-33 hours layout (live 26 Oct 2026)

**Owner, 26 Oct 2026, 15:39:** "Update city of David winter hours. Can we set winter hours as default when winter hours begin", with City of David's own notice of winter hours from 25 Oct. **15:56**, after an inline mock-up of the City of David hours box: "Go live."

Where a supplier lists both Summer and Winter hours, the season Israel's clock is on today comes first with a "Now" mark and the other folds under one tap ("Summer hours" / "Winter hours"). Last-entry lines that start with Summer or Winter fold the same way. The clock change does it; nobody edits anything twice a year. Implementation choices: a sentence starting "Summer and winter time…" counts for neither; when a current-season line refers back ("all of these one hour earlier") nothing folds or moves; if the browser cannot tell Israel's clock, everything shows as written. Nothing in the stored text changes.

It rides on D-33 (8 Oct: opening hours laid out as days and times, last entry as a list, the Unverified/Verified mark at the foot of the box), which was built on `supplier-page-hours` and never went live; brought onto main at 8ad13a7, keeping today's red report button, online links (D-62) and the D-64 price box. Front end only, no database change.

## D-64 · The old single "Main price" comes off a supplier's page once it has price lines (live 26 Oct 2026)

**Owner, 26 Oct 2026, 12:20:** "Sure if it's just clutter remove it." Asked at 12:19 why the main price that goes to R5 is only the adult price (Machon Ayalon): R5's supplier record holds one listed and one agent price, so that box can hold only one number; the full prices (adult, child, senior, student) are the price lines. Offered: hide the box on any supplier that already has price lines.

**Built (front end only, branch `main-price-box`):** on a supplier's page, once its price lines load, the agent price, listed price and basis rows of the old "Main price" box are taken out. Max people and payment terms stay, under the heading "Booking terms"; if neither is filled the box goes. A supplier with no price lines keeps "Main price" as before. The words "(goes to R5)" are gone everywhere (R5 is frozen, F3). The saved fields (`agentPrice`, `listedPrice`, `priceBasis`) are untouched, as are the edit form, the price chip on the supplier list and the legacy R5 export.

**Checked:** `supabase/tests/main_price_box/preview_walk.py` 21/21 in preview (phone, phone dark, desktop). No database, terms or Cockpit change. Built and checked by the same session.

---

## D-63 · Hebrew fields for the business name and the contact person (live since 25 Oct 2026, about 19:05)

**Live:** the owner, 25 Oct 2026, 18:56: "Go live". Production read first: 37 tables, 197 functions equal to the record, 0 table grants, 0 policies. Migration applied through the connector at the first try; afterwards 198 functions, every fingerprint equal to supabase/tests/production_fingerprints.txt; production_probe.sql run on production as a rolled-back transaction: 39 checks, 0 failed, nothing left behind. Pull request #89 merged (main 28d1916).

**Owner, 25 Oct 2026, verbatim:** "I want to start having Hebrew fields for the names of the business and [a Hebrew] option for contact people".

**Built (branch `online-links-hebrew-names`, from main f549dd1; draft pull request, not merged):**
- Two new fields on a supplier: `name_he` (business name in Hebrew) and `"contactPerson_he"` (contact person in Hebrew), at most 200 characters each, empty by default. Live data is not rewritten.
- Form: "Name in Hebrew" (optional) right under the name, "Contact person in Hebrew" right after the contact person, both `dir="rtl"`.
- **Locked like their English twins (rule E3):** for a colleague or an organisation, a change to either becomes a change request with a reason, which Eretz Israel Tours approves in Review (Suggested changes shows "Name in Hebrew" / "Contact person in Hebrew", now and suggested). A new supplier from a colleague waits for review anyway.
- Supplier page: the Hebrew name under the title (right to left); the Hebrew contact beside the contact. List card: the Hebrew name beside the English name, unless the English name already holds the same Hebrew in brackets. Search and search suggestions match the Hebrew name and the Hebrew contact.
- **Bracket helper:** when "Name in Hebrew" is empty and the name holds Hebrew in brackets (e.g. "Sample Tractor Rides (טרקטורונים לדוגמה)"), the form offers "Use “…” from the name". It only copies into the box; nothing is saved until the member saves.
- Booking sheets (D-5, small change): when the bus or van company's entry has a Hebrew name, the Hebrew side of the sheet ("חברה") and the WhatsApp copy use it, with the English name beside it (`booking_open` returns `company_he`, `_booking_json` returns `vendor_name_he`). The same wording block was changed in `index.html` and `b/index.html`.
- Supplier details form (D-61): the form page already asked for the business name in Hebrew; it now also asks for the contact's name in Hebrew. Both come into Review as rows to tick (a Hebrew name, like an English name, starts unticked) instead of a line in the note.

**Implementation choices (the owner may change any):** Hebrew boxes are optional; the Hebrew name shows on the card only when the English name does not already contain it; no check that the Hebrew name is in Hebrew letters; the bracket helper only suggests; existing bracketed names are left as they are.

## D-62 · Online links on a supplier's page: social media, TripAdvisor, Google business page (live since 25 Oct 2026, about 19:05)

**Owner, 25 Oct 2026, verbatim:** "Make a link for social media", then "Also tripadvisor and Google business page", then, after seeing a mock-up: "Build it".

**Built (same branch and migration as D-63):**
- One new field `vendors.links`: one http or https link per line, at most 10, each at most 500 characters. The database cleans every save (`_links_clean`): a bare "instagram.com/x" gets https://; exact repeats are dropped; anything else (javascript:, data:, mailto:, ftp:, a word that is not a link, quotes or angle brackets in the address, an 11th link) is refused with "Only web links can be saved…" / "That link does not look right…" / "At most 10 online links." A table check also refuses any non-http(s) value written past the functions.
- Supplier page: an **Online** section under the contact buttons, one row per link: a plain-text name worked out from the address (Instagram, Facebook, TikTok, TripAdvisor, Google business page for google.com/maps, maps.app.goo.gl, g.page, business.google.com and goo.gl/maps, YouTube, X (Twitter), LinkedIn; anything else by its host name), the handle where easy (@name from instagram.com/name, tiktok.com/@name, youtube.com/@name; the Facebook page name), and the app's own plain external-link icon. **No other company's logo is drawn (rule A7).** Each opens in a new tab with `rel="noopener"`; a tap is logged as a website tap. Only filled links show; no links, no section.
- Edit form: "Online links" box under Website: one box per link, "+ Add another link", × to remove, several links pasted into one box split into boxes, each box says what it is ("Instagram", "Not a link"). **Not locked:** any member, organisations included, saves links the way they save opening hours, straight away.
- Who sees them: everyone who can see the supplier, organisations included. They are public business details, not prices (C3/D4 unchanged: agent prices, private prices and member details are exactly as protected as before).
- Supplier details form (D-61): the single "Instagram / Facebook" box became a links box (one per line). Its web links come into Review as one "Online links" row (the entry's links plus the new ones); text that is not a link goes into the note as "Online (not a link): …". An answer from the older page (`social`) is read the same way.

**Implementation choices (the owner may change any):** one text column with one link per line (not jsonb); at most 10 links, 500 characters each; names by domain as listed; the Online section sits under the contact buttons; links are open to every member, like hours; the Cockpit reader (D-57) does not return links or Hebrew fields.

**Database (D-62 and D-63 together), add and replace only, NOT on production:** `supabase/migrations/2026-10-25_online_links_hebrew_names.sql`. Columns `vendors.links`, `vendors.name_he`, `vendors."contactPerson_he"` with checks `vendors_links_check`, `vendors_hebrew_check`. New helper `_links_clean(text, boolean)` (revoked from public, anon and authenticated). Replaced with `create or replace` (no return type changed): `_all_fields`, `_locked_fields`, `_vendor_apply`, `vendor_save`, `_form_clean`, `_form_rows`, `_booking_json`, `booking_open`. No DELETE, no DROP, no table grant, no policy; safe to run twice. Read functions are unchanged: they send the whole supplier row. 197 functions become 198. `supabase/schema.sql` carries the change (a clean build equals main plus the migration, run twice, in every function, column, constraint and right); `supabase/tests/production_fingerprints.txt` holds the 198 and keeps production's 197 as "production before D-62".

**Checked (local only):** `supabase/tests/online_links_hebrew/run.sh`: schema record = main + migration 5/5; the rolled-back probe `production_probe.sql` 39/39 (also 39/39 with the migration put inside it by `run_probe.py` on main's schema, leaving nothing behind), made to fail on purpose twice (Hebrew name unlocked: 7 failures; link cleaner let through: 12 failures); `probe.py` 81/81 as Eretz Israel Tours, a guide and an organisation. Limited-member checks 98/98; the probes of D-61 (77/77), D-57 (75/75), D-60 (35/35) and of booking days, day times, transport prices, hikes, rentals, route link and claims give the same results as on main. Preview: `online_links_hebrew/preview_walk.py` 143/143, 0 page errors (phone 390 px, phone dark, desktop; Eretz Israel Tours, a guide, an organisation; the supplier's form page). Other walks unchanged from main: supplier_forms 140/140, confirmed_mark 63/63, batch_walk 78/78, transport 46/46, hikes 204, hike page 133; `price_rows` 15/18, `back_button` and `rentals` (a date-dependent calendar step) fail the same way on main.

**Not checked:** production; a real phone; the live site. **To do after go-live (data, by hand):** two live suppliers carry social links in their notes that should move into the new field (named in the session report, not here, D7).

## D-61 · A full member can send a supplier a details form; the answers wait in Eretz Israel Tours' review list (live since 19 October 2026 for Eretz Israel Tours only; the switch for full members is off)

**Owner, 19 Oct 2026, 10:13, verbatim:** "Can you integrate that into he app so people can send this form to venders?" (the bilingual Eretz Israel Tours supplier details form made that morning as a separate private Claude page). **About 10:16:** the answers go to Eretz Israel Tours' review list; all full members can send it; the form lives on the app's address. **10:18**, asked whether that meant a separate page on vendors.eretzisraeltours.com showing only the form, and told that the address itself shows a vendors site exists while rule B1 says suppliers never see the app: "Yes that's what I meant". Read as: B1 stands for the app, its list, prices and notes; the form page is the one page on the app's address a supplier may open, and it shows nothing from the app.

**Mock-up (G1):** Claude artifact "Supplier Form Mock-up", 19 Oct (private to the owner), https://claude.ai/artifact/LdfjrFVF2bHTCZitJMdSER: three phone screens (a member sends the form; the supplier fills it in; Eretz Israel Tours reviews) and five choices made for him. **The build order, 19 Oct, evening:** "build D-61 (a full member can send a supplier a details form; answers wait in Eretz Israel Tours' review list) exactly as the owner approved in the 19 Oct mock-up, on its own branch ... Do not merge or go live without the owner's word." The rulebook (version 9.3) had recorded the mock-up as shown, not approved; this order is taken as his approval.

**Built (branch `supplier-form-d61`, on main 0da9635):**
- **Send:** "Send form to supplier" beside Edit at the foot of a supplier's page, and a "Rather the supplier fills it in?" box on Add supplier (uses the typed name). It makes a link and opens "Send details form": the WhatsApp message ("Hi, this is [your name]. Could you fill in your business details for Eretz Israel Tours' guides? It takes about 5 minutes." and the Hebrew line), "The supplier sees only an Eretz Israel Tours form. Never send a supplier a link to the app itself.", Send on WhatsApp (to the supplier's WhatsApp or phone when the entry has one) and Copy link.
- **The supplier's page `f/?k=…`:** a plain Eretz Israel Tours page, English with Hebrew, no menu, no login, no link into the app, `noindex`. Only the business name is filled in ahead. The fields of the morning's form: the business (kind uses the app's own categories), location (the app's regions), booking contact, opening hours by day (sent as one line, days run together), last entry, Shabbat, groups and the visit, kosher, prices (adult, child, group, rate for guides and agents, VAT), payment, cancellation, a visit for guides, notes, and the consent line. Business name, contact and phone are required. "Send to Eretz Israel Tours · שליחה", then "Thank you! Eretz Israel Tours has your details. The link now closes." Photos and price lists: to Eretz Israel Tours' WhatsApp, as in the morning's form.
- **Review → Supplier forms (Eretz Israel Tours only):** "N new"; each answer shows who sent the link and when it was answered; for a supplier on the list, In the app beside From the supplier, line by line, with a tick on each changed line, "Same ✓" where nothing changed, the old value struck through, and "Apply N ticked" / Open supplier / Discard (a second tap). A supplier not on the list: "New: name", "Not on the list yet", "Create entry from form" opens the usual Add supplier form filled from the answers; after saving, the form belongs to the new entry and its prices and other details are applied the same way.
- **Team → Supplier forms:** "Open supplier forms to all full members" (`forms_for`, off: Eretz Israel Tours only). Organisations never get the button (C2, C3).
- **Database, add and replace only, NOT on production:** `supabase/migrations/2026-10-19_supplier_forms.sql`. Table `supplier_forms` (RLS on, no grants to anon or authenticated, no policies; the link key is kept only as its hash). Helpers `_forms_on`, `_form_clean`, `_form_rows` (revoked from everyone). Member call `supplier_form_new(p_token, p_vendor, p_name)` through `_auth`; the supplier's calls `supplier_form_open(p_key)` (returns the business name and expiry only) and `supplier_form_answer(p_key, p_answers)` (known fields only, once); Eretz Israel Tours' calls `supplier_forms_list`, `supplier_form_apply(p_token, p_id, p_keys)`, `supplier_form_link`, `supplier_form_discard`, all through `_auth(p_token, true)`. Replaced: `whoami` (adds `forms`, `forms_for`) and `set_setting` (adds the key `forms_for`). Not yet in `supabase/schema.sql`: it goes there when the file is run on production, as with D-59 and D-60.

**How applying works:** fields go through `vendor_save` as Eretz Israel Tours' own edit, so the kosher, guide and Eshkol rules hold (a non-kosher restaurant is refused and nothing is saved); hours come in Unverified with "the supplier's details form, date" as their source (E2); a Shomer Shabbat answer sets or clears the tag; each price is a new line, "From the supplier: details form, date", not confirmed, with the supplier's own words as its note (E4); a rate for guides and agents is an agent line, so organisations never receive it (C3, D4); the rest goes onto the entry as one note from Eretz Israel Tours. All or nothing.

**Implementation choices (labelled; the owner may change any):**
- From the mock-up: one link per supplier, single use, 30 days; the supplier sees only the business name; nothing reaches an entry until Eretz Israel Tours applies it; prices come in "from the supplier", not confirmed; a new supplier becomes an entry only on Create entry; open to Eretz Israel Tours first (G2).
- Made in the build: the button sits in the page's bottom bar beside Edit (the mock-up drew both in a card at the top); Edit keeps its look; the mock-up's "Details last checked 3 months ago" line is not built (the app has no reliable date for it). A changed business name is shown but not ticked to start. Prices are added as new lines, so the old price is not struck through and stays on the entry. Details that have no field on an entry (visit length, group size, ages, accessibility, bus parking, how to book, a visit for guides and the like) become one note. An agent rate typed without a number is shown to Eretz Israel Tours only and never put in a note. At most 30 links a day per member. The draft a supplier is typing is kept on their own phone until sent.

**Checked (by the building session only):**
- Local copy built from `supabase/schema.sql` plus the migration: `supabase/tests/supplier_forms/production_probe.sql` 77/77 (as Eretz Israel Tours, a guide, an organisation and the anonymous page); limited-member checks 98/98 with the migration in. The probe was made to fail on purpose five ways (the page sending the sender's name, the link reply carrying an email, an agent line saved as public, organisations allowed, a second answer accepted) and caught each.
- On production, rolled back (19 Oct, about 21:50 Israel time; the probe with the migration inside it, as one statement through the connector): **77/77**, nothing failed, and the 12 new or replaced functions as created there have the same fingerprints as a clean local build of these files. Read before and after: 36 tables, 187 functions, the same fingerprints, no table `supplier_forms`, no sample member or supplier left, 0 table grants, 0 policies, last migration still D-60's. An earlier run of the same day (before the agent-rate fix below) was 75/75.
- Preview (sample data): `supabase/tests/supplier_forms/preview_walk.py` 140/140, 0 page errors (phone, phone dark, desktop; a guide, an agent and an organisation; the supplier's page). Unchanged by this branch: confirmed_mark 63/63, batch_walk 78/78, transport 46/46, rentals 122, hikes 204, hike page 133. `price_rows/preview_walk.py` (15/18) and `back_button/back_walk.py` (stops on a missing test hook) fail the same way on main without this branch.

**Not checked:** the live site and a real phone; WhatsApp opening with the message; a real supplier filling the form; the welcome tour and terms do not mention the form.

**Owner, 19 Oct 2026, verbatim:** "yes · 2 lawyer list · 3 anyone can share jobs". Go live in the order given; leave "Open supplier forms to all full members" off; the consent line goes on the lawyer's list.

**On production (19 Oct, about 22:55):** main had the records branch merged first (#85, main db3bb56); the D-61 branch was brought up to date with it (README sections kept from both sides); limited-member checks 98/98 and the local probe 77/77 on the merged branch. `2026-10-19_supplier_forms.sql` was applied through the connector as `supplier_forms_2026_10_19`. Checked there: 37 tables, row security on all, 197 functions, 0 table grants, 0 policies; the table and the three helpers closed to anon and authenticated; the 12 new or replaced functions equal the tested build; `forms_for` not set (Eretz Israel Tours only). The D-61 block was added to `supabase/schema.sql`: a clean build equals production in all 197 functions; `supabase/tests/production_fingerprints.txt` holds the 197. The probe on production after go-live, rolled back: **77/77**, nothing left behind.

**Live:** pull request #86 merged on the owner's word (main at 945f695); GitHub reports the site built and deployed from that commit at 22:57 Israel time (pages build and deployment, run 141). Production read after: 37 tables, 197 functions equal to the schema record, 0 table grants, 0 policies, `supplier_forms` empty, `forms_for` not set. On main after go-live: limited-member checks 98/98, preview walk 140/140. Not seen: the page the live site serves, because this session's network cannot reach vendors.eretzisraeltours.com or the database's web address; the deployed files were checked in the repository at 945f695 instead. Not tried: a real phone, WhatsApp, a real supplier.

**Before go-live (kept from the build):** the consent line on the supplier's page ("I agree that Eretz Israel Tours may share these business details with licensed tour guides and travel professionals") is new wording shown to people who are not members; it belongs on the lawyer's list with the other personal-data points. The page lives on the app's address (the owner's choice at 10:18).

## D-60 · Batch confirm, made safe and faster: a check before saving, already-confirmed prices skipped, all or nothing, one undo (Eretz Israel Tours only; live since 18 October 2026, 20:37)

**Owner, 17 Oct 2026, verbatim:** "I need a faster way of approving prices. It's one by one. Like city of David. I just put all of those prices in. I should be able to batch confirm them."

**Order given with it (18 Oct):** on one supplier's price lines, Eretz Israel Tours ticks several lines (or "select all"), picks one way and one kind for the batch and confirms them in one action, with a clear count and a review step before saving; each line still gets its own confirmed_at / confirmed_by / confirmed_how; already-confirmed lines are shown and skipped; one undo for the whole batch. Eretz Israel Tours only. G1, add-only database changes, rolled-back probes on production, no change to the Cockpit and no reader key. Rules checked: D-1, F1, D1–D7, E1, E2, G1–G12.

**Why a new number:** D-58 (live since 17 Oct, 23:41) already gives "Confirm prices…", but it saves straight away, re-marks confirmed prices if ticked, saves price by price (a failure part way leaves some saved), and has no undo. D-60 changes those four things and keeps everything else.

**Built:**
- The same "✓ Confirm prices…" button. The list shows the unconfirmed prices ticked, with Tick all / None and a count ("5 of 5 ticked · 1 already confirmed"). Prices already confirmed are listed underneath, "Already confirmed · skipped (N)", with their mark and no tick box.
- One way (official list · their document or email · paid invoice · conversation) and optionally Tariff or Negotiated, then "Review N prices…".
- **Check before saving:** how many, which supplier, how, kind, today's date, how many skipped, and the list of prices that will be marked. Back keeps the ticks and choices. "Confirm N prices" saves.
- One database call, `price_confirm_batch`, saves all or nothing. Each line gets its own `confirmed_at`, `confirmed_by` ('Eretz Israel Tours') and `confirmed_how`, the same fields a single confirm writes. A line already confirmed is skipped even if sent. A line not of that supplier (or deleted meanwhile) stops the whole batch: nothing is saved and the sheet says so.
- **Undo:** after saving, "↶ Undo the batch (N)" shows beside "Confirm prices…" for the rest of the visit. Tap, then "Tap again to undo". `price_confirm_batch_undo` takes the mark off every line still carrying the batch's own mark and puts back the kind each had. A line changed since (price edited, or confirmed again on its own) is left as it is and the message counts it. A batch is undone once.

**Database (add only, on production since 18 Oct 2026 on the owner's "go"):** `supabase/migrations/2026-10-18b_batch_confirm.sql` — table `price_confirm_batches` (RLS on, no grants to anon or authenticated, no policies), functions `price_confirm_batch(p_token, p_vendor, p_ids, p_how, p_kind)` and `price_confirm_batch_undo(p_token, p_batch)`, both through `_auth(p_token, true)`. Nothing replaced: `price_confirm`, `price_marks`, the mark guard and the Cockpit's functions are untouched.

**Implementation choices (labelled):**
- Kind stays optional, as in the single sheet; with none chosen each line keeps the kind it had (a single confirm with none chosen clears it).
- The undo button lasts for the visit (leaving the app forgets it); the batch record stays in the database, so an older batch can still be undone from the SQL editor if ever needed.
- At most 500 prices in one batch.
- To re-mark a price already confirmed, open that price (the single sheet), as before.

**Checked:**
- On production, rolled back: `supabase/tests/batch_confirm/production_probe.sql` with the migration put in by `run_probe.py`, as one statement that ends by raising its result: **35/35**, then a read-only check that no table, function, sample member or sample supplier was left. Covers: a guide, an organisation and a bad link refused; anon and authenticated cannot read the batch table; no way / a website / a wrong kind / nothing ticked refused; a line of another supplier refuses the whole batch with nothing saved; each line its own record; the confirmed line skipped and untouched; no kind keeps the kind; members never see a mark; undo clears the batch's lines and puts the kind back, leaves an edited line and a re-confirmed line, refuses a second undo; the single confirm and the mark guard unchanged; every real price line unchanged.
- Preview (sample data): `supabase/tests/confirmed_mark/batch_walk.py` **78/78** (phone, phone dark, desktop as Eretz Israel Tours; a guide, an agent and an organisation see no button), `confirmed_mark/preview_walk.py` 63/63, `transport_prices/preview_walk.py` 46/46, 0 page errors.

**Not checked:** the live site and a real phone; the all-or-nothing refusal from the screen (only from the database probe); two people confirming the same supplier at once.

**Mock-up (G1):** seven screens, Claude artifact "Batch Confirm Mock-up" (private to the owner), https://claude.ai/artifact/JKiovWUXucsWuwjyJaTtQT.

**Owner, 18 Oct 2026, verbatim:** "go. Also fix the records while you're there: mark D-59 as live in the rulebook, and add D-59's table to supabase/schema.sql."

**On production (18 Oct):** main had not moved (5f1161e) and production had not changed since the rolled-back probe (no batch table; same migrations). The migration was applied through the connector as `batch_confirm_2026_10_18b`. Checked there: both function bodies equal the file (md5), security definer, `search_path` empty, execute for anon and authenticated only through the token check; the table has RLS on, no grants to anon or authenticated, 0 policies; 187 functions, 36 tables. The probe, run as it is in the file: **35/35**, failed none, and nothing left behind (0 batches, 0 sample members, 0 sample suppliers). 

**Live:** since 18 Oct 2026, 20:37. Pull request #83 was merged on the owner's "go" (main at 9accbb7), and GitHub reports the site deployed from that commit at 20:37. This session cannot open the live site, so it has not seen the page there.

## D-59 · Record searches, tabs, hikes, the welcome tour and visit length for Recent activity (live since 18 October 2026, 12:50)

**Owner, 18 Oct 2026, 12:43, verbatim:** "i feel like youre not seeing activity. how can it be someone logs in and doesnt click even one thing?" Offered: record these for Eretz Israel Tours' Recent activity only, with a line for the next terms release. **12:44:** "yes".

**Found before it:** only supplier opens, contact taps, filters switched on, saved changes and the last visit time were recorded; not the terms and welcome tour a new member sees first, searches, browsing, the other tabs, hikes, or how long a visit lasts.

**Built (pull request #82, commit 8d132d2, merged by the owner at 12:50 on 18 Oct):**
- Database, add and replace only, `supabase/migrations/2026-10-18_usage_log.sql`, on production since 18 Oct (applied as `usage_log_2026_10_18`): table `usage_log` (RLS on, no grants to anon or authenticated, no policies); `log_usage(p_token, p_kind, p_value)` through `_auth` (kinds search, tab, hike, tour, visit; at most 30 a minute; one visit row whose `last_at` moves on); `activity_feed` replaced with the same rows plus `usage_log`, limit 1500 (800 before).
- Screen: searches once typing stops, tabs, hikes, the tour finished / skipped / left at screen N (not on replay), a beat once a minute while the app is on screen (back after 30 minutes or more is a new visit); Recent activity shows visit length beside the time and lines for searches, hikes, tabs and the tour.

**For the next terms release (G13):** the terms should say the app records searches, pages opened and visit length, seen only by Eretz Israel Tours.

**Records:** first numbered D-52 in the pull request and renumbered before merge (D-52 was the share links). Not written here, in STATUS or README by the session that built it; recorded by the D-60 session on 18 Oct (table and functions added to `supabase/schema.sql`). **19 Oct:** the comment lines inside `log_usage` and `activity_feed` in `supabase/schema.sql` were taken out, because production holds those functions without them; a clean build now equals production in all 187 functions, and `supabase/tests/production_fingerprints.txt` was refreshed to 187 (it still held the 184 of 17 Oct, before D-59 and D-60). Limited-member checks on the clean build: 98 of 98.

**Not checked:** the live calls from a real phone; the building session's tests ran headless on sample data.

## D-58 · Batch confirm: one way and one kind for several prices at once (Eretz Israel Tours only; live since 17 October 2026, 23:41)

**Owner, 17 Oct 2026, verbatim:** "New, my decision: batch confirm. On a supplier's page, add "Confirm prices…" that opens a list of that supplier's price lines with a tick box on each (all unconfirmed ones ticked by default). I choose one "how" (official list / supplier's document or email / paid invoice / conversation) and Tariff or Negotiated once, press "Confirm 12 prices", and every ticked line gets the same mark with today's date. Same rules as single confirm: only Eretz Israel Tours, only I see it, a changed price loses its mark. Show me a quick mock-up first, then build it, and put it live together with the Confirmed Price Mark screen if that isn't live yet."

**Mock-up:** screens 4 and 5 of the Claude artifact "Confirmed Price Mark" (private to the owner), published before the build. The Confirmed Price Mark screen (D-57) was already live since 23:10, so D-58 goes live on its own.

**Built (front end only, no database change):**
- On a supplier's page, beside the Prices heading, Eretz Israel Tours alone sees "✓ Confirm prices…". It shows only once the marks have loaded.
- It opens a sheet listing every price of that supplier: name, Agent tag, current mark and amount, each with a tick box. Unconfirmed prices start ticked; confirmed ones start unticked. There are "Tick all" and "None" buttons and a count ("3 of 4 ticked").
- You choose one way (Official list · Their document or email · Paid invoice · Conversation) and optionally Tariff or Negotiated, then press "Confirm N prices". Nothing is saved until a way is chosen, and the button cannot be pressed with nothing ticked.
- Every ticked price goes through `price_confirm`, the same database call as a single confirm. The rules are therefore unchanged: Eretz Israel Tours only, never seen by members, cleared when the price changes.
- If a price fails, it is named with the reason, and the others keep their new mark.

**Implementation choices (labelled):**
- One call per price rather than a new all-or-nothing database function. This keeps the database untouched; the cost is that a failure part way leaves the earlier prices confirmed, and the sheet says so.
- Ticking an already-confirmed price replaces its mark with the new way and today's date.
- The kind is optional, as in the single sheet.

**Checked (preview, by the building session):** `supabase/tests/confirmed_mark/batch_walk.py` 51/51, `confirmed_mark/preview_walk.py` 63/63, `transport_prices/preview_walk.py` 46/46, 0 page errors. Covered: phone, phone in dark mode and desktop as Eretz Israel Tours; a guide, an agent and an organisation see no button.

**Not checked:**
- A price failing part way: the page's code cannot be reached from the test, and no test-only hook was added to the live page.
- The live site and a real phone.

**Live:** since 17 Oct 2026, 23:41. Pull request #80 was merged (main at 4756bef), and GitHub reports the site deployed from that commit. It went live on the owner's instruction in the same message as the decision. This session cannot open the live site, so it has not seen the page there.

## D-57 · A confirmed mark on each price line, and a read-only door for the Cockpit (database live since 17 October 2026, 22:36; the screen live for Eretz Israel Tours since 23:10; the reader key is not minted)

**Owner, 17 Oct 2026, verbatim** (given to the Cockpit Steward): "1 yes" (approving a one-way connection, supplier app to Cockpit, only on his click: "The cockpit reads Inner Circle prices one way, only when you click, and nothing in Inner Circle ever changes a trip."); "2 OK. But I am inner circle. It's my app." (approving the two supplier-app pieces below). Earlier the same day: "the vendor list in EIT Build is not very good. It doesn't have all the variations, like children, agent prices, seniors, group, all the pricing things that I need, opening, closing, cancellation dates". Order: `IC_ORDER_COCKPIT_READER_S1_S2_2026_10_17.md` (Drive, 5,653 B, SHA-256 597eeccc…829660). Written contract: the draft in `RETURN_SUPPLIER_LINK_DISCOVERY.md` (Cockpit control folder, 27,038 B), §4 and §5. Rules: D-1, F1, F2, F4, D1–D7, E1, E2, E4, G1–G12.

**S1, the confirmed mark (database only):**
- Four new fields on a price line: `confirmed_at`, `confirmed_by` (`Eretz Israel Tours`, or later a member id), `confirmed_how` (`official_list`, `supplier_document`, `paid_invoice`, `supplier_conversation`), `kind` (`tariff`, `negotiated`).
- Every existing line starts unconfirmed. Only `price_confirm(p_token, p_id, p_how, p_kind)` can set the mark, and only Eretz Israel Tours may call it (G2). A trigger (`_price_mark_guard`) throws away a mark written any other way: an insert, an import, a load, an ordinary save or plain SQL. A website or an import is not one of the four ways and is refused (E1, E2).
- Changing the amount, currency, VAT, basis, who it is for, ages, group size, agent or public, or season clears the confirmation (the kind stays). A new label, note or source keeps it.
- The "✓ Verified" text at the start of a source (D-44) stays as it is and is not read as confirmed.
- Only Eretz Israel Tours sees the mark: `price_marks(p_token, p_vendor)` (admin only) gives the marks on one supplier's lines. `vendor_detail` is unchanged, so no member, Eretz Israel Tours included, gets the fields through it.
- **The screen (built, not live):** the owner approved the mock-up ("looks great — build that screen, for Eretz Israel Tours only, and show me before it goes live", 17 Oct). On a supplier's page, Eretz Israel Tours (only) sees under each price "✓ Confirmed · how · date · kind" or "Estimate · not confirmed yet", in the price list and on every row of a bus or van company's board. Tapping a price shows "Confirm this price" (or "Change the mark"), which opens a sheet: the four ways, Tariff or Negotiated, a note that a website, an import or a colleague's list does not count, "Confirm · today dd/mm/yyyy", Back, and on a confirmed price "Take the mark off". The marks are read with `price_marks` when the page opens, so a member never receives them; if that read fails, no mark is shown rather than a wrong one. The Quotes tab shows no mark. Colleagues and organisations see the page exactly as before. In the preview, sample marks are on the sample jeep company and the sample bus company.

**S2, the read-only door (database only):**
- `cockpit_supplier_prices(p_token text, p_supplier_id text)` returns the supplier (id, name, category, also_categories, region, parent_id, status, archived_at, merged_into, prices_private, hours, hours_last, hours_source, hours_verified_at, hours_verified_how, reservation, cancellation terms), its lines, a `behaviour` sentence and `read_at`. Each line: id, label, audience, age_from, age_to, pax_min, pax_max, basis, per_job, transport, is_agent, price, currency, vat, vat_stated, season, source, checked_on, loaded (the load label, never an email), confirmed, confirmed_at, confirmed_by, confirmed_how, kind, private, eit_own, archived, archived_at, updated_at. No contact details of the supplier or of any member, and no `note`, `created_by` or `owner`.
- Which lines: Eretz Israel Tours' own (no owner, or owned by an Eretz Israel Tours member), private ones and lines on private-price suppliers included; another member's line only when it is a shared organisation rate on a supplier whose prices are not private. Never another member's personal or private line (D1, D4).
- `cockpit_supplier_search(p_token text, p_text text)` returns id, name, category, region and status (`approved`, `hidden`, `pending`, `rejected`, `archived`) only; exact name first, then names starting with the text, then names containing it; at most 25; fewer than 2 characters gives nothing; a supplier id finds that supplier.
- **The credential:** one reader key in its own table `cockpit_readers` (only its hash), checked by `_reader_auth`. It is not a member, so it opens no other function, and no member link (Eretz Israel Tours' included) opens the two reader functions. At most one key is active. Minted and revoked only in the Supabase SQL editor: `select public._cockpit_reader_mint('Cockpit');` shows the key once; `select public._cockpit_reader_revoke();` shuts it out at once. Neither can be called from outside (anon, authenticated and service_role are refused). **Not minted.** The owner mints it when the Cockpit's first slice is ready. No administrator key is ever given to the Cockpit.
- **Delete and merge:** the first time the reader returns a supplier, a read note is left (`cockpit_reads`). From then on, deleting that supplier or any of its lines, by any route (the app's delete buttons, an approved removal request, or SQL), archives it instead: `archived_at` is set (and the supplier is hidden); nothing is cascaded; the reader returns it marked archived. The app leaves archived lines and suppliers out (`_price_visible`, `vendors_list`, `transport_prices`). A supplier the reader never read is deleted as before. Merges are done by hand (D5): set `merged_into` on the old supplier to the id it was merged into, then delete it; if the Cockpit has read it, it is archived with that pointer.
- Tables 32 → 34 (`cockpit_readers`, `cockpit_reads`), functions 172 → 184; still 0 table grants and 0 policies; every new function has its own revoke from public.

**Implementation choices (labelled, not owner rules):** the reader key is a table of its own rather than a member, so it can call nothing else; a read note is the way "used by the Cockpit" is known (the only write the reader makes, never to supplier data); `per_job` is true on Transport, Guide and rental suppliers and on per-vehicle, per-guide, vehicle and transport-detail lines; `confirmed_by` is set to `Eretz Israel Tours` while only Eretz Israel Tours may confirm; the kind stays when a price changes; label, note and `created_by` emails are not sent to the Cockpit; season stays free text (there are no valid-from/to fields).

**Checked (on a local copy built from the record, by the building session only):** the migration runs twice cleanly; a fresh build from `supabase/schema.sql` equals the migrated copy in every function, column, constraint, trigger, privilege and index (1,005 lines); before the change all 172 functions on production equal the record; `supabase/tests/cockpit_reader/production_probe.sql` 75 checks, 0 failed; `supabase/tests/limited_members/run.sh` 98, 0 failed; the claims, transport and limited-members production probes run unchanged.

**On production (the owner, 17 Oct: "go — put the database part of D-57 on production now, then run the production check"):** applied 17 Oct 2026 at 22:36 Israel time (connector migration `cockpit_reader_2026_10_17`). Before: production equal to the record (172 functions, unchanged since the first read). After: 34 tables, 184 functions, 0 table grants, 0 policies, every table with row security; all 184 function fingerprints equal the tested copy (`supabase/tests/cockpit_reader/expected_fingerprints.txt`; `production_fingerprints.txt` updated). `production_probe.sql` on production: 75 checks, 0 failed (an ordinary member, an organisation and Eretz Israel Tours' own link are refused by the reader; with a sample key, another member's private line is not returned and Eretz Israel Tours' private line is). Afterwards: 0 reader keys, 0 read notes, no sample rows left; 331 suppliers, 903 price lines, 33 members, as before. On production the internal helpers can be run by `service_role` (Supabase's default there, as for the older helpers); the mint and revoke functions are refused to it explicitly.

**Screen checked:** `supabase/tests/confirmed_mark/preview_walk.py` 63 checks, 0 failed, 0 page errors (phone, phone dark and desktop as Eretz Israel Tours; a guide, an agent and an organisation see no mark and no button); `supabase/tests/transport_prices/preview_walk.py` 46/46. Two older walks fail the same way on `main` without this change: `price_rows/preview_walk.py` (3 of 18; it predates D-51's paired rows) and `back_button/back_walk.py` (calls `bkTest`, no longer in the page).

**Not checked:** a real Cockpit calling the door; the screen on the live site or a real phone (preview only).

**Live:** the database part since 17 Oct 2026, 22:36, on the owner's word; nothing anyone sees changed (no key, no screen). The screen went live on the owner's word, 17 Oct: "go — put the Confirmed Price Mark screen live (Eretz Israel Tours only)." Before merging: branch 0 behind `main`, production unchanged (184 fingerprints), limited-member checks 98/98, preview walks 63/63 and 46/46. Pull request #78 merged (main at 61c34c5); GitHub reports the site deployed from that commit at 23:10 Israel time. Not seen after go-live: the page the live site serves (this session cannot reach the site) and a real phone. The reader key: the owner, 17 Oct: "Do NOT make the Cockpit key. I will make it tomorrow with the Steward's help."

## D-56 · Mapeak's map, with the hike's route, on each hike's page (live since 16 October 2026)

**Asked for:** Mapeak (Zeev), 16 October 2026: "Please also use that link for the embedded map <iframe src='https://mapeak.com/url/...' width='800' height='500' frameborder='5' scrolling='no'/>. I believe that for this to work, the URLs must be visible to our server." The owner (Eretz Israel Tours) passed the message on, asking for it to be built. Who can see a route is already settled by D-53 (15 Oct 2026: "Honestly I don't care if people on mapeak can see routes").

**What changes from D-53 and D-37:** D-37 and D-53 said nothing of Mapeak's is shown in the app. Mapeak now asks for its map to be shown, so this opens that: Mapeak's own page, in a frame, on the hike's page. No Mapeak route is taken and nothing of Mapeak's is stored.

**Built (trial):**
- On the hike's page, for an approved hike with a route file (the same hikes that get the D-53 route button), a "Mapeak map" section directly under the route file box: Mapeak's page in a frame at the same address the button opens (`mapeak.com/url/` + our public route address, every "/" written as %2F). Full width, about 420 high on a phone (60% of the screen, at most 460), no border, loaded lazily, no referrer sent, titled "Route on Mapeak". Under it: "Map © Mapeak · Opens the route from this hike's file." and "Open full screen in Mapeak ↗" (new tab, same address).
- The code is asked for (`hike_route_link`, unchanged) only when the section comes near the screen, so a member who never scrolls there makes no code and loads none of Mapeak; then kept per hike until the page is loaded again. While it comes: "Loading the Mapeak map…". If it cannot be had: "The Mapeak map could not load. Try again later." with Try again. The frame's address is only ever `hkMapeakRoute(code)`, and only for a code of 20 to 64 letters, digits, "-" or "_".
- Sample mode shows a dashed sample box ("Sample hike. In the app, Mapeak's map with this hike's route shows here.") and asks nothing of anyone.
- The open map's "Open in Mapeak" already opens the route for an approved hike with a route file (D-53, live since 16 Oct); kept, and checked again. Others keep the place link.
- The Leaflet map, marked trails, "Where am I" and the route file box are unchanged. No database or edge function change.

**Implementation choices (labelled, not owner rules):** no sandbox on the frame (Mapeak is a full app and was not tried with one) and no allow list (so Mapeak's "where am I" inside the frame is not offered); the link carries `noopener noreferrer`, like the app's other outside links; the frame starts loading when the section is about 300 pixels from the screen.

**What Mapeak's side shows:** Mapeak's own source (github.com/IsraelHikingMap/Site) has a deliberate frame mode (`RunningContextService.isIFrame`: a plain toolbar with the Mapeak mark, no start-up dialogs, links open in a new tab). No X-Frame-Options or frame-ancestors setting was found in that source; the headers mapeak.com actually sends could not be read (the sandbox cannot reach mapeak.com, and the fetch tool does not show headers and is refused on `/url/` by Mapeak's robots rules). Mapeak's server, asked through `mapeak.com/api/files?url=` for one existing route address on 16 Oct, answered with the route parsed (one route, four parts, 111 points).

**Checked:** `hike_page_walk.py` 133 checks (118 before, 15 new for D-56, on a 380 wide phone with a stand-in for Mapeak); `supabase/tests/hikes/preview_walk.py` 204.

**Not checked:** Mapeak's real page inside the frame (on a real phone or any browser); whether a finger on the frame scrolls the page or moves the map on a real phone; Safari and Firefox.

**Live:** not yet. The owner's word is needed (G1).

## D-54 · Transport prices with their details, and the Quotes tab fed from them (live since 16 October 2026, 10:38)

**Owner, 16 Oct 2026, 09:27:** "Pricing for transportation needs a more detailed input area and it should copy to a more detailed quotes page. Options should be vehicle size - transfer to and from airport to and from city options. Luggage? Vehicle size? Time of day/night. What was paid. Vat? Anything I'm forgetting? And then that should automatically write to quote page. I'm thinking quote page should have same layout. Also layout of quote page should be like landing page with vehicle size, transfer, full day, and anything else that may be relevant. The transportation page ex Manny Weiss should have clearer pricing input areas and data fields. Start now."

**Built (pull request #70, branch `transport-prices`):**
- The price form on a Transport supplier asks: what the price is for (airport pickup Ben Gurion → city, drop-off city → Ben Gurion, either way at one price, a transfer between two places, a full day, a half day, by the hour, something else); the city or from–to; vehicle size (or "not stated"); passengers; luggage (with luggage / hand luggage only / none, and suitcases); time of day (daytime, night, Shabbat or holiday, any time) and a night or Shabbat extra; the date of the job; price, currency, VAT, agent or public; quoted, what was paid, or price list; for a day: hours and km included, each extra hour and km; for a transfer: free waiting time; Kvish 6 included or extra; the driver's tip; source, date and note.
- The supplier page and the Quotes tab show one board: a tab per kind of job (airport transfers, other transfers, full day, half day, by the hour, other) with its count and lowest price, vehicle sizes as chips, a city picker, lowest / average / highest of what is shown, and one row per price that opens on a tap. In the Quotes tab ("Prices & quotes") every transport price line shows at once, beside the vehicle quotes from the quote tracker.
- Database, on production 16 Oct (add only): `vendor_prices.transport` (jsonb), `_transport_clean`, `transport_prices(p_token)`; `_price_clean`, `_price_write` and `vendor_detail` carry the column. A save from an older copy of the page keeps a line's details. Same visibility as the supplier's page: an organisation never receives an agent line (C3), no colleague's name is sent.

**Implementation choices (labelled, not owner rules):** the details live beside the line, and the line's label is still written the D-29 way so older lines and older copies of the page keep working; quotes stay in their own table and show on the board as "Quote" rows, not copied into prices; the lowest / average / highest leave out organisation rates for guides and agents.

**Data, same day (owner: "I put pricing in notes for Manny. Redo page and quotes with that data"):** three agent price lines on Manny Weiss from his last quote of 7 Oct 2026 — Ben Gurion → Jerusalem, 12 passengers with luggage, 800 ILS; Ben Gurion → Jerusalem, 3 passengers with luggage, 400 ILS; Jerusalem → Ben Gurion, 15 passengers with luggage, 1,000 ILS. Marked quoted; VAT and vehicle size not stated in the quote, so left unknown. The note text on his page is left as it was.

**Live:** the owner, 10:36: "Go live". Pull request #70 merged (main at 08ddbd0), deployed at 10:38; /next-transport/ now sends on to the app.

**Numbering:** taken as D-53 at first; D-53 had gone to the Mapeak route link (pull request #68) earlier the same morning, so renumbered D-54 before anything was recorded.

## D-53 · "Open in Mapeak" opens the hike's own route (production database and edge function live; the page is a trial copy at /next/, 16 October 2026)

**Decided by:** the owner (Eretz Israel Tours). 15 October 2026, 23:31: "Honestly I don't care if people on mapeak can see routes". 16 October 2026, 09:13, offered "Make 'Open in Mapeak' open the actual hike": "Do first now".

**What D-37 had left open:** Mapeak opens a route from a web address, but the route file would have to be fetchable by anyone holding that address. The owner has now said that is fine.

**How Mapeak does it (read in its source, github.com/IsraelHikingMap/Site, 16 Oct 2026):** the address `https://mapeak.com/url/<file address>` is read by Mapeak's router as one part (`RouteStrings.URL`, `hash.service.ts`), so the file address must be encoded as one part (`encodeURIComponent`). The page then asks Mapeak's own server, `GET /api/files?url=<file address>` (`file.service.ts` `openFromUrl`, `FilesController.GetRemoteFile`), and that server fetches the file itself (`RemoteFileFetcherGateway`), with no headers of ours, and takes the format from the file name in `Content-Disposition` or from the end of the address. So the file must be reachable by anyone with no key or link, and it ends in `.gpx`. The address must not hold `&` (Mapeak does not encode it again); ours holds none.

**What is built:**

- **A code per route file.** `hike_gpx.link_code`: 32 random characters (24 random bytes, about 192 bits), letters of a web address only. Kept on the route file's row, not on the hike, because the link is to that file and the row's own "removed" mark is what turns it off. Made the first time a member asks, the same for everyone after.
- **`hike_route_link(token, hike)`**: the same checks as `hike_gpx` (the link is good, Hikes are open to him, he can see the hike), and the hike must be approved and have a route file that is not removed. Gives the code.
- **The edge function `route`** (no key needed): `https://wjuqtjlrtcywjaspjpwu.supabase.co/functions/v1/route/<code>.gpx`. It asks the database (`_hike_route_public`, callable with the service key only) for the GPX of that code, only while the file is not removed and the hike is approved, and sends that GPX and nothing else; anything else is "Not found". The stored GPX holds points, heights and the names of marked spots only (`hkCleanGpx`, `_hike_gpx_put`); the function cuts out anything personal a GPX file can hold, as a second guard.
- **Replaced, removed:** a replaced route file keeps its code (its row is updated in place), so a link handed out earlier shows the new route. A removed route file, or a hike taken off the list, stops the link at once; put back, the same code works again.
- **The page.** "Open in Mapeak" on the open map, and beside "Open or save the route file" on the hike's page, with the line "Opens the route in Mapeak. Anyone with that link can see the route." The tap opens a blank window at once (a phone allows a new window only on the tap), then sends it to Mapeak with the route. If the code cannot be had, Mapeak opens at the place as before, with a message. A hike with no route file, or one that waits for approval, keeps the old place link. Sample mode opens Mapeak at the place and says that a sample hike has no route address.

**Not done, on purpose:** Mapeak's map is not shown in the app and no Mapeak route is taken (no permission for that; D-37).

**Who sees what, new to the outside:** anyone holding a hike's Mapeak address can fetch that hike's route (points and heights; no names of members, no hike name, no notes). Mapeak's server fetches it, and Mapeak may keep or show it: the owner's stated choice. The privacy line still to be written (D-36, D-37) should name this too.

**Checked:** `supabase/tests/route_link/run.sh` 49 checks (local Postgres 16; the schema record and the migration build the same database); `supabase/tests/route_link/production_probe.sql` on production, rolled back, every value as expected; on production the function line equals the tested build (170 functions). Over the internet, from the database server, with no headers: a code on one of the owner's approved hikes gave its GPX (`application/gpx+xml`, `Content-Disposition: inline; filename="route.gpx"`, `Access-Control-Allow-Origin: *`), byte for byte the stored route after the XML opening line; a wrong code and a short one gave 404. Mapeak's own server, asked through `mapeak.com/api/files?url=` with that address, answered with the route as one route of four parts. `hike_page_walk.py` 118, `preview_walk.py` 204.

**A second agent read the change for leaks.** It found nothing beyond one hike's GPX reachable, codes not guessable (192 bits, the same 404 for every failure), no grant, injection or search-path fault. Fixed on its word: the blank window no longer waits for ever (after 12 seconds Mapeak opens at the place), and sample mode guards a missing hike. Left as they are, for the owner to change if he wants: a code never changes (a leaked link works while the route is on an approved hike; removing the route stops it, putting it back revives it); links keep working if Hikes is closed to colleagues again; the names of marked spots in a route are sent (none of the routes on production has any).

**Not checked:** a real phone tapping the button and Mapeak drawing the route on its map (the sandbox cannot open mapeak.com in a browser); Safari and Firefox.

---

## D-43 · Wineries under Restaurant and under Attraction / Site (live for Eretz Israel Tours since 12 October 2026; switched off for colleagues)

**Decided by:** the owner (Eretz Israel Tours), 12 October 2026. 09:30: "move winery and put it under sites." 10:21, of the mock-up: "Looks good. But put wineries under restaurants and under sites".

- **What it does:** the Winery button leaves the top row of categories. Restaurant and Attraction / Site each get a second row (as D-20 does for Extreme) with a **Wineries** button: the suppliers whose category is Winery. Restaurant alone, or Attraction / Site alone, includes the wineries; with the second row narrowed, a winery shows when Wineries is one of the buttons picked. A winery is one supplier, so it is listed once even with both buttons on. Choosing "Winery" from the search suggestions opens Wineries under one of the two.
- **No supplier changes:** the stored category stays `Winery` on all 19. The supplier form still offers Winery; the winery type tags stay. The Builder's Cockpit is not touched (rule F4 still maps wineries to Restaurant for any future Cockpit copy).
- **Organisations (limited members):** a winery is visible to an organisation that sees **either** the restaurants section (`food`, as before) or the sites section. No organisation loses a winery it sees today. On 12 October no approved organisation sees sites without restaurants (there are no approved organisations), so none gains wineries yet. Both section descriptions name wineries once the switch is on.
- **Opens to Eretz Israel Tours first (G2):** setting `wineries_for` (`admin` by default, `all` for everyone), switched in the Team tab ("Put wineries under Restaurant and Attraction / Site for all colleagues"). While it is `admin`, colleagues keep the Winery button and organisations see wineries with restaurants only, exactly as before.
- **Implementation choices, his to change:** the Restaurant row also has Meat, Dairy and Mehadrin (from the approved mock-up; each shows only when a restaurant carries that type tag); the "All" button of the two rows reads "All restaurants" and "All sites"; the feature has its own switch, separate from rentals.
- **Database:** `supabase/migrations/2026-10-12b_wineries_under_sites.sql` (adds `_wineries_on`; replaces `_can_see`, `set_setting`, `whoami`). Run on production through the connector on 12 October 2026.

## D-42 · Eshkol / Midbari rentals, their own category (live for Eretz Israel Tours since 12 October 2026; switched off for colleagues)

**Decided by:** the owner (Eretz Israel Tours), 12 October 2026. 09:15: "Add a category for eshkol/Midbari rental, with category of cost, milage, over mileage cost, year make Of car, location, passenger seats, other terms of rental, color of car with availability calender, notes for. Renter notes for review". Who marks the calendar: "Members only". 09:30: "put it as its own category". 10:21, of the mock-up (Claude artifact "Eshkol and Midbari Rentals", version 4): "Looks good." About 12:45, of the preview pictures: "Looks great" (G1); the page went live the same afternoon, for Eretz Israel Tours only.

- **The category:** stored value `Vehicle Rental`, shown on buttons, in the form and on pages as **"Eshkol / Midbari rental"**. For organisations it belongs to Transportation (`_section_of('Vehicle Rental')` = `transport`). A rental company is one supplier in this category; a supplier that also offers Vehicle Rental counts too.
- **Vehicles** (table `rental_vehicles`), one row each under the company: licence type (Eshkol, Midbari or both), make and model, year, colour, passenger seats, pick-up location, cost per day with currency and VAT, km included per day, cost per extra km, where the price is from and the date it was checked (rule E4: a price is refused without both), agent price or not, other terms, notes for the renter. Archived, never removed. Eretz Israel Tours changes any vehicle; a member changes the ones he added and may archive them; only Eretz Israel Tours brings one back.
- **Calendar** (table `rental_days`): any approved member who can see the vehicle taps a day to cycle it free, booked, not known. A day holds only its state, who set it and when: no client, trip or note (D6, D-30). The vehicle's page shows who changed the calendar last and when, by name only (D1). Days from last month to two years ahead.
- **Reviews:** the review system in force (D-14, E9 unchanged). `vendor_notes` gains an optional `vehicle_id`; `rental_review_post` is `review_post` with the vehicle named. The vehicle's page lists the reviews that name it; the supplier's page says which vehicle a review is about.
- **Who sees what:** a supplier that is hidden or waiting for review shows no vehicles to colleagues. An organisation never receives an agent day price (C3): on an agent vehicle the day price, the extra-km price and their source and date are left out and the page says "Ask for rate"; an organisation cannot mark a vehicle agent. A private-price supplier sends no vehicle price to colleagues (D4). Full members see agent day prices (C5). An organisation reads guides' and agents' reviews of a rental company under its general reviews switch (`see_reviews`), not the transport one: the stricter reading, his to change.
- **Opens to Eretz Israel Tours first (G2):** setting `rentals_for` (`admin` by default, `all` for everyone), switched in the Team tab ("Open Eshkol / Midbari rentals to all colleagues"). While it is `admin`, a supplier whose category is Vehicle Rental is hidden from every colleague, and no colleague receives a vehicle.
- **Screens** (the approved mock-up): the category button; on the list, each vehicle with licence, car, seats, tomorrow's state and price per day; the company's page with "Vehicles for rent" and "+ Add a vehicle"; the vehicle's page (car, seats, pick-up, cost, km, extra km, VAT, source and date, other terms, month calendar, notes for the renter, reviews, Write a review); the Add a vehicle form. The phone's Back button on a vehicle returns to its company (D-41).
- **Implementation choices, his to change:** a vehicle added by a colleague shows at once, with his name, without approval (like a calendar mark); "not known" is stored as a day set back, so the last change is still shown; the R5 export sends Vehicle Rental as Other; the existing Transport supplier that rents out Eshkol and Midbari vehicles is not moved into the new category: that is his word to give.
- **Database:** `supabase/migrations/2026-10-12_rentals.sql` (two tables, one column, twelve functions; replaces `_section_of`, `_can_see`, `set_setting`, `whoami`), run on production through the connector on 12 October 2026. **`supabase/migrations/2026-10-12c_vehicle_rental_category.sql` is for the owner to run himself in the Supabase SQL editor (G5: it swaps the list of categories, taking the old one off).** Until he does, the database refuses a supplier whose category is Vehicle Rental; everything else works.

---

## D-41 · The Back button never leaves the app (live since 11 October 2026)

**Decided by:** the owner (Eretz Israel Tours), 11 October 2026. 09:01: "Change it so back button doesn't leave app". 09:53, after trying it: "back should never leave the app". 09:54: "hes it works on the trial 2".

- **What it does:** the phone's or the browser's Back button closes what is open, one thing at a time: a box on top (with its own Cancel or Close), the full-screen map, the open sheet (the sheet's own Back, Cancel or Close if it has one, otherwise its ×), a step of the welcome tour. With nothing open on another tab it returns to Suppliers. With nothing open on Suppliers it does nothing. A member leaves with the phone's Home button or by closing the tab.
- **Implementation choices, his to change:** that Back from any tab goes to Suppliers and not to the tab before; that Back on a form does what its Cancel does, which drops what was typed, as Cancel does today; that Back with nothing open shows no message.
- **How, two ways used together:** (1) the page keeps a few spare entries of its own in the browser's history (same address, a counter in each entry) and listens for Back landing on one; Chrome skips entries a page added without a tap, so on its own this misses a Back pressed before the first tap. (2) On an Android phone the page also keeps a CloseWatcher open, which Chrome reaches before history, tap or no tap, and opens the next one after each press. Front end only, `index.html`; no database change; it reads and changes no address, link or member data. The two places that tidy the address (a personal link, a job link) keep the page's counter on the history entry.
- **How it got here:** the first trial copy at /next/ had only way (1) and said "Press Back again to leave", a second press leaving. The owner, 09:43: "back nutton minimizes app now". Way (2) went into a second trial copy at about 09:50; he tried it on his phone and said it works. The message and the second press that left were then taken out on his word. That last form, where Back does nothing at the list, went live without a trial of its own: it is the trial he tried with the leaving removed.
- **Checked in preview:** `supabase/tests/back_button/back_walk.py`, 41 checks at phone and desktop size, through the welcome tour and as an Android phone (Back before any tap, nine presses in a row with nothing tapped, three presses that close a map, a hike and the tab, a keyboard's Esc), 0 failed; the hikes walk 204 and the hike page walk 106, 0 failed. As an Android phone, Back is the watcher's own close request made from the test, not a real Back button.
- **Checked on the trial copies in the owner's Chrome on his computer, on the real list, with the browser's own Back:** Back closed a supplier's page; from an open hike on the Hikes tab, presses with nothing touched in between closed the hike and returned to Suppliers.
- **Not checked:** the never-leave form on a phone; the app installed on a phone's home screen; Safari and Firefox.
- **Known edges:** on a computer, where only way (1) works, a Back pressed before the first tap, or about three in a row with nothing tapped in between, can still leave the page; that is Chrome's own rule. On a computer Back no longer returns to the website the member came from. After the page is reloaded, a Back press can reload it once.

## D-40 · A Modiin region (live since 11 October 2026)

On the owner's word (11 Oct, 08:59: "Add modiin as region for activities").

- **What changed:** one name added to the page's list of regions, `Modiin`, between Tel Aviv & Center and Shfela. It is offered wherever a region is chosen (a supplier's form, a hike's form, a job, where a member is based) and shows as a region filter once something is filed under it.
- **Implementation choices, his to change:** its place in the list; that the one shared list is used, so a hike can be filed under Modiin too, although he asked for it for activities.
- **Nothing in the database changed shape:** a region is plain text there.
- **Moved into it:** nothing at first. At 09:53 the owner said to move the two suppliers that are in Modiin ("yes move those two HaSadna and Lin Bee Farm to modiin"); their region went from Tel Aviv & Center to Modiin on the live database. Both are still hidden and waiting for review.
- **Checked:** in preview at phone and desktop size, the supplier's form offers Modiin with every other region still there, and a sample supplier saved under it gets a Modiin filter button that shows only that supplier (12 checks); the two hikes walks (204 and 106 checks) pass with the new list.

## D-39 · Hikes get a region of their own: Dead Sea (live since 11 October 2026)

On the owner's word (11 Oct, 08:55: "Also create a dead sea region for hikes").

- **What changed:** hikes can be filed under `Dead Sea`. It sits just before Dead Sea & Judean Desert in the hike's form and in the order of the hikes list. Suppliers are untouched: their list of regions has no Dead Sea, and suppliers by the Dead Sea stay under Dead Sea & Judean Desert.
- **The place picker still works:** a hike filed under Dead Sea is offered the places of Dead Sea & Judean Desert first (`hkVReg`).
- **Nothing in the database changed shape:** a region is plain text there.
- **Moved into it:** the ten hikes on the Dead Sea shore itself (Ein Gedi four, Masada two, Ein Bokek two, Nahal Perazim, Lower Nahal Darga). Left under Dead Sea & Judean Desert, for Eretz Israel Tours to place: Wadi Qelt, Lower Nahal Og, Upper Nahal Og, Middle Nahal Tzafit.
- **Checked:** the hikes walk has two new checks at each screen size (204 in all), the hike page walk 106; none failed.

## D-38 · A Jordan Valley region (live since 11 October 2026)

On the owner's word (11 Oct, 08:43: "Create a Jordan valley region"), after his walk at Nahal Firan had to be filed under Binyamin & Shomron for want of a better place.

- **What changed:** one name added to the page's list of regions, `Jordan Valley`, between Binyamin & Shomron and Dead Sea & Judean Desert. It appears wherever a region is chosen: a supplier's form, a hike's form, a job, where a member is based; and in the region filters once something is filed under it.
- **Nothing in the database changed shape:** the database keeps a region as plain text and has no list of its own.
- **Moved into it:** the hike "Nahal Firan (Jordan Valley)" only. Suppliers and other hikes stay where they are until Eretz Israel Tours moves them.
- **Checked:** the two hikes walks (200 and 106 checks) pass with the new list.

## D-37 · The hike's map: marked trails drawn over it, a link to Mapeak; the route file box names the apps (live since 10 October 2026)

**Decided by:** the owner (Eretz Israel Tours), 10 October 2026, evening.

**In his words:** 20:17, "israel hiking map is now called mapeak. does that change anything? ... it even ha public hikes listed on it. can we use those and integrate mapeak into app?" 20:23, "lets try all of them and see whoich works best. i just sent the email.." 20:50, after trying the trial copy: "Open map showed the hike. Open in mapeak. Showed map but not hike. Yes 18202 how did you find that?" 20:55: "Marked trail layers are fine. The open map function is fine too. What if someone downloads the gpx can they get a pop up. Saying open in and chooses mapeak or amud Anan?"

**What was found about Mapeak (its own pages, read 10 October):** the same licence under the new name ("Tiles © Mapeak under CC BY-NC-SA 3.0"), a paid Pro subscription, terms that give no permission to show its map or copy its content elsewhere, and public routes that come from OpenStreetMap's trail records and from partners (Nakeb, KKL) by their permission. So Mapeak's map and its public routes are not taken into the app without Mapeak's written yes. The owner sent the request to support@mapeak.com on 10 October; no answer yet.

**What is live:**

- **Marked trails over the map.** Waymarked Trails' picture of the marked trails OpenStreetMap holds, laid over the hike's map on the page and on the open map, with the Israeli colour marks. A button on the open map takes it off and puts it back. Its terms, read on its own site: use on other sites is allowed at a moderate rate, with OpenStreetMap and Waymarked Trails named; both are credited on the map. The app takes and keeps no trail data.
- **"Open in Mapeak"** on the open map: a plain link to Mapeak's own map at the start of the hike. It shows the place, not the hike; nothing of the hike is handed to Mapeak.
- **The route file box.** On Android the phone itself asks which app opens a saved route file, and only after the file is tapped; the page cannot raise that question. The box now says so step by step, names Mapeak and Amud Anan, says that Mapeak is the new name of Israel Hiking Map, and after saving says what to tap next. This last part answers his question of 20:55 and went live with the rest; it is his to send back.

**Tried and not built:**

- **Reading a walk's trail colour from OpenStreetMap.** Around his walk from Har Gamal the records hold green 18202, red 18201, black 18240 and others; 29 of 30 points of his recording lie within 35 m of green 18202, and he confirmed it ("Yes 18202"), so that mark is now on his hike. The public look-up service answered one time in three and took seven seconds: fit for a look-up when a route is added, not for every phone.
- **Showing the hike itself in Mapeak.** Mapeak opens a route from a web address (`mapeak.com/url/` and the address of the file; seen to ask its own server for a sample file). That would need the hike's route to be fetchable for a short time by anyone holding the address, and hands the route to Mapeak: who sees what, the owner's. He asked about the saved file instead, which needs none of that.

**Who sees what:** unchanged inside the app. New to the outside: a phone showing a hike's map now also asks `tile.waymarkedtrails.org` for pictures of that area. It joins the privacy line still to be written for OpenStreetMap (terms, the week's release).

**Checked:** `hike_page_walk.py` 106 checks, `preview_walk.py` 200. On the trial copy in the owner's Chrome: the trails drew over his walk with their colour marks. On his phone, by his word: the open map showed the hike and Mapeak opened at the place.

**Not checked:** the reworded route file box on a phone.

---

## D-36 · Hikes open to every colleague; a box that says how to allow location (live since 8 October 2026)

**Decided by:** the owner (Eretz Israel Tours), 8 October 2026, 23:45 Israel time.

**In his words:** "So have a pop-up tell g them what to do and make the hikes live fore everyone. And can we add more hikes?" Sent after a picture from his phone of the open map on Ein Ovdat with the message "Your phone did not give its place. Allow location for this site, then try again."

**What that picture settled:** "Where am I" failed on his phone because Chrome there had not been allowed to use location for the site. The app was not at fault, but its message vanished after a few seconds and did not say where to allow it.

**What is done:**

- **The box** (`hkWhereHelp`). When the phone or browser refuses, a box stays on screen with the steps for that kind of device: Chrome on Android (and what to do when Location is not listed), an installed copy on Android, an iPhone, a computer. "Try again" asks the phone again. It says the member's place is drawn on his own screen and sent nowhere. Front end only.
- **Hikes are open to every approved member**: the setting `hikes_for` is `all`, set in the database the way the Team tab's own switch sets it. Colleagues and organisations now see the Hikes tab, the 33 hikes, and can add hikes (each waits for Eretz Israel Tours' approval) and reports. The switch on the Team tab turns it back.

**Opened on the owner's word with two things still open, both terms changes for the week's release (G13), neither yet written into the terms:**

- a line in the privacy notice that a hike's map is fetched from OpenStreetMap's server, which sees the phone's internet address and the area looked at;
- the no-responsibility line for hikes, which is also on the lawyer's list. The hike's page carries its own notice meanwhile.

**Checked:** `hike_page_walk.py` 97 checks (the box for Android, iPhone, computer, at 320 wide; "Try again", Escape, closing the map; no watch left running); `preview_walk.py` 200. After the setting: every approved member counted as seeing Hikes.

**Not checked:** the box on a real phone; whether the installed copy's "Site settings" step is worded as Samsung phones word it.

**The box rewritten, 9 October 2026, about 14:40, on the owner's word ("Rewrite in app how to fix location").** The first box sent him to the page of this one site, where there was no Location to switch: a site that was never asked is not listed there, and he uses the copy on his home screen, which has no Chrome menu. What worked on his phone was switching location on for Chrome as a whole. The box now gives the two switches that decide it on Android, in order: Chrome's own (Chrome, three dots, Settings, Site settings, Location), then the phone's permission for Chrome (Settings, Apps, Chrome, Permissions, Location), then "Try again". On the home-screen copy it says to open Chrome itself. It adds that switching these on only lets a site ask. It opens at its first line. iPhone and computer steps are unchanged. Which of the two switches was off on his phone is not known; he did not say. Checked: `hike_page_walk.py` 102 checks. Not seen: on a phone.

**"Can we add more hikes?":** yes. A second list is being put together for him to choose from, as the first was.

---

## D-35 · The hike's page: a real map with the route on it (live since 8 October 2026)

**Live since 8 October 2026, about 22:40, on the owner's word.** He tried the trial copy on his phone and wrote at 22:35: "Open map works full screen 2 where am I doesn't work file saves ask Israel hiking map Route saved. Make it live no one uses the app anyway". So, on his Android phone: the map opens full screen; the saved route file was taken by Israel Hiking Map (as this session reads his words); "Where am I" did not work. Why it did not is not known: he did not say what the phone showed. The likeliest cause was the app's own doing: he was far from the hike, and the first version then refused to show him at all. That is changed before go-live: his place always comes onto the map, the map widens to hold him and the hike, and it says how many kilometres away he is. If the cause was the phone not giving its place, the page says so and how to allow it. Pull request #31 merged (main 7fdb20c); front end only; D-34 went live with it. Seen on the live app a few minutes later, in the owner's Chrome on his computer: his hike Ein Ovdat opens with the real map, the route on it, Start and End, and the credit. The trial copy at `/next/` now only sends on to the app (pull request #34). Not seen since go-live: a phone.

**Decided by:** the owner (Eretz Israel Tours), 8 October 2026, 20:45 Israel time, after trying the trial copy of D-34 on his phone.

**In his words:** "The route on the page: new, so you can see the walk without any other app. It is a line drawing, not a map. It's a line not on any map... It's useless. The Google map start and end doesn't help either because it just opens Google maps. And you can't see both at once. Why can't you integrate open maps? Honestly I couldn't. Really tell the difference in old and new"

**What is built** (branch `hike-page-fixes`, on top of D-34; front end only, no database change):

- **A map leads the hike's page.** OpenStreetMap, with the recorded route drawn on it as a line and start and end marked together. It stays still on the page so the page scrolls under a finger. "Open the map", or a tap on the map, opens it over the whole screen: it moves and zooms, start and end each offer Waze and Google Maps to that exact point, and "Where am I" shows the member's own place against the route.
- **A hike with no recording** shows its start and end together on the map when their map links carry a point; the page says no route is recorded. A short Google link carries no point, so such a hike has no map until someone adds a recording.
- **Height along the walk**: a small chart of the recording's heights, above its length, climb, descent, lowest and highest point.
- **The page's order**: map, key facts in one band, "Open the map", region and status, warnings, the four tiles (Waze and Google Maps now say "to the start"), then the sections of D-34.
- **Gone:** the line drawing as the normal view (it is now only what shows when the map cannot load), and the four separate "where the recording starts/ends" buttons (they are on the map's own points).

**Where the map comes from, and on what terms:**

- **Map pictures:** OpenStreetMap's own server (`tile.openstreetmap.org`), free, under its tile usage policy, read 8 October 2026: the credit "© OpenStreetMap contributors" stays on the map, only what is on screen is fetched, nothing is fetched ahead or kept for use without a connection. The service makes no promise to stay up, and may block heavy use. With one user this is nothing; with the whole membership it is still light, but it is a service the app does not control.
- **The drawing library:** Leaflet 1.9.4 (BSD licence), copied unchanged from its published package into `vendor/leaflet-1.9.4/` (checksums compared), served from this site, loaded only when a map is first needed.
- **Israel Hiking Map**, the map guides know, with the trail colours: **not used.** Its tiles are licensed for non-commercial use, and its own FAQ says showing the map in another site is "in coordination with the authors" and commercial use needs their word. It is one address to change in the code once they agree. **Asking them is the owner's.**

**Who sees what:** unchanged inside the app. New to the outside: when a hike's page shows a map, the member's phone asks OpenStreetMap's server for the map pictures of that area, which shows that server the phone's internet address, the area looked at, and this site's address; nothing about the member or the hike. "Where am I" is worked out on the phone and drawn there; the place is sent nowhere (when the map widens to include the member, the pictures then fetched are of that area). **The privacy notice does not yet say this. It must before Hikes opens to colleagues** (a terms change, the owner's, G13). Today only Eretz Israel Tours sees Hikes.

**Checked:** `hike_page_walk.py`, 91 checks, map pictures stood in for (the test machine cannot reach OpenStreetMap): the line and points on the map, the credit seen and not covered, the still map does not trap scrolling, the open map, "Where am I" (near, far, slow, refused, and that the phone stops being asked when the map closes), a hike with start and end only, with an end only, with nothing; map pictures not arriving; the library or its style sheet not arriving. `preview_walk.py`, 200. A second agent attacked the first version: six faults and a list of small ones, fixed (GPS left running after a slow fix, a dead End point, a half-drawn map when the style sheet fails, the open-map button covering a point, the page saying a recording did not exist when it had only failed to load, a named Google place giving the middle of the screen as its point).

**Seen on the trial copy, 8 October, about 21:50, in the owner's Chrome on his computer:** his own hike Ein Ovdat with the real map: the map pictures came from OpenStreetMap, the recorded route lay on the trail the map draws, Start and End were marked, the credit showed, the figures read 2.09 km and a climb of about 120 m, and the open map came up with "Where am I" and "Whole route".

**Not checked, and it matters:** nothing on a real phone; iPhone; "Where am I" with a real phone's place; the phone's Back button does not close the open map (the app has no handling of Back anywhere).

**Open, the owner's:** whether "Where am I" works for him now, and what the phone says if not; asking the Israel Hiking Map authors; the privacy line before Hikes opens to colleagues.

---

## D-34 · The hike's page: laid out as a finished page, map links that open, a route file that can be used (live since 8 October 2026, with D-35)

**Decided by:** the owner (Eretz Israel Tours), 8 October 2026, about 18:30 Israel time, testing the live Hikes tab on his Android phone (Chrome, a Samsung) after adding a route file to his own hike.

**In his words** (spoken, as transcribed; "Anode dot" is his hike Ein Ovdat):

- "I uploaded a GPX file to Anode dot, and it the layout of the page does not look good. It looks like um, just the layout's not good. It doesn't look like a finished page. It looks like a tab. The edit page looks better, now the start and finish destination Google Map link doesn't open, doesn't show me anything. First start and end."
- "GPX file when I tried to open it it didn't open in any kind of app."
- With a picture of the route file box showing "Could not hand the file over. Save it instead.": "Ein ovdat android". Asked whether a hiking app is installed on that phone: "Yes".

**What was found:**

- **Route file.** The box offered "Open in a hiking app" because the browser said it could pass a file on. Chrome on Android then refuses a GPX file (it passes on pictures, sound, video, text and PDF only), which is the message he got. The stored file was whole: 3,365 points. Whether the saved file then opens depends on a hiking app on the phone that takes GPX files; that part has not been seen on a phone.
- **Start and end.** His start and end are pasted Google Maps short links. The page did build the right link (seen in a phone-sized test: a tap opened a new tab on that address). Why his phone showed nothing is not known. The likely cause is that a short link opened in a new tab is left as an empty tab when the phone tries to pass it to the Maps app. It is a guess until he tries the change.
- **Layout.** The page was a region line, four tiles and one long list of rows; the form, with its named groups, read as the more finished of the two.

**What was built** (front end only, `index.html`; no table, function, grant or policy change):

- **The page is in sections:** the key facts first (distance, usual time, difficulty) as three tiles, then the warnings (cliffs, firing zone), the Waze / Google Maps / Route file / Add report tiles, then "Getting there" (start and end), "The trail" (markers and the route), "The place" (the park, as before), "Important notes", the reports and "Before every trip". Nothing the old page showed is gone.
- **Start and end** each show their words, then a Google Maps button and a Waze button, each only when the place gives it something to go by: Google Maps takes a Google Maps link from the text, else the point a Waze link carries, else a search for the words; Waze takes a Waze link, else the point a Google Maps link carries, else the words. Nothing is searched by the hike's name any more (the two tiles at the top still fall back to it). A place that is only a pasted link says "A pin on the map".
- **On Android a map link asks the phone for the app itself** (Google Maps or Waze), and carries the web address as the way out when the app is missing. Elsewhere, and inside a bare in-app web view, it stays an ordinary link in a new tab. Only an address the page accepted as Google Maps or Waze, or built itself, is ever turned into an app link, and the app is named by the page, never by the address.
- **The route is drawn on the page**: the recorded line, north at the top, with its length, climb and descent (moves of 10 m or more only, shown as "about"), lowest and highest point, and buttons that open the first and the last point of the recording in Google Maps and Waze. Parts of a track are kept apart, so a gap is neither counted nor drawn; a file with a track and a route uses the track. It says it is a sketch, not a map. The file is fetched once per hike and version when its page opens.
- **The route file box** no longer offers handing the file to an app on Android. It says what to do: save the file, open it from the hiking app (or tap it in Downloads and choose the app), and that nothing can open it until such an app is installed. Where a browser offers to pass the file and then refuses, the dead button goes and the same steps show.
- **The file handed over** is the stored route with three things added around it: the XML opening line, and the hike's name on the file and on its track, so a hiking app shows a name. What is stored is unchanged.

**Who sees what:** unchanged. The route file was already open to every member who can see the hike; the page now fetches it when the hike opens instead of when the button is tapped.

**Checked:** `supabase/tests/hikes/hike_page_walk.py`, new: 58 checks as an Android phone at 411, 360 and 320 wide, an Android in-app web view, an iPhone-like browser that passes files on, one that offers and refuses, and a computer; the page's own helpers are called with made-up routes and places and their figures and links compared with figures worked out in the test. `preview_walk.py`: 200 checks; it now ends with a failing exit code when a check fails. A second agent attacked the first version (security of the app links and the markup, the route figures, the layout at five widths, the tests themselves) and its findings were fixed: a fact tile cut off on 360-wide phones, a file broken by some hike names, figures wrong for files with more than one line, climb overstated on noisy heights, "start and end in one place" judged in picture dots, and seven faults the tests did not notice.

**Not checked, and it matters:** nothing here has been seen on a real Android phone. The app links follow Chrome's documented form, and whether they cure "doesn't open" is not known until the owner taps them. Whether a saved route file opens in Israel Hiking Map or Amud Anan on his phone is not known either. iPhone Safari, Samsung Internet and Firefox were not run.

**Open:**

- The supplier pages' Waze and Google Maps buttons are still ordinary links in a new tab. If the app links cure the fault on his phone, the same change belongs there; if those buttons already work on his phone, the cause of fault 2 is something else.
- A route file opened in one tap in Israel Hiking Map needs a web address the map's site can fetch the file from, which would be a new, public, short-lived link to a route file: the owner's decision (who sees what), and the site's way of opening a file by address has to be confirmed first.
- A real map under the line (a map library and map tiles from another site) was left out on purpose: a new outside dependency is the owner's call.

**Status:** built on the branch `hike-page-fixes`. **Not live.**

## D-32 · Hikes and parks: a hike names its park, parks hold brochures, start and end open Google Maps (live for Eretz Israel Tours since 8 Oct 2026)

**Decided by:** the owner (Eretz Israel Tours), 8 October 2026, between 15:12 and 15:34 Israel time, a few minutes after the Hikes tab went live (D-31).

**In his words:**

- 15:12: "Some hikes are connected to national parks. for instance right now I want to add Ein ovdat which I just did today and it's part of that nature reserve perhaps for something like that a see the link hike should be there which will take you to the hike page also for the national parks they all have brochures. There should be a place where they're uploaded."
- 15:14: "Also start and end. Location should. Open Google maps"
- 15:21: "Also the moked teva page link. Only opens general.. Nothing specific to this hike"
- 15:34: "Also, most places that have hikes have different variations of hikes. Like Ein Gedi might have Nachal David. Or the D-U-D-I-M caves. Etc. There are many ways to do Nachal Prat also. So one card should have many different hike options."

**How it was read:**

- A hike can be connected to the supplier it lies in: the national park, nature reserve or site. The link works both ways. The hike's page names the park and opens the park's page; the park's page lists its hikes and opens each one.
- A park's page has a place for its brochure. Brochures are a new kind of file on a supplier, next to photos, price lists and the rest, and show near the top of the page.
- On a hike's page the start and the end are each tappable and open Google Maps.
- The links under "Before every trip" should be about this hike. Moked Teva has no page for one hike that could be linked to (its site could not be read from the session to check), so the park's own page comes first and Moked Teva is named as the whole-country page it is.
- A place with several hikes is one card in the list, holding every hike there. The place is the park or site the hikes are connected to, so this needs nothing new in the database. A hike connected to no place stays on its own.

**What was built:**

- **The hike form** has a field "Part of a park or site". It offers the suppliers the member can see whose category, or one of their "also offers", is National Parks or Attraction / Site: None first, then the places in the hike's region, then the rest by name. With more than eight places a search box narrows the list.
- **The hike's page** shows "Part of" with the park's name, which closes the hike and opens the park's page. Under it: the park's opening hours and last entry as its own page holds them, marked Verified or Unverified; "Book entry" when the park has a booking link (web links only, in a new tab); "Brochure" when the park has one (several open a short list).
- **The park's page** shows its brochure near the top, under the hours, and a section "Hikes here" with each hike's name, distance and usual time, and "Add a hike here", which opens the hike form with the place and its region chosen. A supplier that is not a park or site and has no hikes shows nothing. A park or site with no brochure offers "Add brochure".
- **The list of hikes** shows one card per place inside each region: the place's name, how many hikes it has, and under it every hike there. The card's head opens the place's page. Hikes connected to no place share a plain card below. The search finds a hike by its place.
- **Before every trip**, on a hike's page: first the park's own page, when the hike has a park and the park has a website ("its own page, for closures and changes"), then Moked Teva, worded as trail updates and firing zones for the whole country, with a line saying it has no page for one hike.
- **Start and end**, on the hike's page and inside each report, open Google Maps in a new tab. Only two kinds of link are ever built: a Google Maps link found in the text (the same test as the buttons at the top), or a Google Maps search for the text. A Waze link in the text is never opened as Google Maps: the search is used, by the text, or by the hike's name when no text is left. Any other link in the text stays text. The Waze and Google Maps buttons at the top are as they were.

**Who sees what:**

- A hike never shows a supplier to a member who cannot open that supplier. The database sends the park's id only when the supplier exists, is not hidden, and the member is Eretz Israel Tours or has the supplier's section (`_hike_park`). To anyone else the hike reads as having no park: no name, no hours, no booking, no brochure. An organisation without the sites section gets every hike, and no park on any of them.
- A member can only connect a hike to a supplier he can see himself; anything else is refused with "Choose the place from the list."
- Brochures are open to every member who can open the supplier, organisations included, like photos and kosher certificates. A brochure marked "only me and Eretz Israel Tours" stays private. An organisation still never gets a guide's or agent's price list, receipt, contract, booking confirmation or quote.
- Names only, as before: nothing here sends a member's email, phone or licence number.

**Implementation choices, his to change:**

- The link is the supplier's id on the hike, with no foreign key. A supplier taken off the list, merged or hidden leaves the id where it is, and the hike reads as having no park until the supplier is there again.
- A hidden supplier reads as no park for everyone, Eretz Israel Tours included, and cannot be chosen.
- An older copy of the page, which does not send the park, leaves it as it is. The page itself sends the park with a new hike, and with a change only when the member changed it in the form: a member who cannot see a hike's park is shown None, and his save of another field does not take the park off.
- Setting or changing the park on a waiting hike counts as a change to it, like any other field: an approval of the version read before is refused (D-31).
- The picker offers National Parks and sites only. **Which other suppliers should be offered is the owner's to widen.**
- The hours on a hike's page are shown as text with Verified or Unverified. Marking hours as verified stays on the park's own page.
- "Book entry" and the brochure open in a new tab without passing the app's address on.
- Preview mode has three sample parks and sites (real place names, every detail invented and marked as a sample), three sample hikes connected to them, one sample brochure, and a second sample organisation that has no sites section, to show what such a member gets.

**Database, two files:**

- `supabase/migrations/2026-10-08c_brochure_kind.sql`: one statement, the list of kinds a supplier's file can have gains Brochure. It takes the old list off and puts the new one in its place, so **the owner runs it himself in the SQL editor** (rulebook G5). Safe to run twice. It must be run before the new files function and the new page go live.
- `supabase/migrations/2026-10-08b_hikes_parks.sql`: adds and replaces only, safe to run twice. One new column, `hikes.vendor_id`, with a length check and an index. One new internal helper, `_hike_park`, not callable from outside. Three functions replaced: `_hike_json` (one new key, `vendor_id`), `hike_save` (takes the key `vendor_id`; everything else, its lock order and every earlier check as they were) and `_file_visible` (Brochure joins Photo and Kosher certificate as a kind open to organisations). 154 functions become 155.
- The files edge function, version 12 in the repository: Brochure added to the kinds it takes and to the kinds open to organisations. **Not deployed.**

**Checked (on a local PostgreSQL 16):** a database built from `supabase/schema.sql`, one built from the schema before D-31 with all three files run twice, and one built from the schema on `main` with files c and b run twice each have the same functions, the same roles allowed to call each one, the same columns, constraints, indexes and triggers on every table, and the same privileges and row security on every table and sequence. 225 checks in `supabase/tests/hikes/` as Eretz Israel Tours, two guides and two organisations (156 before); the 98 limited-member checks still pass; the probe for the live database returns what its header lists on the local copies and leaves nothing behind. In preview (`supabase/tests/hikes/preview_walk.py`), 186 checks at phone and desktop size as Eretz Israel Tours, a guide, an organisation that sees sites and one that does not, with no page errors and nothing running off the side of the screen (84 before).

**Not checked:** production (nothing has been run there); PostgreSQL 17; the files edge function, which was changed by hand and read, not run (no Deno on the build machine; its text passes a syntax check only); uploading and opening a real brochure through the live files function; a real phone; whether a tap on start or end opens the Google Maps app on a phone; Safari and Firefox. No second session has tried to break this change yet (D-31 had four such rounds).

**Open:**

- **For the lawyer's list:** brochures are the Parks Authority's own handouts. Members upload them for colleagues' use inside the app only. They are never placed on a client-facing page. Whether keeping copies for colleagues is in order is a question for a lawyer.
- Which suppliers besides National Parks and sites the picker should offer: the owner's to widen.
- The line in the terms, and the Hebrew side, as for D-31.

**Status: live since 8 October 2026, about 16:40 Israel time**, on the owner's word at 16:31 ("Make. Them live."). Hikes are still open to Eretz Israel Tours only, so colleagues see the brochure kind and nothing else of this until he opens Hikes. In order: the owner ran `2026-10-08c_brochure_kind.sql` himself in the SQL editor (16:33, "I think I did it in supabase"; the list of kinds was read afterwards and holds Brochure); `2026-10-08b_hikes_parks.sql` went through the connector in two parts (`hikes_parks_2026_10_08b_part1_column_helper_hike_json`, `part2_hike_save_file_visible`); all 155 function fingerprints equal `supabase/tests/hikes/expected_fingerprints.txt`, with 30 tables, 91 functions callable from outside, 0 table grants and 0 policies; the files function was deployed as version 12 and its deployed source read back equal to the repository file; `supabase/tests/hikes/production_probe.sql` returned every expected value and left nothing behind; then pull request #30 was merged by the session. Not checked: the files function answering a real call (the session cannot reach it), a real upload of a brochure, the live page in a browser, a real phone.

---

## D-31 · Hikes: official marked trails, with a report after the walk (live for Eretz Israel Tours since 8 Oct 2026)

**Live since 8 October 2026, about 15:02 Israel time, for Eretz Israel Tours only.** The owner merged pull request #28 himself at 14:57 ("Merged"). The database file was then run on production through the connector, in parts (`hikes_2026_10_08_part1_tables` to `part5_set_setting_whoami`), with `whoami` last so the tab appeared only once everything behind it was in place. Checked after (G4): 30 tables, 154 functions, 91 callable from outside, 0 table grants, 0 policies; all 154 function fingerprints equal `supabase/tests/hikes/expected_fingerprints.txt`; the three new tables equal the schema record (columns, constraints, indexes, row security); `supabase/tests/hikes/production_probe.sql` returned every expected value and left nothing behind (0 hikes, 0 reports, 0 route files, no probe member, no `hikes_for` row). Colleagues do not have the tab: `hikes_for` is not set, which reads as Eretz Israel Tours only. Not checked: the live page in a browser (no browser was reachable from the session), a real phone, a route file opened in a hiking app.

**For the next session that sends SQL through the connector:** the connector turns a written-out character code of the form backslash-u-four-hex-digits into the character itself before the SQL reaches the database. `_hike_gpx_put` arrived with the two characters instead of the two codes: same behaviour, different text, so its fingerprint differed. It was sent again inside a `do` block that swaps a placeholder for the backslash (`hikes_2026_10_08_part2b_gpx_put_exact_text`), and now equals the repository to the letter. Other backslash forms (`\.`, `\s`, `\x01`) arrive unchanged. Compare fingerprints after every part, before the part that switches a feature on.

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 8 October 2026, in steps between 09:14 and 12:06 Israel time.

**In his words:**

- 09:14: "Put in the pipeline a hikes tab - gpx, important notes, distance, how long it typically takes. If putting in for after then group size, ages, difficult level, cliffs (fear of heights), water shoes, start location, end location, points of interest, firing zone, water, bathrooms, can you eat on hike. Etc."
- 09:17: "We can scrape websites for hiking in Israel like hiking the holy land, trail, lovloveisrael, any others?facebook?reddit, Hebrew and English, as well as מוקד טבע, sort by region"
- 10:45: "2 I think to enter after hike 3 yes and can update 4 yes as long as it's been updated in last few years. Any Israel hiking websites Agreed on all points. We take no. Responsibility for the info on the app message or disclaimer" (2 = the longer list is a report entered after the hike; 3 = organisations see hikes and can update; 4 = hikes may be taken from websites.)
- 11:34, of the mock-up: "Can you add trail markers and numbers"
- 11:53, of the mock-up with the choices listed: "Looks great!"
- 12:06: "I think build it now, why not? Number two, I don't know what trail means. It has to be an official marked trail. Hiking trail number or color is not mandatory. You can write for 3 , unverified. And aside from that, GPX needs to open on an app. You can offer suggestions. Israel hiking map.  Or Amud aNan."

**What it is:** a Hikes tab. A hike is an official marked trail: its name and region, a route file (GPX), important notes, the distance and the usual time, where it starts and ends, and the trail markers on the way (colour and trail number, in walking order, both optional). After walking it, a member adds a report: the date, group size, youngest and oldest, difficulty, cliffs, water shoes, points of interest, firing zone, water on the route, drinking water, bathrooms, whether you can eat on the way, and anything else. The hike's page shows a summary of the reports and each report with the name of who wrote it.

**The rules he set:**

- Only official marked trails are listed. The form asks for a tick; without it nothing is saved.
- Hikes are shown sorted by region.
- Organisations (limited members) see hikes and can add hikes and reports, like every other member.
- Hikes may be taken from Israeli hiking websites, in Hebrew or English, when the page was updated in the last few years. With the mock-up he accepted 3 years. A page that shows no date is taken and shown as Unverified, "date not known".
- What is taken from a website is its facts in the app's own words, with a link to the page; the page's text, pictures and route file are not copied. A hike from a website shows as **Unverified** until a member has reported walking it (rulebook E2). Facebook and Reddit are not read in bulk.
- A route file comes from a member's own recording or a route he drew on an open map. It must open in a hiking app; the app names Israel Hiking Map and Amud Anan.
- The firing zone answer says only whether the route crosses one. The app never says a route is open.
- Group size and ages are numbers. No client's name and no trip details go in any field (rulebook D6, D7).
- The app carries a message that no responsibility is taken for hike information. Wording as he approved it on the mock-up: "Hike details are colleagues' reports and notes taken from websites. Eretz Israel Tours and the members take no responsibility for them. Check the route, the weather and any firing zone yourself before every trip."

**Accepted with the mock-up (11:53), his to change:** any member may add a hike, and a new one shows to colleagues once Eretz Israel Tours has approved it; the Hikes tab sits between Quotes and Jobs; a report shows its writer's name; every hike links to Moked Teva's safety pages; markers are entered with the hike, not with the report.

**Implementation choices, his to change:**

- A member can change his own hike while it waits for approval. Once it is approved only Eretz Israel Tours changes it; everyone else has "Suggest a change", which goes to Feedback with the hike named.
- Eretz Israel Tours approves the version it read. If the writer changed the hike, its route file or his own reports on it after that, the approval is refused and the hike has to be opened again.
- Nothing is ever removed from the database: a hike taken off the list, a report taken off and a route file taken off are marked and kept. Eretz Israel Tours can put a hike back.
- One route file per hike. A report can bring a route file only when the hike has none.
- Only the route is kept from a file: its points, their heights and the names of marked spots (up to 200 spots, 60 characters a name). The recorder's name and email, the date and times of the walk, the name he gave the recording and the file's own name are left out: the page writes a new file from the points alone before sending it, and the database takes that form and nothing else. Every route file is called `route.gpx`; when saved it takes the hike's name.
- The summary takes the most common answer, except cliffs and firing zone: one report saying yes is enough.
- In a start or end place, only a Waze or Google Maps link becomes a button; any other link stays as plain text.
- A member may add 20 hikes and 30 reports a day.
- Reports of an organisation are marked "Organisation". Organisations read all reports on hikes (they read guides' reviews of suppliers on transportation only, D-15; a hike is not a supplier).
- The 3-year rule is asked when a hike is added or its page year is changed, not when an older entry is corrected.
- The message about responsibility is in the app from the start. The matching line in the terms waits for the week's terms release (rulebook G13) and for a lawyer; **no terms change is in this branch**.

**Opens to Eretz Israel Tours first (rulebook G2):** a new setting, `hikes_for`: `admin` (only Eretz Israel Tours; the default) or `all`. The switch is in the Team tab.

**Database (`supabase/migrations/2026-10-08_hikes.sql`; it only adds and replaces):** three new tables, `hikes`, `hike_reports`, `hike_gpx`, closed like every other table (row security on, no grant, no policy). Six new internal helpers (`_hikes_on`, `_hike_visible`, `_hike_markers_clean`, `_hike_json`, `_hike_detail_json`, `_hike_gpx_put`), none callable from outside. Seven new calls: `hikes_list`, `hike_detail`, `hike_save`, `hike_decide`, `hike_report_save`, `hike_report_hide`, `hike_gpx`. Two functions replaced, each gaining only the hikes switch: `whoami` (two new keys, `hikes` and `hikes_for`) and `set_setting`. 141 functions become 154.

**Not in this branch:** loading hikes from websites (a data job for after the tab is live, each source first read for what it allows); a map on the page; the Hebrew side; a line in the welcome tour; the terms line.

**Checked (on a local PostgreSQL 16; production is PostgreSQL 17, see Not checked):** a database built from `supabase/schema.sql` and one built from the schema before this change with the file run twice have the same functions, columns, constraints and indexes; 156 checks in `supabase/tests/hikes/` as Eretz Israel Tours, two guides and an organisation; the 98 limited-member checks still pass; the probe for the live database returns what it should on the local copy and leaves nothing behind. In preview (`supabase/tests/hikes/preview_walk.py`), 84 checks at phone and desktop size as Eretz Israel Tours, a guide and an organisation, with no page errors. A second session that wrote none of it tried to break it in four rounds, on the database and through the page. It found, among smaller things: a hike could be swapped between the moment Eretz Israel Tours read it and the approval; a route file could carry the recorder's name, email and times, and its own file name; a crafted route file could keep the database busy for minutes; a save already under way could land on a hike just approved. All of it was fixed and is in the checks; its fourth round found nothing it would hold the change for, and the three small points it raised then were fixed afterwards and are covered by the author's checks only.

**Not checked:** production itself (the file has not been run there); PostgreSQL 17; a real phone; opening a route file in Israel Hiking Map or Amud Anan, which depends on the phone's own "open with"; Safari and Firefox.

**For a lawyer, before it opens to colleagues:** the message about responsibility (a notice may not remove responsibility for safety information); reports that name where and when a group walked; taking facts from other websites.

**Status:** built on the branch `hikes-tab`. **Not live.** The database file has not been run on production and nothing is merged.

---

## D-30 · A real client's details never appear anywhere public; example text and sample data are invented (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 7 October 2026, 13:11 Israel time, after a read-only report.

**In his words:** "replace it" and "rewrite history and make a rule that private client data never shows up publicly for anyone".

**What was found:** the example text in the box "For which trip or client? (private)", in the quote form and in the booking sheet form, and two lines of the preview's sample data, used a real client's family name. The sample quote also repeated that trip's first day, head count and the date the quote was received. Every member saw the two example texts. This repository is public, and anyone can download the page file without a member link.

**The rule (rulebook D7):** nothing about a real client or a real trip goes anywhere that is public or that members can see. That covers the code, example text, sample data, tests, the files in this repository, commit messages, pull request and issue text, preview pictures, and any document shared outside Eretz Israel Tours. Example and sample data are invented, say "Sample", and do not copy a real trip's name, dates, head count or prices. A real client's details stay in Eretz Israel Tours' private notes and private Drive. Before a session pushes anything, it searches what it is pushing for the client names in those private records.

**What was changed:**

- Both example texts now read `Sample family, May 2027`.
- The preview's sample booking sheet is labelled `Sample family, Nov 2026`.
- The preview's sample quote is titled `Sample family, 6 days`, with invented dates (7–12 March 2027), 16 people, received 1 September 2026, valid to 28 February 2027.
- Front end only (`index.html`, four lines). No database change, no terms change. The example texts are hints in an empty box, and the sample data runs only in preview, so nothing a member can do changes.
- The history of this repository is to be rewritten so that the name is in no commit of any branch. Not yet done; see `docs/STATUS.md` for where that stands.

**Checked:** in preview at phone size as Eretz Israel Tours and as an organisation: both forms show the new example text; the sample quote and the sample booking sheet show under their new labels; the Quotes tab draws; no page errors; the name is nowhere in the page that is served or in any file of the repository. On the live site after the merge, read once, read only: the page it serves holds the new example text twice and the name nowhere. Pull request, issue and comment text on GitHub was searched for client names: none. **Not checked:** nobody has opened the two forms on the live site.

**Status:** the replacement is live since 7 Oct 2026, about 13:16, on the owner's word of 13:11 ("replace it"); pull request #25. The rewrite of the history is NOT done.

---

## D-29 · Prices on a driver's or bus company's page: every vehicle size, airport transfers to and from Ben Gurion, agent price (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 7 October 2026, 12:31 Israel time. He had just added an independent van driver with five vehicle sizes and airport transfers.

**In his words:** "pricing for drivers needs to have all of the options of vehicle size. it needs airport transfer Ben Gurion - (add City) and (add city) Ben Gurion needs agent price".

**Decision:** on a Transport supplier (an independent van driver or a bus company) a price says which vehicle size it is for, an airport transfer says which way and which city, and the price is entered as an agent price.

**Changed the same day, on his word at 12:43, after the first preview:** "i think it should be in a dropdown format of all the relevant pricing - a list is too daunting". It could mean the form or the list of saved prices, so both were changed and shown to him again.

**What was built (implementation choices; change on request):**

- "Add price" on a Transport supplier is a short form of drop-downs. **What is the price for?** is one drop-down: Airport transfer Ben Gurion → city, Airport transfer city → Ben Gurion, Airport transfer both ways at the same price, Day rate, Per hour, Something else. The "both ways" choice was not asked for; it is saved as one line marked "each way".
- **City** (for a transfer) is a drop-down of 39 towns that ends with "Another city…", which opens a box to type any city.
- **Vehicle size** is a drop-down of all seven sizes (bus, midibus, the four van sizes, car). It is required for a transfer, a day rate and an hourly rate. A driver with one size has it filled in.
- **Agent or public price?** is a drop-down, "Agent price" first and the default, and the price box is named after the one chosen ("Agent price, one way"). An organisation never sees this choice and its line is never an agent rate (C3), as before.
- Season and the note are folded under one line, "Season, extra charges, a note". Where the price is from and the date it was checked stay in view (E4).
- Not asked for: **"Save + add another"**, which opens the next line with the same kind, city, vehicle, VAT and source, so a driver's whole list can be typed in a row.
- **On the supplier's page** a Transport supplier's prices are no longer one long list. They sit under headings that open on a tap: Airport transfers, Day rate, Per hour, Other prices, each with its count. With more than one vehicle size on the page, a **Vehicle size** drop-down above them keeps only that size. With three prices or fewer the groups start open. Inside a group a line is named without repeating the heading ("Ben Gurion → Jerusalem · Van, up to 8 seats").
- The kind, the route and the vehicle are written into the line's name ("Airport transfer: Ben Gurion → Jerusalem · Van, up to 8 seats"). Front end only (`index.html`): no table, column or database function changed, so who sees a price is exactly as before. Lines already on the list are untouched; they open under "Something else" and are listed under "Other prices".
- A transfer is saved per vehicle, a day rate per day, an hourly rate per hour; "For", child ages and group size are not asked for those three.
- Suppliers that are not Transport keep the form and the flat price list they had.

**Checked:** in preview, 52 checks at phone and desktop size as Eretz Israel Tours, as a colleague and as an organisation: every vehicle size offered; both directions and both ways; a city from the list and a typed city; agent and public; the refusals (no city, no vehicle size); the groups, their counts, the size drop-down; edit opens a saved line with its parts set; an older free-text line saves unchanged; "Save + add another" keeps "Suggest for everyone" and the reason; an organisation's line is an organisation rate and it is shown no agent rate; a jeep supplier's form and list are as before; no page errors. 160 names written and read back the same. **Not checked:** on the live site; on a real phone; by a session other than the one that built it. The limited-member database checks were not run again because the database is not touched.

**Status:** live since 7 Oct 2026, about 13:00, on his word at 12:57: "go live". He was shown two sets of preview pictures first; the second, the drop-down form and the prices in groups, is what went live. Front end only. No terms change, no database file. Not yet tried on the live site by a person.

---

## D-28 · Gaza Envelope is a region (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 17:37 Israel time.

**In his words:** "add Gaza Envelope - עוטף עזה as a region".

**Decision:** the region list gains **Gaza Envelope - עוטף עזה**, written as he wrote it.

**What was changed (implementation choices; change on request):**

- It sits after "Negev & Arava" in the list. It is offered wherever a region is chosen: the supplier form, where a driver is based, and a job.
- As with every region, its button on the supplier list appears once a supplier a member can see is in it.
- Front end only (`index.html`, one line). The database takes any region text up to 60 characters, so nothing changes there.

**Suppliers moved into it, on his word:** four suppliers that were under "Negev & Arava", all four hidden and waiting for review: Burnt Vehicles Compound (Tkuma), Garden of Heroism and Remembrance (Sderot), Nova Festival Memorial Site (Re'im), The Salad Trail (Talmei Yosef). Asked whether to move them, he said at 17:42: "yes to both". Only the region of those four rows was changed.

**Checked:** in preview at phone and desktop size: the region is offered on the supplier form and is saved as chosen; with one sample supplier placed in it, its button shows on the list and filters to that supplier. No page errors. **Not checked:** on the live site.

**Status:** live since 5 Oct 2026, about 17:45, on his word at 17:42: "yes to both" (go live, and move the four suppliers). Shown the preview picture first. Front end only, plus the region of four supplier rows. No terms change. Until one of the four is approved or another supplier is put in the region, colleagues see it in the forms but not as a filter button.

---

## D-27 · "Did they check your reservation?" is asked at national parks only (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 17:23 Israel time.

**In his words:** "shimshons farm is private and i got a popup about reservations, that isnt relevant there".

**Decision:** the question whether a reservation was actually checked belongs to national parks, where booking is the official rule and the gate does not always ask. A private supplier is booked with the supplier, so there is nothing to report.

**What caused it:** the reservation bar and its one-time pop-up were built for national parks. Since the supplier findings import of 4 October, 38 suppliers that are not parks carry a reservation setting (activities, museums, wineries, restaurants): 19 "required", 16 "recommended", 3 "not needed" (read from the live database on 5 October, 17:40). The pop-up opened on the 19 marked "required", 9 of which colleagues can see; the "They checked / Not checked" buttons showed on all 35 marked "required" or "recommended", 18 of which colleagues can see.

**What was changed (implementation choices; change on request):**

- The pop-up, the "Colleagues reported" line and the "They checked / Not checked" buttons show only on entries in the category National Parks. Parks are unchanged.
- Any other supplier with a reservation setting shows one plain line and no question: "Book ahead: by reservation only", "Reservation recommended" or "No reservation needed". The wording "Book ahead: by reservation only" is the session's, in place of "Reservation officially required".
- The "Reserve ahead" label on the supplier list is unchanged.
- Front end only (`index.html`). Nothing in the database changes and no supplier's setting was changed.

**Left as it is:** one answer already given on a private supplier (Eretz Israel Tours, "they checked", Shimshon's Farm, 5 October at 17:21) stays in the database and no longer shows anywhere. Removing it is a delete, which is the owner's to run.

**Checked:** in preview, before and after, at phone and desktop size, as Eretz Israel Tours and as an organisation: a private supplier marked required, recommended, not needed and not set; a national park marked required. No page errors. **Not checked:** on the live site.

**Status:** live since 5 Oct 2026, about 17:40, on his word at 17:34: "yes go live". Shown the before and after pictures first. Front end only. No terms change.

---

## D-26 · "Hours counted from": "Leaving the depot" becomes "When the bus turns on" (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 16:47 Israel time.

**In his words:** "Hours counted from / The pick-up  Leaving the depot  - change leaving the depot to from time bus stops". That could be read three ways, so he was asked what the second choice should say, and answered: "when the bus turns on".

**Decision:** the second choice under "Hours counted from" reads **When the bus turns on**. The first, **The pick-up**, is unchanged.

**What was changed (implementation choices; change on request):**

- English: "When the bus turns on" on the guide's form, "when the bus turns on" on the sheet and on the company's page, and in the plain WhatsApp message with blanks.
- **Hebrew:** "התנעת האוטובוס", so the sheet reads "השעות נספרות מ־ התנעת האוטובוס". It replaces "היציאה מהחניון". Proposed by the session; shown to him and approved at 17:18 ("yes and make live").
- What is stored does not change (the value is still `depot`), so nothing in the database changes and a sheet that already holds this choice simply reads the new words.
- **The quote a confirmed sheet leaves** in the Quotes tab already says "Hours counted from when the bus turns on.": the owner ran `supabase/migrations/2026-10-05c_quote_wording.sql` himself at about 17:15 (see D-25).

**Checked:** in preview at phone size: the guide's form, the company's form, and the finished sheet. **Not checked:** on the live site; whether bus companies read "התנעת האוטובוס" the way he means it.

**Status:** live since 5 Oct 2026, about 17:25, on his word at 17:18: "yes and make live". Front end only. No terms change. With the database file he ran at 17:15, the sheet and the quote of a confirmed sheet now use the same words.

---

## D-25 · The guide can leave terms off a booking sheet, by tick box (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 15:44 Israel time.

**In his words:** "can make "all of the terms youre expecting" removable by box. meaning if i want to send without the "tip" or ;mileage etc". In the same message he settled the open point of D-24: "keep" (the optional "Where to" for each day stays).

**Decision:** each of the terms on a booking sheet can be taken off that sheet with a tick box.

**How it was read (his to correct):** a term left off is off the sheet altogether. The company is not asked about it, neither side's sheet shows it, and it is not flagged as "not stated". Leaving a field empty already meant "I don't propose anything here, the company fills it in"; this is the further step of not asking at all.

**What was built (implementation choices; change on request):**

- **Eight tick boxes** at the top of "Terms you expect", all ticked to begin with: Hours and overtime (hours in a day, where they are counted from, the extra hour), Mileage (km in a day, the extra km), Kvish 6 and tolls, Parking, Driver tip, Cancellation policy, Other extras, Payment. **The price and its VAT cannot be taken off.** "Anything else" stays as free text.
- **Unticking a box** takes its fields out of the form, keeps what was typed in the others, and leaves that term off the sheet the company gets: its page does not ask for it, and the plain WhatsApp message with blanks does not list it.
- **The warnings follow:** nothing left off is listed under "not stated", and with Cancellation policy left off the company is not warned that it left the policy empty.
- **Stored** in one new column, `bookings.terms_off`. The database also drops a term that was left off from anything the company sends, so it cannot be added back from the company's side.
- **Part of what both sides accept:** taking a term off (or putting one back) after the company accepted clears its acceptance and sends the sheet back to it. A term put back comes back empty and is asked again.
- **The sheet's closing line is unchanged:** "Anything not written here will not be charged." So a term left off is one the company cannot charge for under the sheet. Whether that wording holds up is one of the points already listed for a lawyer (the booking sheet's closing line).
- **The quote a confirmed sheet leaves** in the Quotes tab says nothing about a cancellation policy that was left off the sheet. This part came later the same day: it sits in the one function the connector will not send without his confirmation, so the owner ran `supabase/migrations/2026-10-05c_quote_wording.sql` himself at about 17:15 ("done"). The same file makes the quote say "Hours counted from when the bus turns on." (the words he gave at 16:47 for the second choice under "Hours counted from"; the wording on the sheet itself is a separate change that waits for his word). Checked on production straight after: 141 functions, every fingerprint equal to the tested copy, only `_booking_to_quote` changed, and a rolled-back probe gave the expected conditions on both quotes and showed an organisation nothing of the probe's name, client or note.

**Checked:** 12 further checks in `supabase/tests/booking_day_times/run.sh` (33 in all): the list keeps only known groups; a term left off is gone from what the guide expects; the company cannot add it back; an old copy of the app keeps the list; a term taken off after acceptance leaves the agreed terms and sends the sheet back; a term put back is asked again. In preview at phone size: the boxes, the form, the plain message, reopening, the company's form and sheet, and the cancellation warning with and without the policy on the sheet. **Not checked:** on the live site; on a real phone; at desktop size; by a session other than the one that built it.

**Status:** live since 5 Oct 2026, about 16:10. Asked whether to go live with D-24 and D-25 together, he said at 15:57: "yes go live." The database file `supabase/migrations/2026-10-05b_booking_day_times.sql` went through the connector this time (it holds nothing the connector asks him to confirm). Checked on production straight after: 27 tables, 141 functions (138 before), 0 table grants, 0 policies; every function's fingerprint equals the tested copy (`supabase/tests/production_fingerprints.txt`); the three helpers cannot be called from outside; and a rolled-back probe as a guide and as an organisation (`supabase/tests/booking_day_times/production_probe.sql`) came back as expected and left nothing behind. Then the branch was merged. Production had no booking sheets at the time.

---

## D-24 · On a booking sheet of more than one day, each day has its own pick-up time and estimated finish (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 15:34 Israel time.

**In his words:** "each day needs its own start and finsh time. there should be be timated. for instance this is what the itinerary looks like." With it he attached one of his own trip itineraries, where each bus day has its own pick-up time and an estimated return, some still to be set. The itinerary is a client document and is not kept in these records (D6).

**Decision:** on a booking sheet for more than one day, every day carries its own start time and its own finish time, and the finish is an estimate.

**What was built (implementation choices; change on request):**

- **The form:** when a sheet has more than one day, a block "Times for each day" lists the chosen days. Each has a pick-up time, a finish time ("to about") and an optional "Where to". The single pick-up time and drop-off time fields are hidden then; pick-up place and drop-off place stay, one for all days. **Same times every day** copies the first day's times to the rest.
- **"Where to" for each day was not asked for.** It was added because the itinerary he showed has a different region each day and a bus price depends on where the bus goes. It is optional. Asked whether to keep it, he said at 15:44: "keep".
- **What the company sees:** under the date line, one line for each day, Hebrew with English under it: "ד׳ 18.11 · איסוף 08:30 · סיום משוער 18:00 · ים המלח" / "Wed 18 Nov · pick-up 08:30 · finish about 18:00". A day with a pick-up time and no finish reads "finish time to follow"; a day with nothing reads "times to follow". Also in the WhatsApp plain message and the printed sheet.
- **Every finish time is worded as an estimate** ("סיום משוער", "finish about"). Nothing else on the sheet says what an estimate means for overtime: the hours included in a day and the price of an extra hour are the company's to fill in, as before.
- **Stored** in one new column, `bookings.day_plan` (`{"2026-10-20": {"start":"08:30","end":"18:00","route":"…"}}`). Empty means the sheet's one pick-up and drop-off time apply to every day, so sheets made before this are unchanged. When every day has the same times and no "Where to", nothing is stored per day and the sheet shows one pick-up and one drop-off time, as before.
- **The times are part of what both sides accept:** a time changed after the company accepted clears its acceptance and comes back to it in red (D-5, item 10). Taking a day off the sheet takes its times with it.
- A one-day sheet is unchanged. Sheets of more than 31 days get no per-day block.

**Checked:** `supabase/tests/booking_day_times/run.sh` (21 checks: the change file run twice on the earlier schema gives the same functions and columns as the schema record; sheets made before the change read exactly as they did; bad times, days not on the sheet and empty entries are dropped; an old copy of the app keeps the times; a time changed after acceptance goes back to waiting; an organisation sees only its own sheets). The 98 limited-member checks and the 26 day-picker checks still pass. In preview, at phone and desktop size, as Eretz Israel Tours: fill in, save, plain message, reopen, same times every day, and the company's page. **Not checked:** on the live site; on a real phone; by a session other than the one that built it; in preview as an organisation; the red marking of a changed time on the company's page was checked in the database only, not looked at.

**Status:** live with D-25; see its status line for the go-live checks.

---

## D-23 · Photographer is a subcategory under Other (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 11:43 to 12:02 Israel time.

**In his words:** "also add as a supplier photgrapher". Offered its own category (which needs a database file he runs) or a type under Other (no database change), he first said "Photographer own category" (12:01) and a minute later settled it: "photgrapher sub category under other" (12:02).

**Decision:** a photographer is listed under the category Other, with the type Photographer. It is not a category of its own.

**What was built (implementation choices; change on request):**

- **The supplier form** offers "+ Photographer" as a type when the category is Other.
- **The supplier list:** when Other is switched on, a second row appears with **All other** and **Photographers**, the same way Extreme and Activity have theirs (D-20). The button shows once a photographer is on the list.
- **A photographer's entry reads "Photographer"** where it would have said "Other", the same idea as D-19.
- **No food nearby** on a photographer's page: it is a service that comes to the client, not a place (E7).
- **Organisations** see photographers only if Eretz Israel Tours gives that organisation the Other section. By default they do not, the same as every supplier under Other.
- A sample photographer was added to the preview's sample list. The live list is untouched: no photographer exists on it until someone adds one.

**Checked:** in preview at desktop and phone size as Eretz Israel Tours (filter, entry, page, form) and as an organisation (does not see it). **Not checked:** on the live site; by a session other than the one that built it.

**Status:** live since 5 Oct 2026, about 15:30. He saw the preview picture and, asked whether to put all three changes of the branch `email-choice` live, said at 15:27: "yes". Front end only. No database change, no terms change. The live list has no photographer yet, so the Photographers button shows once someone adds one.

---

## D-22 · The Email button on a computer offers Gmail, the mail program, or copying the address (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 11:30 to 11:37 Israel time.

**In his words:** "also when i click email for a vender nothing happens", then "email was on cpu", and, offered a fix in the app for everyone (tapping Email offers Open in Gmail, Open mail app or Copy address, with a preview first): "yes - fix now".

**Cause, read in the code:** the Email button was an ordinary email link, which asks the device to open its own mail program. A computer where none is set for email links (Gmail used only in the browser, for example) does nothing. Nothing in the app blocked it. Not reproduced on his computer.

**What was built (implementation choices; change on request):**

- **On a computer**, Email opens a small box with the address and four buttons: **Open in Gmail** (a new tab with the message started), **Open my mail program** (the old behaviour), **Copy the address**, **Cancel**. "A computer" means a device with a mouse; a phone or tablet behaves exactly as before and opens its mail app at once.
- **The same box** is used for the other three places the app starts an email: asking a supplier for agent prices, the welcome message to a new member, and sending a booking sheet by email. Subject and message carry over to Gmail.
- **The hidden copy to Eretz Israel Tours is unchanged:** it is added for the same members as before, in Gmail as in the mail program, and the box says so. The first-time notice about the hidden copy still comes first.
- **"Don't ask again on this computer"** (the owner, 11:42, offered it: "yes pls"): a tick box in the box. Ticked, the choice of Gmail or the mail program is kept on that computer only (in the browser, like the welcome tour) and Email then opens that way at once. My settings shows "On this computer, Email opens Gmail" with **Ask me each time** to undo it. Copy and Cancel are never remembered. If the browser blocks the Gmail tab, the box shows again.
- **Only Gmail is offered as a browser mailbox** (the owner, 11:42: "thats fine").

**Checked:** in preview at desktop size as Eretz Israel Tours and as an organisation (box shows, Gmail and mail-program links correct, copy works, box closes), and at phone size (no box, mail app link as before). The links were checked with a subject, a message and a hidden copy. **Not checked:** on the live site; on his computer; Gmail itself opening (no internet access from the test); the hidden copy in the running app (the demo members have none); by a session other than the one that built it.

**Status:** live since 5 Oct 2026, about 15:30, on his word at 15:27 ("yes" to putting the Email box, the narrow-window row fix and Photographer live together). Front end only (`index.html`). No database change, no terms change. Brought up to date with `main` after D-21 went live (the one shared line, the booking sheet's Email button, keeps both changes). Not yet tried on his computer.
## D-21 · A booking sheet for separate days inside a period (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 11:07 and 11:12 Israel time.

**In his words:** "booking sheet - it only has full dates example nov 18 -27 what if i need only 5 dates during that period? how do i delinieate days?" Told that the sheet could not do it, and asked whether to prepare a preview of a "Which days" picker: "yes".

**Go-live:** he saw the preview pictures (11:29, "looks good") and, asked whether to put it live, said at 11:30: "yes".

**What was built (implementation choices; change on request):**

- **The form keeps Date and Until.** When the two are more than one day apart, a small calendar of that period appears under them, "Which days", with every day switched on. Tapping a day leaves it out. Periods longer than 62 days get no calendar.
- **What is stored:** one new column, `bookings.days`, a comma list of the chosen days. Empty means every day from the first date to the last, so every sheet made before this is unchanged. The first and last chosen day become the sheet's dates. Chosen days that are all in a row are stored as a plain period, with no list.
- **What the company sees:** the date line lists the days with their weekday, in Hebrew and in English ("5 ימים: ד׳ 18.11, ה׳ 19.11, …" / "5 days: Wed 18 Nov, Thu 19 Nov, …"), also in the WhatsApp message and the plain-message version. A plain period now also says how many days it is ("… · 10 days").
- **The number of days is written beside the price per day** ("× 5 days") on the sheet, and above the price box on the company's page ("This booking is for 5 days. The price is for one day."). No total is worked out: overtime, extra km and tolls make a total a guess.
- **The days are part of what both sides accept.** Changing a day after the company accepted clears its acceptance and comes back to it in red with the earlier days, the same rule as any other change (D-5, item 10).
- **The quote a confirmed sheet leaves in the Quotes tab** counts the chosen days, not the period, and its conditions say "5 separate days between these dates."
- **Who can use it:** whoever can use booking sheets today, organisations included, on their own sheets. Nothing new is sent to anyone else. No terms change: 6c already says the company sees the date of the job.

**Not built, his to ask for:** a different time, pick-up or outline for each day (the sheet still has one of each for all days); a total price.

**Checked:** `supabase/tests/booking_days/run.sh` (26 checks: the change file run twice on the earlier schema gives the same functions and columns as the schema record; a sheet made before the change reads exactly as it did; junk, repeats, impossible dates and days outside the period are dropped; an old copy of the app keeps the days unless it moves the dates; a day dropped after acceptance goes back to waiting; the quote counts the chosen days; an organisation sees only its own sheets). The 98 limited-member checks still pass. In preview, at phone and desktop size, as Eretz Israel Tours: fill in, save, send, reopen, and the company's page. **Not checked:** on the live site; on a real phone; by a session other than the one that built it; in preview as an organisation.

**Status:** live since 5 Oct 2026. The connector's approval prompt was cancelled twice, so the owner ran `supabase/migrations/2026-10-05_booking_days.sql` himself in the Supabase SQL editor at about 11:42 (G5). Checked on production straight after: 27 tables, 138 functions, 0 table grants, 0 policies; every function's fingerprint equals the tested copy (`supabase/tests/production_fingerprints.txt`); the helper cannot be called from outside; and a rolled-back probe as a guide and as an organisation (`supabase/tests/booking_days/production_probe.sql`) came back as expected: the days are kept and reach the company's page, the company's page gets no private field, each sees only its own sheet. Then the branch was merged. Before the change production had 137 functions and no booking sheets.

---

## D-20 · Choose two or more categories at once; subcategories under a category (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 4 October 2026, 18:26 Israel time.

**In his words:** "I want to be able to choose two or more categories from top. Like extreme, activity etc" and "I think I also want subcategories - extreme should have jeeps, atvs, water, rappelling, etc".

**Decisions:**

1. **More than one category can be chosen at the top of the supplier list**, for example Extreme and Activity together.
2. **A category can have subcategories.** Extreme has Jeeps, ATVs, Water, Rappelling and so on.

**Implementation choices (not owner decisions; change on request):**

- **Two categories together show the suppliers of either one** (Extreme or Activity), not only suppliers that are both.
- **A subcategory is a group of the type tags suppliers already carry.** Jeeps = Jeep; ATVs = ATV / RZR; Water = Kayak & rafting, Boat, Snorkelling; Rappelling = Rappelling; then Zipline, Bikes, Horses, Camels, Shooting. A subcategory button shows only when a supplier on the list has that type. Nothing in the database changes and nothing new is sent to anyone.
- **Two subcategories together show either one** (Jeeps or Water). A subcategory narrows its own category only: with Extreme and Activity on and Jeeps picked, the list is the jeep suppliers plus every activity.
- **Activity got subcategories too**, from the types already on its list (Workshops, Food & wine, Farms, Family, Volunteering, Archaeology, Shooting). The owner named Extreme only; this was added so the two rows behave alike, and it comes out on his word.
- **Guide and Transport keep the second rows they had** (guide details; bus company or van driver; vehicle size).
- **Regions are still one at a time.** He asked for categories.
- **"All" clears every category and subcategory.** Tapping a chosen category again switches it off.
- **A supplier with no type tag** shows under its category and under no subcategory. On 4 October one Extreme supplier (hidden, in review) has none of the listed types.

**Not changed:** the stored categories, the supplier form, the database, the terms, what a limited member receives.

**Status:** live since 4 October 2026, about 19:00 (pull request #15), front end only. The owner saw the preview pictures and said at 18:55: "Go live". Tested in preview only (sample suppliers), as Eretz Israel Tours and as an organisation, at phone and desktop size, with no page errors. Not tested on the live site.

---

## D-19 · A supplier shows what it does, not the word "Adventure"; the category is called Extreme (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 3 October 2026, 23:02, 23:05 and 23:08 Israel time.

**In his words:** "why category called adventure. Why not jeep". Offered two ways (rename the category, or show the type instead of the category), he chose: "Show the type instead of the category on a page like Eitan's, so it reads 'Guide + Jeep'", and added: "Adventure is not a real category we would use".

**Decisions:**

1. **Where the app printed "Adventure" for a supplier, it prints what the supplier does:** Jeep, ATV / RZR, Rappelling, Kayak & rafting and so on. A guide who also runs jeeps reads "Guide + Jeep".
2. **"Adventure" is not a category guides and agents would use.**
3. **The category is called Extreme.** Asked what the filter button should be called (23:08): "extreme".

**Implementation choices (not owner decisions; change on request):**

- **The type comes from the supplier's type tags** that are on the Adventure suggestion list, in that list's order. At most two are printed, then "…". A supplier with none of them still reads "Adventure".
- **Display only.** The stored category, the database, the limited-member sections and the R5 mapping are unchanged. It applies to the list rows, the supplier page, the most-used cards, the Review list and the pick lists.
- **"Extreme" is the name shown, not the name stored** (`catDisp`): on the filter button, in the form's category list and "also offers" buttons, in search (typing "extreme" finds them), in the access sheet for organisations and in the welcome tour's example. The database still holds `Adventure`, so nothing stored had to move. A supplier with no type tag reads "Extreme".

**Status:** live since 3 Oct 2026, about 23:30 (pull request #14, merged by the master agent on his "Yes merge"). Front end only. Tested in preview at phone and desktop width with sample suppliers set up like the live ones: rows, a guide's page, most-used cards, the Extreme filter, search, the form. No page errors. Not tested on the live site.

---

## D-18 · Organisations see retail prices only; transport quotes are the one exception; a guide who also runs jeeps is two entries (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 3 October 2026, 22:23, 22:34, 22:52 and 22:59 Israel time.

**In his words (22:23):** "yeshivas and outside organizers ONLY see retail pricing NEVER pricing thats agent or pricing history of any guides or others users, the only exception is transportation. they can contribute to all". On a guide's page showing an organisation "Ask for rate": "Correct. yes". **(22:34),** asked about a supplier who is listed for jeeps and also guides, whose retail price an organisation could still see: "Really I think he should be two different entries. One guide one jeep".

**Decisions:**

1. **An organisation (limited member) sees retail prices only.** Never an agent price.
2. **It never sees what a guide, an agent or another member was quoted or paid,** except for transportation (bus and van quotes).
3. **A guide's own prices stay behind "Ask for rate"** unless Eretz Israel Tours switches guide rates on for that member.
4. **Organisations can add to everything they see.**
5. **Someone who guides and also runs jeep tours is two entries:** one as a guide, one for the jeeps.
6. **A guide may still offer other services on his guide entry, and have another page for that service; the two link to each other.** (22:52) "No guide can offer those and have a link to that page." Asked whether that meant a guide entry may not tick another category, he corrected the reading (22:59): "No, what I meant to say is, Guide is allowed to offer those. He can offer other services and still have another page for that service."
7. **A business that itself offers several activities stays one entry.** (22:52) Of a supplier whose business is jeeps and rappelling: "that's what his business does. So he should remain one entry."

**What changed, and what did not:**

- **Changed (database, one helper):** with the guide-rates switch on, an organisation used to see guides' and agents' quotes for a guide as well (an implementation choice under D-15). It no longer does: `_quote_visible` now lets an organisation see a guide's or agent's quote only when it is a bus or van quote. The switch still shows a guide's listed price and retail price.
- **Already so:** agent prices, agent links, other members' own price lines, and guides' and agents' quotes for hotels, sites and activities were never sent to an organisation.
- **Done on the list (decisions 5 and 6), 3 Oct about 23:00, after his "I think so" to splitting them now:** the two entries that combined Guide and Adventure are now four. In each pair the entry that already held the history kept its id; the new one got the same contact details. Where the pair was hidden and pending, both still are. Each jeep entry points to its guide entry through the existing `parent_id` link, so the guide's page lists the jeep entry and the jeep page links back. What each entry looked like before is written in its private note.
- **App (decision 6):** the link was built for national-park sites and said "Part of" and "Sites". For any other pair it now says "See also". The "+ Add site" button shows only on a national-parks entry.
- **"Also offers" stays as it is (decision 6):** the form and the database go on letting a guide tick another category. On one of the two split guide entries the master agent had taken "also offers Adventure" off, on a wrong reading of his 22:52 sentence; it was put back at 23:00. The jeep entries do not carry "also offers Guide": a jeep page is not a guide page.
- **Still to do:** the new guide entry carries neither "Licensed tour guide" nor "Specialty guide", and its Eshkol tag has no "D1 license" (D-16): someone who knows has to mark it.

**Implementation choices (not owner decisions; change on request):**

- **"Pricing history" was read as quotes and members' own price lines.**
- **What organisations add themselves is still shown to other organisations** (organisation rates and quotes), as he decided in D-15 ("everyone can see including them"). If "others users" was meant to include other organisations, that is one more line to change.
- **"They can contribute to all"** was read as what D-15 already allows: suppliers in their sections, quotes, reviews, rates, photos. No change.

**Numbering:** D-17 is kept for the parked AI assistant (recorded as a second D-6 on the branch `ask-assistant`).

**Status:** the database line is live since 3 Oct 2026, about 22:45. Connector migration `org_retail_only_2026_10_03d`; file `supabase/migrations/2026-10-03d_org_retail_only.sql`. It was applied by the master agent on its reading of the 22:23 rule, before the owner had been asked about that specific line; he was told at once and said at 22:34 to push the records. No terms change (2c already says only bus and van quotes). Checked before applying: production equalled `main` in all 137 functions. Checked after: production equals the tested copy in all 137 functions; `_quote_visible` is not callable from outside; 0 table grants. `run.sh`: 98 passed, 0 failed (two checks added). No organisation has joined yet, so nobody saw the earlier behaviour.

---

## D-16 · Licensed guides only, D1 for Eshkol, malicious posts (database live; app waits for the owner's merge)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 3 October 2026, 21:41 Israel time.

**In his words:** "add to all relevant places that the rules is only licesned guides are allowed to be used except for specialties like shuk tours, or graffiti tours etc.  any malicious post will be removed and used will be banned.  only drivers with a D1 license will be allowed to be listed as an eshkol driver/guide"

**Decisions:**

1. **Only licensed guides are used**, except specialties such as shuk tours or graffiti tours.
2. **A malicious post is removed and its author is banned.**
3. **Only a driver with a D1 license is listed as an Eshkol driver or guide.**

**Implementation choices (not owner decisions; change on request):**

- **Stated with tags, not checked against a license.** `Licensed tour guide` or `Specialty guide` on a guide; `D1 license` next to any Eshkol tag. The form and the database both ask.
- **A specialty guide is an exception Eretz Israel Tours approves**, the way "Kosher, no certificate" is.
- **Entries already on the list are not blocked** from other edits and are not marked. Going through them is still to do.
- **"All relevant places"** was taken as: terms 3a and 3c, the welcome tour's house rules, the supplier form, the Review tab, the note box, the driver review form, the job form and "Jobs I take". A new job starts with "Licensed guide" ticked; the poster can untick it for a specialty.
- **"Banned" is done by hand:** Eretz Israel Tours removes the post and revokes the member in the Team tab. Nothing detects a malicious post.

**Status:** the rule in `vendor_save` is on production since 3 Oct 2026, about 22:00. The form, terms `2026-10-03d` and house rules go live when the owner merges `guide-for-clients`. Until then the live form does not offer the two buttons, so a new guide entry is refused unless the tag is typed by hand.

---

## D-15 · Limited members: organisations that are not in tourism (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 3 October 2026, over several messages: the idea, the rules, a mock-up of six phone screens, then the go-ahead to build and go live.

**In his words:** "Is there's an option to create a partial version of the app for people not fully in tourism, but use buses and hotels, like people that run yeshivas, so they won't see the site listings. But they'll see transportation and hotels". Then: "Don't show them hotel rates. But show them guides. Or rather give admin the option to choose what they see with transportation and guides as the default". Then: "they can add suppliers and quotes. Also, let them see sites and activities, but don't give them access to any agent rate pricing or reviews. But allow them to leave reviews. They can also see restaurants, wineries, but no agent rates." Then: "Add hotels but don't give them agent rates. Give them an option to add agent rates that everyone can see including them?" On reviews: "Let reviews be on for transportation" and "Make sure their reviews show up for everyone even limited access people". On proof: "Let them write their credentials as proof in free text". On the mock-up: "Build it and make it live".

**Decisions:**

1. **A limited kind of member**, for people who are not in tourism but book busses, guides and hotels for a school, a yeshiva or another organisation.
2. **Eretz Israel Tours chooses, per member, which sections of the list they see.** The standard set is Transportation, Guides, Hotels, Sites and activities, Restaurants and wineries.
3. **A limited member never gets an agent rate**, hotels included. They see listed prices.
4. **They do not read guides' and agents' reviews, except on transportation**, where reviews are on.
5. **They can leave reviews, and their reviews show for everyone**, other limited members included.
6. **They can add suppliers and quotes.**
7. **They can add the rates they were given, and everyone sees those rates**, them included.
8. **To join, they write their credentials in free text.** No license number and no upload.

**Implementation choices (not owner decisions; change on request):**

- **"The rates they add" are called organisation rates, not agent rates.** A rate a school or yeshiva was given is not an agent rate, and a limited member must never be sent one. Their lines are stored as their own kind, never marked as agent, and shown in their own block ("Organisation rates: what schools, yeshivas and other organisations were charged").
- **An organisation rate saves straight away, without approval.** A guide's suggested price still waits for Eretz Israel Tours. The organisation's own line is only changed or removed by them or by Eretz Israel Tours.
- **Rates and quotes from organisations show without a name; reviews show the person and the organisation**, the way a guide's note shows his name. Eretz Israel Tours sees who added everything.
- **Six sections:** Transportation; Guides; Hotels; Sites and activities (Attraction / Site, Activity, Adventure, National Parks); Restaurants and wineries; Agents and other (everything else, off in the standard set). A supplier that offers several things shows if any of them is in the member's sections.
- **Four switches per limited member**, with these defaults: bus and van quotes shown (also opens booking sheets); guide rates hidden (a guide's price shows as "Ask for rate"); transportation reviews shown; reviews elsewhere hidden.
- **Where reviews are hidden, so are the supplier's summary ratings, strengths, weaknesses and notes**, which are written by guides and agents. Notes copied from the supplier's own website stay.
- **Guides' and agents' quotes:** a limited member sees bus and van quotes with that switch, guide quotes with the guide-rates switch, and never a guide's or agent's quote for a hotel, a site or an activity.
- **Organisations' quotes are left out of the averages guides and agents see** in the quote tracker, and shown tagged "From an organisation".
- **Files:** a limited member sees photos, kosher certificates, what he uploaded and what other organisations uploaded. Not price lists, receipts, contracts, booking confirmations or quotes from guides and agents.
- **No Jobs tab** for limited members: they are never offered a job and never appear in the list of people a job fits.
- **Enforced in the database**, not only hidden in the app: a supplier outside the member's sections is refused by every function, and agent fields are never sent.
- **Stored as role "Other" with the organisation's name**; the app shows "Organisation, not in tourism". The list of allowed roles in the database was left as it is.
- **Every existing member stays a full member.** Any member can be switched between full and limited in the Team tab ("Change access").
- **Terms** `2026-10-03c` add section 2c (organisations) and a line in section 6. Every member accepts again on next opening.

**Clash to settle before the branch `guide-for-clients` goes live:** The branch `guide-for-clients` (D-12 a guide's page for clients, D-14 claimed pages, disputes and reviews; built, not live) was written at the same time, from the code as it was before this change. Its two database files (`2026-10-03b_guide_for_clients.sql`, `2026-10-03c_claims.sql`) replace six functions that now carry the limited-member rules: `_vendor_view`, `vendor_detail`, `vendor_save`, `note_add`, `_driver_json` and `driver_review_add`. Its versions do not have those rules. Run on production as they are, they would send agent prices and guides' reviews to limited members. Before either file is run: bring the branch up to date with `main`, rewrite those six functions on top of the current ones, and repeat the limited-member probe on production. Its terms version is also `2026-10-03b`; it needs one later than `2026-10-03c`. Nothing from that branch is on production (checked 3 Oct, 21:50: no `vendor_set_client`, no `vendor_claim`).

**Settled 3 Oct 2026, about 22:00:** the two files were never run. The branch was brought up to date with `main`, the six functions were rewritten on top of the limited-member versions (through `_note_visible` and `_vendor_for`, where the rules now live), and the three files became one, `2026-10-03c_guides_claims_reviews.sql`. It was probed locally as two organisations and on production (rolled back) before and after applying. Its terms version is `2026-10-03d`.

**Left as it was (known, small):** the function that asks to remove a price line (`price_delete`) was not changed. It works by the line's internal id, which a limited member is never sent for an agent line.

**To check with a lawyer:** terms 2c; the credentials text is personal data now stored; showing what one organisation paid to others.

**Status:** live since 3 Oct 2026, about 21:40. Database change on production (connector migrations `limited_members_2026_10_03b_part1_columns_helpers`, `_part2_rpcs`, and `_part3_decision_number`, which only corrects two comments), `files` function v11 deployed (v10 at go-live; v11 corrects a comment), code on `main`. Tested on a local database (74 checks as an organisation, a guide and Eretz Israel Tours; guides' and Eretz Israel Tours' results unchanged), in a browser against that database, and by a rolled-back probe on production; see README. Not yet tried on the live site by a person.

---

## D-14 · Claimed pages, disputes, reviews hidden from the person they are about, approval of a guide's review of a guide, private reviews (database live; app waits for the owner's merge)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 3 October 2026, 21:15 and 21:25 Israel time.

**In his words (21:15), answering whether any member may fill in a guide's page:** "no - An unclaimed entry can have their info written in including their retail charge - when someone joins they can claim their entry - and ask to dispute their info. reviews should be blocked from them but available for others. that includes all users that also have a vender file." **(21:25):** "also guide reviews about other guides needs admin approval to go live. there should be a keep private option for reviews if it doesnt already exist".

**Decisions:**

1. **An unclaimed entry can be written in by others, retail price included.**
2. **A member can claim his own entry.**
3. **He can ask to dispute the information on it.**
4. **Reviews of an entry are blocked from the member it belongs to, and available to everyone else.** This covers every member who also has a supplier entry, not only guides.
5. **A guide's review of another guide needs approval by Eretz Israel Tours before it shows.**
6. **Reviews can be kept private.**

**Implementation choices (not owner decisions; change on request):**

- **"Reviews" means** the ratings, strengths, weaknesses and notes fields of a page, its notes thread, and driver reviews. It does not include quotes and prices colleagues recorded from that supplier.
- **A claim needs approval by Eretz Israel Tours**, who can also link a page to a member directly. One member per page.
- **A page that carries a member's own phone or email counts as his even without a claim**, for hiding reviews only. Otherwise a member could keep reading his reviews by not claiming.
- **Once a guide has claimed his page, only he and Eretz Israel Tours write the section for clients.** Other fields are edited as before, and he disputes what he disagrees with.
- **He cannot rate or note his own page**, or review himself or his company's drivers.
- **"A guide"** is a member whose role is Licensed tour guide, or who has claimed a guide's page. **"A review of another guide"** is a note on a guide's page, or a change to its ratings and remarks. A driver review is not included.
- **A note turned down** stays visible to its author and Eretz Israel Tours, marked "Not approved".
- **Private** exists for notes and driver reviews. Eretz Israel Tours sees private ones (house rule 4). A private note skips approval.
- **A dispute** arrives with the supplier updates in Review, marked as coming from the page's owner.
- **Where this meets limited members (D-15)**, chosen by the two sessions, the owner to say if he wants otherwise: a guide's retail price follows the organisation's "guide rates" switch (off by default, so it is not sent); an organisation does not write a guide's section for clients and does not claim a page; an organisation's review shows at once and never waits for approval, and it may keep one private; the owner of a page sees no notes on it, organisations' included.

**To check with a lawyer:** terms 6f. A member is told that remarks about him exist and are kept from him; under privacy law a person may have a right to see information held about him.

**Status:** the database change is on production since 3 Oct 2026, about 22:00, rebuilt on top of limited members (D-15); see README. The app code (terms `2026-10-03d`) goes live when the owner merges `guide-for-clients` into `main`. His go-ahead, 21:41: "yes add changes". Tested on a local database (96 checks with the limited-member ones), in preview mode as five kinds of member, and by two rolled-back probes on production.

---

## D-13 · Food nearby only on entries with a physical address (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 3 October 2026, 21:16 Israel time.

**In his words:** "food nearby is only on entries with a phsical address not a service provider like guide, rappeling, jeep, bus etc."

**Decision:** the Food nearby section belongs to places, not to service providers.

**Implementation choices (not owner decisions; change on request):** "a place" is decided by category (Hotel, Restaurant, Winery, Attraction / Site, National Parks), plus Activity and Other unless the entry is tagged jeep, ATV / RZR or rappelling. The whole Adventure category counts as a service provider. Tips already saved on service providers stay in the database, unseen.

**Status:** front end only; live since 3 Oct 2026 (pull request #8 merged).

---

## D-12 · A guide's page for clients: bio, up to four pictures, retail price (database live; app waits for the owner's merge)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 3 October 2026, 20:45 Israel time.

**In his words:** "Every guide should have a client-facing bio and place to put up to four pictures. And an option to add their retail price. in a free text."

**Decisions:**

1. **Every guide has a bio written for clients.**
2. **Up to four pictures.**
3. **A retail price, optional, in free text.**

**How it was read:** confirmed by him at 21:15 ("1. correct"): "every guide" was taken as every supplier in the Guide category, on that supplier's page, because that is where colleagues look a guide up. It was not built on members' own profiles; a guide who is a member fills in his own page on the list. "Client-facing" was taken as material a colleague sends to his client, not a page a client opens by himself.

**Implementation choices (not owner decisions; change on request):**

- **Who fills it in:** first built as any approved member; he said no to that at 21:15. Now anyone while the page is unclaimed, and only the guide and Eretz Israel Tours once it is claimed (D-14).
- **These three things may leave the list**; everything else on the page stays between colleagues. Terms 6e says so. This is a deliberate exception to "never show the list to anyone outside".
- **The retail price follows "Keep this supplier's prices private"**: colleagues then neither see it nor change it.
- **Copy bio** copies the name and the bio, not the price, so a colleague who adds his own margin is not undercut by his own message. **Share with a client** uses the phone's share sheet.
- **Pictures:** JPEG, PNG or WebP; never a file marked "only me". They sit with the supplier's other photos, marked "for clients".

**To check with a lawyer:** terms 6e; pictures of people, and of guides who are not members, passed on to clients.

**Status:** the database change is on production since 3 Oct 2026, about 22:00, rebuilt on top of limited members (D-15); see README. The app code (terms `2026-10-03d`) goes live when the owner merges `guide-for-clients` into `main`. Tested on a local database, in preview mode, and by a rolled-back probe on production.

---

## D-11 · Jobs between colleagues, and My days (live; any colleague may post a job, since corrected 19 Oct 2026)

**Correction, 19 October 2026 (the owner, verbatim):** "anyone can share jobs". The setting on production is `jobs_for` = `all` (read 19 Oct): every approved full member sees, answers and posts jobs and marks days. Organisations (limited members) still have no Jobs tab and cannot post (C4; `_jobs_post` leaves them out). No app change was needed; only the records said "only Eretz Israel Tours posts". When it was switched to `all` is not in the records; the owner confirms it as it stands. Whether a job is ever charged for is still his open decision.

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, 17:16 Israel time (the idea) and 3 October 2026, 20:02–20:47 (the mock-up, the go-ahead to build, and the go-ahead to go live).

**In his words:** "I would like to have an option, starting with myself and later with other people, to have anonymous requests for tour guides or other providers that might be on the site. The price will be listed, as will the details of the job. Each participant will get a notification or perhaps I will get to choose from a list of relevant guides based on the filters. It will be sent to them by WhatsApp or by a notification from the app." On availability: "if I had Google Calendar integration for the people in the app so I could see at a glance their availability and they can share their availability." On the mock-up (3 Oct, 20:13): "it looks good. Is there other calendar integration that makes sense outside of Google calendars? Is there an easy way for them to update their calendar availability?" On the suggestion to build tap-and-automatic availability and an "Add to my calendar" button now, and a pasted calendar link later (20:19): "OK let's do that. I'll take your suggestion". On the preview (20:47): "Looks good. Let's make it live for beta version. Make it live for me".

**Decisions:**

1. **Members can post jobs for colleagues, anonymously, with the price and the details listed.**
2. **It starts with Eretz Israel Tours and opens to others later.**
3. **A job goes either to everyone it fits or to people the poster picks from a filtered list.**
4. **Availability is kept by tapping days, and filled in automatically when a job is given.** Jobs can be added to the member's own calendar. Reading members' calendars through a pasted link comes later.
5. **Build it in preview first, to try before it goes live.**
6. **Live as a beta, for Eretz Israel Tours only** (3 Oct, 20:47). Colleagues do not see it until he changes the setting.
7. **Colleagues receive jobs; only Eretz Israel Tours posts.** He changed the setting himself in the Team tab later on 3 October, and confirmed it on 3 October at 22:05 when asked "should colleagues already receive jobs?": "yes".

**Not decided yet (his to decide):**

- **Whether the app ever takes a cut of a job.** He wrote "I have to make a decision: whether I will use this as an opportunity to monetize by taking 5% of any booking that comes to the site or 10%. Research needs to be done." The research (Claude Doc "Inner Circle monetization research", 2 Oct) advises neither, and flat fees paid first by suppliers. He has not answered in his own words. He was asked about the line "Nothing is charged on a job" in terms 6d and answered "Looks good. Let's make it live". To keep his decision open, the line went live as "As of now, nothing is charged on a job", the wording the welcome tour already uses for joining.
- **Whether founding members stay free for every later paid feature**, or only for the list.

**Implementation choices (not owner decisions; change on request):**

- **WhatsApp is a message the poster shares himself**, not one the app sends. Members' phone numbers are never given to other members (standing rule), and the app has no WhatsApp sending service. The share screen warns that sending it himself shows who posted.
- **Name and phone pass between poster and taker only when the job is given.** This is a consented exception to the no-phones rule, stated in terms 6d.
- **A "Jobs I take" profile** (kinds of jobs, what the member has, languages) decides who a job fits. An empty profile fits everything.
- **Three levels in the Team tab** (`jobs_for`): only Eretz Israel Tours; colleagues receive; everyone posts. The default is the first.
- **Answers are "I'm available", "Not for me" and "I'm busy that day".** The poster chooses among those available; the first to answer does not win automatically.
- **Days shared by default**, with a switch to stop; colleagues see free or busy only, never why. A "still right?" prompt after 21 days.
- **Eretz Israel Tours sees who posted each job**, in line with D-2 and house rule 4.

**To check with a lawyer:** terms 6d; members' availability is personal data now stored; if a job is ever charged for, the payment-services and tax points in the research.

**Status:** live since 3 Oct 2026, 21:04 (terms `2026-10-03a`), at first for Eretz Israel Tours only. Since later the same evening colleagues receive jobs and Eretz Israel Tours posts (`jobs_for` = `receive`, set by the owner; decision 7). The session that built it was not allowed to push to `main` or to apply SQL containing DELETE, so the owner merged pull request #7 and ran `supabase/migrations/2026-10-03_jobs_last_step.sql` in the SQL editor himself. Checked afterwards on production: 107 functions, all as tested, and the whole flow passed in a rolled-back probe; see README.

---

## D-10 · Official WhatsApp, Waze and Google Maps buttons (asked for; logos not yet in)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026 ("the Waze and Google Maps and Whatsapp buttons should be official") and 3 October 2026, 19:28 Israel time ("I want the official buttons").

**Decision:** the WhatsApp, Waze and Google Maps buttons on a supplier page should be the official ones.

**What the brand owners' own pages say (read 3 Oct 2026):**

- **WhatsApp (Meta):** publishes a logo pack and a ready-made "Chat on WhatsApp" button, with the rule to use them as supplied and unchanged.
- **Google Maps:** creatives that include the Google Maps trademark or logo "must be reviewed and fully approved by Google's brand team". Without approval, Google welcomes a text button such as "Open with Google Maps".
- **Waze (a Google brand):** the rules sit behind a sign-in on Google's Partner Marketing Hub and were not read.

**Done (live 3 Oct 2026):** the buttons carry the owners' wording ("Chat on WhatsApp", "Open with Google Maps"; "Navigate with Waze" is our own), the short label "Maps" is now "Google Maps", and each button shows the brand owner's own logo file as soon as it is put in the `brand/` folder of the repository. No code change is needed then. File names, sources and rules: `brand/README.md`.

**Not done, and why:** no logo is on the buttons yet. The session does not draw other companies' logos, its workspace cannot download from Meta's or Google's sites, and no browser on the owner's computer was reachable. The Google Maps logo (and probably Waze) also needs Google's approval first.

**Implementation choices (not owner decisions; change on request):** logos show at 22 px on the existing small buttons, unchanged in colour; a plain line icon stays until a file is present; redrawn or icon-site versions are not accepted.

---

## D-9 · Hours pulled from websites are unverified until checked in person or by phone; last entry times (approved; live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, 16:58–17:20 Israel time.

**In his words:** asked whether to look up published opening hours and fill them in marked "to verify": "Yes". Then: "I thought I'm on automatic. If you're searching the websites, I give you access to search the websites under this session. Aside from that, you should be scraping for pricing and any other relevant information." And: "mention that these are unverified and have a check box for people to verify them, but not by verifying on their website, either by speaking to them or being there. And some places have last entrance times that should be added. Masada has a last cable car up, last cable car down, earliest time to … climb the snake path, etc."

**Decisions:**

1. **Published hours are pulled from suppliers' websites and written into the list**, without asking him supplier by supplier.
2. **They are shown as unverified**, with a tick for members to verify them.
3. **Verifying means speaking to the supplier or being there.** Checking the website is not verification.
4. **Last entry and similar times get their own place** (last cable car up and down, when the Snake Path opens, and so on).
5. **Published prices and other relevant information are pulled the same way.**

**Implementation choices (not owner decisions; change on request):** the verifier's name shows next to the tick (standing "From [name]" rule); the verifier or Eretz Israel Tours can undo; changing the hours clears the tick; when a supplier's own site has no hours a third-party listing is used and labelled as such; pulled prices are stored as public (not agent) price lines with their source and date.

**Status:** live since 2 Oct 2026, about 17:40. The lookup for the remaining suppliers, prices and other details continues in the same session.

---

## D-8 · Opening hours; "Kosher, no certificate" only as an approved exception (approved; live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, 16:36 Israel time.

**In his words** (answers to three questions): should the kosher field be required for restaurants: "No". Is "Kosher, no certificate" acceptable: "No, with some exceptions. Needs review from admin". Opening hours added: "Yes".

**Decisions:**

1. **Suppliers get opening hours.**
2. **A restaurant that is kosher without a certificate is not accepted, except as an exception that Eretz Israel Tours reviews.**
3. **The kosher field stays optional for restaurants.**

**Implementation choices (not owner decisions; change on request):** hours are free text with tap-to-add buttons, editable by any member without approval; the kosher rule is enforced in the database as well as the form; a colleague's "Kosher, no certificate" on an existing restaurant becomes a change request; the rule covers a supplier whose main or extra category is Restaurant, not hotels or wineries without that category.

**Status:** live since 2 Oct 2026, about 16:50. Database change applied to production through the Supabase connector (the owner's "Yes" to opening hours, after being told it needs a new database field).

---

## D-7 · Shomer Shabbat badge; kosher restaurants only (approved; live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, 16:28 Israel time.

**In his words:** "I want a button on a vendor if they are Shomer Shabbat. And in the terms, we do not accept non-kosher restaurants."

**Decisions:**

1. **A supplier can be marked Shomer Shabbat**, and it shows on the supplier.
2. **The terms say the list does not accept non-kosher restaurants.**

**Implementation choices (not owner decisions; change on request):** Shomer Shabbat is a supplier tag any colleague can set, with a badge in the list and on the page; the form refuses a Restaurant marked "Not kosher" or "Kosher-style (not certified)" ("Kosher, no certificate" is still accepted); the rule also covers Food nearby tips; a restaurant with no kosher value is still accepted.

**Also asked, not decided:** whether suppliers have opening hours. They do not; no field exists.

**Status:** live since 2 Oct 2026, about 16:45. Front end only.

---

## D-6 · Welcome tour, the name "The Inner Circle – Israel Guide", and the use-and-add rule (approved; live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, 15:45–16:20 Israel time.

**In his words:** "Create a first time log in of the app and it's functions. For first time users." Then, after a mock-up: "Add that we're currently working on AI integration. This is a project that's meant to help everyone. And it is not for pay. But everybody needs to contribute. We're currently working on an AI chat box integration to help for searches. Although that will cause cost Eretz Israel tours money. We will not be rolling that fee over. As this is for the greater good … Show the booking sheet and explain its use … I would like to come up with a policy that users that are … inactive or only use but don't contribute will be removed from the app." On cost: "as of now nobody pays to join nor will you be asked to pay in the future If at any time we do decide that it's not worth it to bear the costs, founding members will be free." On the name: "OK go. With the inner circle Israel guide official name." And: "Also they need to use and contribute."

**Decisions:**

1. **A welcome tour inside the app** for first-time users, shown as a mock-up first (his choice of two), then built.
2. **The official name is The Inner Circle – Israel Guide.** It replaces "Israel Suppliers Master List".
3. **Not for pay.** As of now nobody pays to join, and members will not be asked to pay in the future. If the costs are ever not worth bearing, founding members stay free.
4. **A founding member is anyone approved while the list is still free** (his choice of three: everyone before a fee / the first 300 / leave undefined).
5. **Every member has to both use the list and add to it.** A member who has not done both for **3 months** (his choice of 3, 6 or 12) is removed.
6. **The AI chat box for searches is announced as in the works**; Eretz Israel Tours pays for it and does not pass the cost on.
7. **The tour shows the booking sheet and explains its use.**

**Implementation choices (not owner decisions; change on request):** a reminder goes out before removal (proposed in the mock-up, which he approved as shown); the tour is remembered per device, not per member; Skip lands on the house rules; the name is shown as "The Inner Circle" with "Israel Guide" under it; the web address stays vendors.eretzisraeltours.com; the tour is in English only.

**Raised by the owner and not decided:** charging later ("perhaps first 300 users are free, and after that a one-time or a monthly fee"), and marketing the app in other countries. Advice given in the session: do not charge now; revisit with real numbers on members and AI cost. No fee, payment or licensing work is authorised by this decision.

**To check with a lawyer:** terms 2a (removal for not using or not adding) and 2b (the promise to founding members). No trademark search was done on the name.

**Status:** live since 2 Oct 2026, about 16:35. Front end only. The rule in decision 5 has no tooling yet: see README "Welcome tour, new name, use-and-add rule".

**Update, 3 October 2026, 21:21 (the owner):** "with new additions from tonight the first time sign in tour needs to be edited". The tour was brought up to date with Jobs and My days (D-11), opening hours and their verification (D-8, D-9), the Shomer Shabbat badge and the kosher rule (D-7), and a guide's page for clients (D-12). **Implementation choices (not owner decisions; change on request):** the Jobs screen shows only to members who have the Jobs tab; the clients paragraph shows only once that feature is in the app; members who already took the tour are not shown it again. In a pull request from branch `tour-update`; live when he merges it. Details in the README.

---

## D-5 · Booking sheets for buses and vans (approved; live for all colleagues)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, 14:15–14:31 Israel time.

**In his words:** "a booking sheet for buses and van services for tour guides … very simple with name, date of booking, outline of the day, pick up, drop off, location, time, destination. And then for the bus company to fill in conditions and terms such as extra charge for Highway 6, extra charge for mileage, extra charge for overtime, expected tip, so guides can protect themselves from being gouged. Nothing that looks too formal or too complicated." Then: "Also write it in Hebrew and English." Then, after three mock-ups (WhatsApp message, paper form, phone form): "I like number three. The form has to be filled in digitally. And there could be an option to send a printable PDF. But the guide should be able to fill in his part digitally … it will have autofill options that could be sent to a driver who could fill it in and send it back. They could send it through my site or through WhatsApp." And: "also have a box for free text."

**Decisions:**

1. **A digital booking sheet in the supplier app**, modelled on the phone-form mock-up: the guide fills in the job, the company fills in price and terms.
2. **Hebrew with English under each line.**
3. **Autofill** for the guide, and the company gets the expected terms filled in.
4. **Sent through the site or WhatsApp**, and a **printable PDF**.
5. **A free-text box** on both halves.

**Added by the owner the same afternoon (15:16 and 15:20):**

6. **Dates in Israeli order**, day / month / year.
7. **Open to everybody now**: "I think a live version for everybody is fine right now."
8. **An accept button for both sides.**
9. **A cancellation policy** the company can copy and paste into a text box; **a warning if it opts out** of filling it in.
10. **Anything either side changes before acceptance comes back in red for approval.**
11. **Emails**, "if that's easy to create": a copy by email when the sheet goes out to the driver, and an email to the guide when they respond. Not built yet: it needs an email-sending service the owner has to choose and set up.
12. **For the future, not now:** the guide or tour agency can put in its own terms, "such as if driver is late, if bus is dirty".

**Offered as choices and not picked by the owner, so the recommended defaults were used (his to change):** the company answers through a one-booking link (a plain WhatsApp message with blanks is the fallback); a confirmed sheet feeds the Quotes tab without the guide's name, the same rule as D-2.

**What follows from it (implementation choices, not owner decisions):** visible to Eretz Israel Tours only until he opens it to colleagues in the Team tab; the company's link key is stored readable so the same link can be re-sent; the sheet locks on confirmation; the closing line "Anything not written here will not be charged"; no terms change yet (a first-use explainer instead).

**Research behind the fields (2 Oct 2026):** charter operators abroad quote a base rate (vehicle, driver, fuel, insurance) and bill tolls, parking, overtime, driver lodging and tip separately; Israeli price lists quote a day as hours plus km with an extra-hour rate; one Israeli guide says a quote must state waiting hours, the extra-hour rate, and whether Kvish 6 and parking are included; one company's list charges the km back to the starting point. Published tip norms vary, so the sheet makes the company state it.

**Boundary with D-1 unchanged:** a booking sheet is between a guide and a supplier. It carries a private trip label, no Cockpit id, and nothing is exported.

**Status:** first step live since 2 Oct 2026, about 15:09 (the owner ran the database change himself in the Supabase SQL editor after the approval prompt failed to reach him twice). Items 6–10 are live: the owner ran `supabase/migrations/2026-10-02d_bookings_accept.sql` at about 15:40, which also opened booking sheets to all approved colleagues. Item 11 waits for his choice of email service. Item 12 is parked.

---

## D-4 · Transport organised by vehicle size (approved in principle; ranges proposed)

**Decided by:** the owner (Eretz Israel Tours), 2 October 2026, 13:53 Israel time.

**In his words:** "we need to organize transportation better. A transportation company can offer buses, vans, and smaller cars. Vans should be organized by size, eight seater, nineteen, nineteen passenger, twenty five passenger, thirteen passenger. I think those are the numbers. Maybe do research about what are typical passenger numbers in vans."

**Decision:** a transport company lists what it offers as buses, vans by size, and cars.

**Size ranges (proposed from research, not yet confirmed by the owner):** Bus 36–60 · Midibus 21–35 · Van 17–20 · Van 11–16 · Van 9–10 · Van up to 8 · Car up to 4 passengers. His 8 / 13 / 19 / 25 fall in: up to 8, 11–16, 17–20, and midibus (a 25-seater is sold as a midibus, not a van). Sources and reasoning are in README "Transport organised by vehicle size".

**Status:** live since 2 Oct 2026. Ranges still to be confirmed by the owner.

---

## D-3 · Driver reviews keyed by phone number; "bus", not "coach" (approved)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, 13:07 Israel time.

**In his words:** "Call them busses not coaches. Have reviews for drivers with phone numbers to add to confirm same driver. Drivers of busses for the companies and van drivers."

**Decisions:**

1. The app says **bus**, not coach.
2. **Drivers can be reviewed**: the bus companies' drivers and van drivers.
3. **The phone number identifies the driver.** It is entered so colleagues can confirm it is the same driver.

4. **Bus drivers are listed under their bus company, as a sub tab** ("because some are contracted by bus company"). Owner, 13:26.
5. **Adding a driver starts with a pop-up: van driver, or driver for a bus company?** It leads either to the independent van driver's own page or to the Drivers sub tab of the company. Owner, 13:26.
6. **Reviews take free text as well** as the tap buttons. Owner, 13:20.

**Implementation choices (not owner decisions; change on request):** an independent van driver's "own page" is a Transport supplier tagged `Independent van driver`; one driver per phone number across all suppliers, with reviews following him; reviews show the reviewer's name and role, in line with the standing "From [name]" rule (quotes are the only anonymous item, per D-2); a rating from 1 to 5 is required, tags and text optional; the author or Eretz Israel Tours can delete a review.

**To check with a lawyer:** drivers are individuals who are not members. Their names, work numbers and colleagues' reviews are now stored.

**Status:** live since 2 Oct 2026.

---

## D-2 · Quote tracker: quotes shared without names (approved)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, about 12:50 Israel time.

**The request, in his words:** "I want all of the consumers, meaning tour agents, tour guides, to be able to, at a glance, see what a bus company or van drivers are charging per hour, per day. Was it high season, which is August, December? or Chol Hamoed. I think the most important function is clarity on quotes for those service providers." Also: its own tab, the average quote, and "warnings that they threw extra fees at me for mileage hours etc Kvish 6".

**Decisions:**

1. **Quotes feed a shared Quotes tab, anonymously by default.** New quotes show prices, fees, dates and supplier to all members, never who got it, the client or the private note. The owner of a quote can switch sharing off. (His choice of three options: anonymous by default / opt-in only / shared with names.)
2. **Eretz Israel Tours sees who got each quote** ("But I want to see who got the quote"). Colleagues do not. If he later wants every member to see names, that is a new decision and a terms change.
3. **High season** is August, December and the weeks of Pesach and Sukkot (Chol HaMoed), taken from the quote's dates.

**What follows from it (implementation choices, not owner decisions):** an average needs 3 quotes; quotes on private-price suppliers are never shared; attachments are never shared; terms get section 6b and members re-accept.

**Boundary with D-1 unchanged:** these are reference quotes with no client or trip details shown to colleagues. Trip quotes for real clients stay in the Cockpit. No Cockpit-facing fields or exports were added.

**Status:** live since 2 Oct 2026. The owner ran the database change himself in the Supabase SQL editor at about 14:09, after the approval prompt failed to reach him four times.

---

## D-1 · Vendor Master / Cockpit boundary (approved)

**Decided by:** Daniel (Eretz Israel Tours), in the Vendor Master Claude session, 1 October 2026, about 16:20 Israel time.
**Evidence:** Independent Reviewer return `EIT_VENDOR_MASTER_REVIEWER_RETURN_2026_10_01.md`, Drive file id `1FmgByjj2GQG8o2BvPNkTgvCTePqgr2-0`, in the Builder's Cockpit control folder. The return authorises nothing by itself; this decision is Daniel's.

**The boundary (reviewer's wording, approved as written):**

> Vendor Master is the canonical source for reusable supplier identity and dated reference evidence. The Cockpit is the canonical source for trip-applied supplier costs and trip quote state. The Cockpit may later read Vendor Master data one-way and offer it to Daniel; applying a price creates a trip-local snapshot with provenance. No Vendor Master change may silently alter an existing trip.

**Owner clarification (Daniel, 1 October 2026, 16:27 Israel time), in his words:**

> Yes — I approve the boundary: the Vendor Master is the source for reusable supplier identity and dated reference prices; the Cockpit is the source for trip-applied prices and trip-specific quotes. Any later Cockpit use of Vendor Master data is one-way and user-triggered; applying a price copies it into the trip with provenance, and later Vendor Master changes never silently alter that trip.
> No active R5 use — keep the R5 export as legacy/backup only and do not develop it further.

**What this means here:**

- The two apps stay separate. There is no shared database and no periodic batch copy.
- This app keeps every price line dated and sourced (`source`, `checked_on`, `updated_at`). A newer price is added or edited here. It never reaches into a trip.
- Trip quotes for real clients stay in the Cockpit. Quotes here are reference only and carry no client or trip details.
- The R5 export is **frozen as a legacy backup tool**: no more work on it. It is not the integration path. Daniel confirmed he has **no active R5 use**.
- **Not authorised by this decision:** any integration code, new cross-system ID fields, or export formats aimed at the Cockpit. The first integration work, when separately authorised, is a supplier identity map plus a written contract and verifier. Those come only after v4.97 is deployed and v4.98 is closed.
- Not touched: the Cockpit's frozen v4.97 deployment path and its authorised v4.98 closure work.

**Recorded on the Vendor Master side:** this file, `docs/STATUS.md`, the README "Change rules", and the updated `docs/PROJECT_BRIEF.md` (section 8).
**For the Cockpit side (Steward's job, not done from here):** record the decision in the owner authorisations log, and add the thin cross-system status pointer to the Cockpit control folder.

**Follow-ups Daniel approved in the same decision, done 1 Oct 2026:**

1. Database structure saved in the repo (`supabase/schema.sql`) and edge-function source (`supabase/functions/files/index.ts`).
2. Status file for the Steward (`docs/STATUS.md`).
3. R5 export frozen and relabelled "Legacy R5 export (backup only)" in the Review tab.
4. Brief and skills list updated (`docs/PROJECT_BRIEF.md`).
