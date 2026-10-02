# The Inner Circle – Israel Guide: current status

*Called the Israel Suppliers Master List until 2 October 2026 (D-6).*

*Short, factual status for the Cockpit Steward and other EIT projects. Updated by the Vendor Master session after any change that matters to them. The commit that last changed this file is its version.*

**As of:** 2 October 2026

## Identity

| | |
|---|---|
| App | https://vendors.eretzisraeltours.com (and `/b/?k=…`, the one-booking page a bus or van company sees) |
| Repo | `Danielg972/eit-vendors`, branch `main` (cite by commit SHA) |
| Database | Supabase project `wjuqtjlrtcywjaspjpwu` (org "EIT Vendors", Frankfurt) |
| Schema record | `supabase/schema.sql` (tables, functions, grants), plus `supabase/functions/files/index.ts` (edge function v9) |
| Terms version | `2026-10-02e` (draft, not yet reviewed by a lawyer; adds 2a use-and-add rule, 2b cost and founding members, 3b kosher restaurants only, no-certificate as an approved exception) |
| Decisions | `docs/DECISIONS.md` (D-1 Cockpit boundary; D-2 quote tracker; D-3 driver reviews; D-4 transport by vehicle size; D-5 booking sheets; D-6 welcome tour, name, use-and-add rule; D-7 Shomer Shabbat badge, kosher restaurants only; D-8 opening hours, no-certificate needs approval; D-9 verified hours, last entry, hours from websites) |

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
| Members | 4 approved, 0 join requests waiting |
| Waiting for Eretz Israel Tours | 0 change requests, 0 supplier updates, 0 feedback |
| Unverified imports | Old Providers Master List (33), Gmail sweep (17), remaining email-import items. All hidden until approved. |

## Health

- **Keep-alive:** fixed 1 Oct 2026. The old ping read a blocked table and failed with HTTP 401. It now calls the `ping` function, which was tested and returned `ok:100`. Next run is in at most 3 days, or it can be run by hand in GitHub Actions.
- **Join alerts:** push to Eretz Israel Tours' phone via the ntfy app (no personal details in the alert). Added 1 Oct 2026.
- **Security:** 0 table grants to anon or authenticated, 0 RLS policies. All access goes through token-checked RPCs and the `files` edge function. Colleague-privacy probe passed on 1 Oct 2026. From D-5: two functions, `booking_open` and `booking_answer`, are checked by a one-booking link key instead of a member token; they reach that booking only.
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

## Waiting for the owner

- **Emails for booking sheets: choose how the app sends email.** Asked for 2 Oct 15:16 ("if that's easy"): a copy by email when a sheet goes out, and an email to the guide when the company answers. Not built: the app has no email-sending service. Options: (a) a Resend account with the eretzisraeltours.com domain verified (DNS records at SiteGround), the route Supabase documents; (b) an Eretz Israel Tours mailbox at SiteGround used over SMTP, not yet confirmed to work from Supabase. Either needs a secret set in Supabase by the owner.

## Next

- **Kosher value missing on 7 of 8 restaurant suppliers** (D-7): fill them in, or make the field required for restaurants. Owner to decide.
- **Opening hours:** pulled from suppliers' websites on 2 Oct (D-9), all marked Unverified until a colleague confirms by speaking to the supplier or being there. Remaining suppliers, published prices and other details are being pulled the same way.
- **HaGoshrim Kayaks may have closed** (old site is an unrelated blog; a ticketing site lists its route as closed permanently). Check and remove or mark inactive.
- **Use-and-add rule (D-6):** a Team-tab view of who used the list and who added to it in the last 3 months, and the reminder before removal. Needs a database function; not started.
- **AI chat box for searches:** announced in the welcome tour as "in the works"; not built.
- **Booking sheets (D-5): first real use** by the owner with a real bus company, then by colleagues.
- **Lawyer:** terms 6c, the closing line of the sheet, and the cancellation-policy warning wording.
- **Later, not now (owner, 2 Oct 15:20):** the guide or agency adds its own terms to a booking sheet (driver late, bus dirty).

## Changes that would affect the Cockpit (log)

- 2026-10-02: **Live (about 17:40):** verified hours (`hours_verify`, `hours_verified_*`), last entry and other times (`vendors.hours_last`), source of unverified hours (`vendors.hours_source`). Migration `2026-10-02f`, applied to production. 60 callable functions. Hours for 32 suppliers written from their websites, unverified. New readable fields for the Cockpit; treat `hours` as unconfirmed unless `hours_verified_how` is set. No IDs or export formats changed.
- 2026-10-02: **Live (about 16:50):** opening hours (`vendors.hours`, free text) and the kosher rule in `vendor_save` (non-kosher restaurants refused; "Kosher, no certificate" on a restaurant goes to Eretz Israel Tours for approval). Migration `2026-10-02e`, applied to production; terms `2026-10-02e`. New readable field for the Cockpit: `vendors.hours`. No IDs or export formats changed.
- 2026-10-02: **Live (about 16:45):** Shomer Shabbat badge (a supplier tag, `Shomer Shabbat`), and kosher restaurants only (terms `2026-10-02d`, 3b; the form refuses a non-kosher Restaurant). Front end only, no schema change. Nothing Cockpit-facing; a Cockpit read of `vendors.tags` would see the new tag.
- 2026-10-02: **Live (about 16:35):** welcome tour for first-time users, the app renamed The Inner Circle – Israel Guide, terms `2026-10-02c` (use-and-add rule, cost and founding members). Front end only, no schema change. Nothing Cockpit-facing.
- 2026-10-02: **Live for all approved colleagues (about 15:40):** booking sheets, second step: both sides accept, changes return in red, cancellation-policy box, open to all colleagues (`2026-10-02d`). `bookings` gains `guide_ok_at`, `company_ok_at`, `company_ok_via`, `seen_guide`, `seen_company`; new RPC `booking_accept`. Dates are entered and shown day/month/year across the app. Nothing Cockpit-facing.
- 2026-10-02: **Live (Eretz Israel Tours only):** booking sheets for buses and vans (D-5). New table `bookings`; new page `b/index.html`; six new RPCs; `whoami` gains `phone`, `bookings`, `bookings_for`. A confirmed sheet creates an ordinary `Booked` quote. Nothing Cockpit-facing: a booking sheet carries a private trip/client label only, never a Cockpit id, and no export.
- 2026-10-02: **Live:** driver reviews and "bus" wording (D-3), transport by vehicle size (D-4). New tables `drivers`, `driver_vendors`, `driver_reviews` (driver identity = phone number); supplier tag `Coach` became `Bus` (5 suppliers); a company's vehicles are tags (`Bus`, `Midibus`, `Van 17–20 seats`, …). Nothing Cockpit-facing.
- 2026-10-02: **Live:** quote tracker (D-2). `quote_options` gained `service`, `seats`, `hours_incl`, `km_incl`, `fees`; `quotes.shared` defaults to true; new RPC `quotes_tracker`. Nothing Cockpit-facing. Quotes here remain reference only.
- 2026-10-01: D-1 boundary approved and confirmed in the owner's own words (16:27). R5 export frozen; owner has no active R5 use. No integration-facing schema changes made.
