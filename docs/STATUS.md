# The Inner Circle – Israel Guide: current status

*Called the Israel Suppliers Master List until 2 October 2026 (D-6).*

*Short, factual status for the Cockpit Steward and other EIT projects. Updated by the Vendor Master session after any change that matters to them. The commit that last changed this file is its version.*

**As of:** 7 October 2026

## Identity

| | |
|---|---|
| App | https://vendors.eretzisraeltours.com (and `/b/?k=…`, the one-booking page a bus or van company sees) |
| Repo | `Danielg972/eit-vendors`, branch `main` (cite by commit SHA) |
| Database | Supabase project `wjuqtjlrtcywjaspjpwu` (org "EIT Vendors", Frankfurt) |
| Schema record | `supabase/schema.sql` (tables, functions, grants), plus `supabase/functions/files/index.ts` (edge function v11) |
| Terms version | `2026-10-03c` live (adds 2c, organisations as limited members; `2026-10-03a` added 6d, jobs). `2026-10-03d` on the branch `guide-for-clients`: 3a malicious posts, 3c licensed guides and D1, 6e a guide's page for clients, 6f your own page and reviews. All draft, not yet reviewed by a lawyer |
| Decisions | `docs/DECISIONS.md` (D-1 Cockpit boundary; D-2 quote tracker; D-3 driver reviews; D-4 transport by vehicle size; D-5 booking sheets; D-6 welcome tour, name, use-and-add rule; D-7 Shomer Shabbat badge, kosher restaurants only; D-8 opening hours, no-certificate needs approval; D-9 verified hours, last entry, hours from websites; D-10 official buttons; D-11 jobs between colleagues and My days, live for Eretz Israel Tours only; D-15 limited members: organisations that are not in tourism; D-13 food nearby only on places; D-12 a guide's page for clients; D-14 claimed pages, disputes, reviews; D-16 licensed guides only, D1 for Eshkol, malicious posts) |

## Integration with the Cockpit

| | |
|---|---|
| Status | **None built. Disabled.** |
| Agreed boundary | D-1: the Vendor Master holds supplier identity and dated reference prices; the Cockpit holds trip-applied prices. Any later link is one-way, on Daniel's click, and snapshots the price into the trip. |
| Supplier identity contract | Not written yet. It is the first integration step, after v4.97 is deployed and v4.98 is closed, and needs separate authorisation. |
| Fields the Cockpit could later read | `vendors` (id, name, category, also_categories, contacts, region, location, maps_link, hours, hours_last, hours_source, hours_verified_at / _how, tags); `vendor_prices` (label, audience, price, currency, vat, basis, is_agent, source, checked_on, updated_at, private, owner) |
| R5 export | Frozen, legacy backup only (owner: no active R5 use). Not round-tripped; IDs don't match R5; importing clears R5's trip view. |

## Data (counts worth watching)

| | |
|---|---|
| Suppliers | 100 total: 50 live, 50 hidden or pending review |
| Price lines | 119 |
| Members | 6 approved (7 rows), all full members; 0 organisations, as counted 3 Oct 2026 |
| Waiting for Eretz Israel Tours | 0 change requests, 0 supplier updates, 0 feedback |
| Unverified imports | Old Providers Master List (33), Gmail sweep (17), remaining email-import items. All hidden until approved. |

## Health

- **Keep-alive:** fixed 1 Oct 2026. The old ping read a blocked table and failed with HTTP 401. It now calls the `ping` function, which was tested and returned `ok:100`. Next run is in at most 3 days, or it can be run by hand in GitHub Actions.
- **Join alerts:** push to Eretz Israel Tours' phone via the ntfy app (no personal details in the alert). Added 1 Oct 2026.
- **Security:** 0 table grants to anon or authenticated, 0 RLS policies (re-checked on production 3 Oct 2026 after the jobs change and again after the limited-members change: 26 tables, 123 functions, 74 callable). All access goes through token-checked RPCs and the `files` edge function. Colleague-privacy probe passed on 1 Oct 2026. From D-15: what a limited member (an organisation) may see is decided in the database; a rolled-back probe on production on 3 Oct found no agent price, agent link or email in anything he receives. From D-5: two functions, `booking_open` and `booking_answer`, are checked by a one-booking link key instead of a member token; they reach that booking only.
- **Change process:** changes are committed straight to `main` and deployed by GitHub Pages; there is no review gate. Schema changes must be re-exported to `supabase/schema.sql` in the same change. That rule was adopted 1 Oct 2026.

## Known risks

1. The terms have not been reviewed by a lawyer.
2. Supplier identity is not yet mapped to the Cockpit's suppliers. About 30 overlap, by eye.
3. "Current price" has no freshness policy yet; each line only carries its checked date.
4. Lighter governance than the Cockpit: no review gate and no automated tests.
5. Free-tier limits: Supabase 500 MB database and 1 GB storage.
6. From D-3 (once live): personal data about drivers who are not members (name, work number, reviews). Not yet reviewed by a lawyer.
7. From D-5: the booking sheet's closing line ("Anything not written here will not be charged") is a record of what was agreed, not a lawyer-drafted contract. The sheet also holds the name of whoever answered for the company. Have the lawyer look at both.
8. From D-5: nobody is alerted when a company answers a booking sheet; the guide sees it when he opens the sheet.
9. From D-6: the 3-month use-and-add rule is in the terms but nothing measures it yet. The Team tab shows last seen only; what each member added is not counted, and no reminder is sent.
10. From D-6: the terms now promise that members approved while the list is free never pay ("founding members"). Have the lawyer read 2a and 2b.
11. From D-6: the name "The Inner Circle" has had no trademark search; a dating app uses "Inner Circle".
12. From D-11: members' availability and job posts are personal data. A poster's name stays hidden from colleagues only inside the app; a WhatsApp message he sends himself shows who he is. Terms 6d is not reviewed by a lawyer.
13. From D-11: terms 6d says "As of now, nothing is charged on a job". Whether a job is ever charged for is the owner's open decision.
14. Schema record and production had drifted on `member_decide` (welcome email through a Google Apps Script since 1 Oct). The record is corrected; the README's older "nothing is sent automatically" line is out of date. Worth a look by the owner: a secret for that script sits in `app_settings`.
15. From D-15: terms 2c is not reviewed by a lawyer. An organisation's credentials are free text and are personal data. Nothing checks them but Eretz Israel Tours reading them.
16. From D-15: an organisation's rate saves without approval and shows to every member at once. A wrong or careless rate is visible until Eretz Israel Tours or the organisation removes it.
17. From D-15: approving an organisation sends the same automatic welcome email as for a guide; its text lives in a Google Apps Script outside the repository and has not been checked for organisations.
18. From D-15: re-running the jobs migration files of 3 Oct would put back `whoami`, `_jobs_on`, `_jobs_post` and `_job_fits` without the limited-member rules. Run `2026-10-03b_limited_members.sql` after them.
19. From D-12: a guide's bio and pictures are meant to be sent to clients, and any member can write them, including for a guide who is not a member. Not reviewed by a lawyer.
20. From D-14: remarks about a member are kept from him by design. He is told they exist. Ask the lawyer whether a member can demand to see them.
21. From D-14: matching a member to a page by phone or email can hide reviews from someone who merely shares a number with a business (an office line). Eretz Israel Tours sees the matches on the page and can judge.
22. From D-16: "licensed" and "D1" are tags that the person adding an entry states. Nothing checks a license. A malicious post is found only when someone reports it or Eretz Israel Tours sees it.
23. Two sessions changed the same functions on production on the same evening (limited members; guides, claims and reviews). It was caught before anything was overwritten because the fingerprints of the live functions were compared with the record first. Do that before every database change.

## Waiting for the owner

- **Prices on a driver's or bus company's page (D-29):** built, NOT live, branch `driver-prices` (draft pull request #24). Asked for on 7 Oct at 12:31; made into drop-downs on his word at 12:43 ("a list is too daunting"). "Add price" on a Transport supplier is a short form of drop-downs: what the price is for (airport transfer Ben Gurion → city, city → Ben Gurion, both ways; day rate; per hour; something else), the city, the vehicle size (all seven), agent or public price. On the supplier's page the prices sit under headings that open on a tap, with a vehicle-size drop-down. Front end only: the parts are written into the line's name, no database change. He has the second set of preview pictures; waits for his word.
- **Region "Gaza Envelope - עוטף עזה" (D-28):** live since 5 Oct, about 17:45, on his word ("yes to both"). Asked for at 17:37. One line in the region list; no change to the database structure. On the same word, four hidden suppliers that were under "Negev & Arava" were moved into it (Burnt Vehicles Compound, Garden of Heroism and Remembrance, Nova Festival Memorial Site, The Salad Trail).
- **Reservation question at national parks only (D-27):** live since 5 Oct, about 17:40, on his word ("yes go live"). He reported on 5 Oct at 17:23 that Shimshon's Farm, a private supplier, asked him whether his reservation was checked. The pop-up and the "They checked / Not checked" buttons now show only in the category National Parks; any other supplier with a reservation setting shows one plain line. Front end only; no database change.
- **Booking sheets, "When the bus turns on" (D-26):** live since 5 Oct, about 17:25, on his word. The second choice under "Hours counted from" says "When the bus turns on" / "התנעת האוטובוס" in place of "Leaving the depot". Wording only; the stored value is unchanged.
- **Quote wording (database, one function):** on production since 5 Oct, about 17:15, run by the owner (`supabase/migrations/2026-10-05c_quote_wording.sql`). The quote a confirmed sheet leaves says "Hours counted from when the bus turns on." and says nothing about a cancellation policy left off the sheet. 141 functions, checked against the tested copy.
- **Booking sheets, terms left off by tick box (D-25):** live since 5 Oct, about 16:10, on his word, with D-24. Eight tick boxes in "Terms you expect"; a term left off is not asked of the company and is not on the sheet. Same database file as D-24.
- **Booking sheets, each day's own times (D-24):** live since 5 Oct, about 16:10, on his word. On a sheet of more than one day each day has its own pick-up time, estimated finish and optional "Where to". `supabase/migrations/2026-10-05b_booking_day_times.sql` is on production (with D-25: two added columns, five functions replaced, nothing deleted); production now has 141 functions, checked against the tested copy. Not yet tried by a person on the live site. Nothing Cockpit-facing.
- **Photographer, a subcategory under Other (D-23):** live since 5 Oct, about 15:30, on his word. A type under Other with its own button in the second row; no database change. Organisations do not see it unless given the Other section.
- **Rows cut off in a narrow computer window (review item D1, second part):** the owner, 5 Oct, 11:43: "desktop home page is still cutoff and i cant scroll right". The 3 Oct fix wrapped the rows only in windows 700 px or wider; a browser beside another app, or zoomed in, is narrower and still had one clipped row a mouse cannot scroll. Now any device with a mouse wraps them, at any width (categories, regions, view tabs, most-used cards two to a row). Phones unchanged. Styling only. Live since 5 Oct, about 15:30, on his word. His window was not seen: the live site showed nothing cut off in a 1,443 px window, and the fault was reproduced in preview at 577 and 690 px.
- **The Email button on a computer (D-22):** live since 5 Oct, about 15:30, on his word, with "Don't ask again on this computer". On a computer it offers Open in Gmail, Open my mail program or Copy the address; a phone is unchanged. Front end only. Not yet tried on his computer.
- **Booking sheets for separate days inside a period (D-21):** live since 5 Oct on his word ("yes", 11:30). He ran `supabase/migrations/2026-10-05_booking_days.sql` himself; production now has `bookings.days` and 138 functions, checked against the tested copy. Not yet tried by a person on the live site. Nothing Cockpit-facing.
- **Several categories at once, and subcategories (D-20):** live since 4 Oct, about 19:00, on his word. Front end only. His to say if he wants otherwise: Activity was given subcategories too (he named Extreme only). Not yet tried by a person on the live site.
- **Merge the branch `guide-for-clients` (pull request #11).** Merge it before the welcome-tour branch (pull request #9), which clashes with it in six places and has to be brought up to date afterwards by its own session. Its database change is already on production, rebuilt on top of limited members. Until it is merged the live form has no "licensed or specialty" buttons, so adding a new guide is refused, and the client section, claims, disputes and private notes have no screens.
- **Limited members (D-15): try it once on the live site.** Ask to join as an organisation from a second browser, approve it in the Team tab, and look at the list through that link. Tested on a local copy and by a probe on production, not yet by a person on the live site. Also: read the automatic welcome email with an organisation in mind.
- **Guides already on the list (D-16):** the 6 guide entries have neither "Licensed tour guide" nor "Specialty guide". Someone who knows has to tag them. One entry carries an Eshkol tag without "D1 license"; the same goes for it.
- **Second look at the database, asked for by the owner 3 Oct 22:02:** two reminders are set in the guides-and-claims session, for 3 Oct 23:20 and 4 Oct 08:30 Israel time, to compare every function on production with `supabase/tests/production_fingerprints.txt`, run both rolled-back probes and report to him. A first check at about 22:15 found nothing changed and nothing exposed.
- **His to say if he wants otherwise (where D-14 meets D-15):** an organisation is not sent a guide's retail price unless its "guide rates" switch is on; it does not write the section for clients and does not claim a page; it may keep a review private.
- **His to confirm (D-14):** that "reviews" means ratings, remarks, notes and driver reviews, not quotes; and that a page carrying a member's own phone or email is treated as his before he claims it. He answered "yes add changes" to the message that asked.
- **Jobs (D-11): settled.** The setting on production is "Colleagues see and answer jobs and mark their days. Only you post." The owner set it himself and confirmed it on 3 Oct at 22:05 ("yes"). `docs/DECISIONS.md` D-11 now says so (decision 7). Still his to decide: whether a job is ever charged for.
- **Decision numbers:** D-16 is the guide rules (this file, DECISIONS, the migration). The rulebook in Drive had kept D-16 for the parked AI assistant, which used D-6 a second time; the assistant takes D-17 when it is rebuilt.
- **Official logos on the WhatsApp, Waze and Google Maps buttons (D-10).** The buttons are ready and show a logo as soon as the brand owner's own file is in `brand/` in the repository (names and sources in `brand/README.md`). Needed from the owner: the WhatsApp logo from Meta's brand page; for Google Maps, Google's approval first (their brand page requires it), and the same is likely for Waze, whose rules are behind a sign-in.
- **Emails for booking sheets: choose how the app sends email.** Asked for 2 Oct 15:16 ("if that's easy"): a copy by email when a sheet goes out, and an email to the guide when the company answers. Not built: the app has no email-sending service. Options: (a) a Resend account with the eretzisraeltours.com domain verified (DNS records at SiteGround), the route Supabase documents; (b) an Eretz Israel Tours mailbox at SiteGround used over SMTP, not yet confirmed to work from Supabase. Either needs a secret set in Supabase by the owner.

## Next

- **Kosher value missing on 7 of 8 restaurant suppliers** (D-7): fill them in, or make the field required for restaurants. Owner to decide.
- **Website pass done (2 Oct, D-9):** 63 suppliers have opening hours (all Unverified), 200 public price lines on 50 suppliers, contact details and notes filled in. Next step is colleagues verifying hours by phone or in person.
- **21 supplier updates wait in Review** from the website pass (author "Website check"): a probable closure, a move, a rename, wrong regions, and suppliers that could not be identified by name.
- **Use-and-add rule (D-6):** a Team-tab view of who used the list and who added to it in the last 3 months, and the reminder before removal. Needs a database function; not started.
- **AI chat box for searches:** announced in the welcome tour as "in the works"; not built.
- **Booking sheets (D-5): first real use** by the owner with a real bus company, then by colleagues.
- **Lawyer:** terms 6c, the closing line of the sheet, and the cancellation-policy warning wording.
- **Later, not now (owner, 2 Oct 15:20):** the guide or agency adds its own terms to a booking sheet (driver late, bus dirty).

## Changes that would affect the Cockpit (log)

- 2026-10-03: **Live (about 22:45):** organisations see retail prices only (D-18). `_quote_visible` no longer lets an organisation see a guide's or agent's quote for a guide, even with guide rates on; bus and van quotes are the one exception. One helper replaced; 137 functions, 84 callable, unchanged. Also D-18: a guide who also runs jeeps is two entries; the two entries that combined them were split on 3 Oct (two new supplier ids; the jeep entry of each pair has `parent_id` set to its guide entry). For a later Cockpit read: `parent_id` no longer means only "a park site under its authority". Nothing else Cockpit-facing.
- 2026-10-03: **Database live (about 22:00), app on the owner's merge:** a guide's page for clients, claimed pages, disputes, review approval, private notes, guide rules (D-12, D-14, D-16). New `vendors.client_bio`, `retail_price`, `claimed_by`, `claimed_at`; table `vendor_claims`; `vendor_files.for_clients`; `vendor_reports.by_owner`; `vendor_notes.private`, `status`; `driver_reviews.private`. 27 tables, 137 functions. New supplier tags `Licensed tour guide`, `Specialty guide`, `D1 license`. `retail_price` is free text, not a price the Cockpit can apply.
- 2026-10-03: **Live (about 21:40):** limited members, organisations that are not in tourism (D-15), terms `2026-10-03c`, `files` function v11. `members` gains `member_type`, `sections`, four `see_*` switches, `org`, `credentials`; `vendor_prices`, `quotes`, `vendor_notes`, `driver_reviews` and `vendor_files` gain `org` (true when an organisation added the row); `vendor_notes` gains `rating`. New RPCs `request_access_org`, `review_add`, `member_set_access`. 26 tables, 123 functions. For a later Cockpit read of `vendor_prices`: a line with `org = true` is what an organisation was charged, not an agent rate and not a public price; it has `owner` set and `is_agent` false. No IDs or export formats changed.
- 2026-10-03: **Live for Eretz Israel Tours only (21:04):** jobs between colleagues and My days (D-11), terms `2026-10-03a`. New tables `jobs`, `job_offers`, `member_days`; six new columns on `members`; eleven new RPCs; `whoami` gains `jobs`, `jobs_post`, `jobs_for`; setting `jobs_for`. 26 tables, 107 functions. Nothing Cockpit-facing: a job carries no trip or client id, and there is no export.
- 2026-10-02: **Data only (evening):** website pass wrote hours for 63 suppliers, 200 unverified public price lines (`vendor_prices.created_by` = `import from websites (2 Oct 2026)`, `checked_on` 2026-10-02), contact details and notes. A Cockpit read of `vendor_prices` must not treat these as confirmed prices: check the `note` and `created_by`.
- 2026-10-02: **Live (about 17:40):** verified hours (`hours_verify`, `hours_verified_*`), last entry and other times (`vendors.hours_last`), source of unverified hours (`vendors.hours_source`). Migration `2026-10-02f`, applied to production. 60 callable functions. Hours for 32 suppliers written from their websites, unverified. New readable fields for the Cockpit; treat `hours` as unconfirmed unless `hours_verified_how` is set. No IDs or export formats changed.
- 2026-10-02: **Live (about 16:50):** opening hours (`vendors.hours`, free text) and the kosher rule in `vendor_save` (non-kosher restaurants refused; "Kosher, no certificate" on a restaurant goes to Eretz Israel Tours for approval). Migration `2026-10-02e`, applied to production; terms `2026-10-02e`. New readable field for the Cockpit: `vendors.hours`. No IDs or export formats changed.
- 2026-10-02: **Live (about 16:45):** Shomer Shabbat badge (a supplier tag, `Shomer Shabbat`), and kosher restaurants only (terms `2026-10-02d`, 3b; the form refuses a non-kosher Restaurant). Front end only, no schema change. Nothing Cockpit-facing; a Cockpit read of `vendors.tags` would see the new tag.
- 2026-10-02: **Live (about 16:35):** welcome tour for first-time users, the app renamed The Inner Circle – Israel Guide, terms `2026-10-02c` (use-and-add rule, cost and founding members). Front end only, no schema change. Nothing Cockpit-facing.
- 2026-10-02: **Live for all approved colleagues (about 15:40):** booking sheets, second step: both sides accept, changes return in red, cancellation-policy box, open to all colleagues (`2026-10-02d`). `bookings` gains `guide_ok_at`, `company_ok_at`, `company_ok_via`, `seen_guide`, `seen_company`; new RPC `booking_accept`. Dates are entered and shown day/month/year across the app. Nothing Cockpit-facing.
- 2026-10-02: **Live (Eretz Israel Tours only):** booking sheets for buses and vans (D-5). New table `bookings`; new page `b/index.html`; six new RPCs; `whoami` gains `phone`, `bookings`, `bookings_for`. A confirmed sheet creates an ordinary `Booked` quote. Nothing Cockpit-facing: a booking sheet carries a private trip/client label only, never a Cockpit id, and no export.
- 2026-10-02: **Live:** driver reviews and "bus" wording (D-3), transport by vehicle size (D-4). New tables `drivers`, `driver_vendors`, `driver_reviews` (driver identity = phone number); supplier tag `Coach` became `Bus` (5 suppliers); a company's vehicles are tags (`Bus`, `Midibus`, `Van 17–20 seats`, …). Nothing Cockpit-facing.
- 2026-10-02: **Live:** quote tracker (D-2). `quote_options` gained `service`, `seats`, `hours_incl`, `km_incl`, `fees`; `quotes.shared` defaults to true; new RPC `quotes_tracker`. Nothing Cockpit-facing. Quotes here remain reference only.
- 2026-10-01: D-1 boundary approved and confirmed in the owner's own words (16:27). R5 export frozen; owner has no active R5 use. No integration-facing schema changes made.
