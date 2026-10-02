# Israel Suppliers Master List: current status

*Short, factual status for the Cockpit Steward and other EIT projects. Updated by the Vendor Master session after any change that matters to them. The commit that last changed this file is its version.*

**As of:** 1 October 2026

## Identity

| | |
|---|---|
| App | https://vendors.eretzisraeltours.com |
| Repo | `Danielg972/eit-vendors`, branch `main` (cite by commit SHA) |
| Database | Supabase project `wjuqtjlrtcywjaspjpwu` (org "EIT Vendors", Frankfurt) |
| Schema record | `supabase/schema.sql` (tables, functions, grants), plus `supabase/functions/files/index.ts` (edge function v8) |
| Terms version | `2026-10-01e` (draft, not yet reviewed by a lawyer) |
| Decisions | `docs/DECISIONS.md` (D-1: Vendor Master / Cockpit boundary, approved 1 Oct 2026) |

## Integration with the Cockpit

| | |
|---|---|
| Status | **None built. Disabled.** |
| Agreed boundary | D-1: the Vendor Master holds supplier identity and dated reference prices; the Cockpit holds trip-applied prices. Any later link is one-way, on Daniel's click, and snapshots the price into the trip. |
| Supplier identity contract | Not written yet. It is the first integration step, after v4.97 is deployed and v4.98 is closed, and needs separate authorisation. |
| Fields the Cockpit could later read | `vendors` (id, name, category, also_categories, contacts, region, location, maps_link); `vendor_prices` (label, audience, price, currency, vat, basis, is_agent, source, checked_on, updated_at, private, owner) |
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
- **Security:** 0 table grants to anon or authenticated, 0 RLS policies. All access goes through token-checked RPCs and the `files` edge function. Colleague-privacy probe passed on 1 Oct 2026.
- **Change process:** changes are committed straight to `main` and deployed by GitHub Pages; there is no review gate. Schema changes must be re-exported to `supabase/schema.sql` in the same change. That rule was adopted 1 Oct 2026.

## Known risks

1. The terms have not been reviewed by a lawyer.
2. Supplier identity is not yet mapped to the Cockpit's suppliers. About 30 overlap, by eye.
3. "Current price" has no freshness policy yet; each line only carries its checked date.
4. Lighter governance than the Cockpit: no review gate and no automated tests.
5. Free-tier limits: Supabase 500 MB database and 1 GB storage.
6. From D-3 (once live): personal data about drivers who are not members (name, work number, reviews). Not yet reviewed by a lawyer.

## Waiting on the owner

- **Go-live of D-2, D-3, D-4 (2 Oct 2026):** everything is on branch `quote-tracker` and rehearsed. The live database change was cancelled at the approval prompt three times (12:55, 13:00, 14:05), so nothing is live. To finish: run `supabase/migrations/2026-10-02_GO_LIVE.sql` on the project (approve the prompt, or paste it into the Supabase SQL editor), then deploy the `files` function v9 and merge the branch into `main`.

## Next, not started

- **Standard booking terms form for bus and van companies** (owner, 2 Oct 2026, 14:04): a form a guide sends to the company when booking, so the price can't change afterwards. To cover: hours in a day and when overtime starts and its rate; km included and the rate over it; Highway 6 / tolls; expected tip; VAT in or out; how and when payment is made. The quote form already holds most of these fields, so the booking form can be filled from a quote. To be done after the go-live above. It is a contract template: have a lawyer look at the wording.

## Changes that would affect the Cockpit (log)

- 2026-10-02: Driver reviews and "bus" wording (D-3) built on the same branch; **not live yet**. When live: new tables `drivers`, `driver_vendors`, `driver_reviews` (driver identity = phone number); supplier tag `Coach` becomes `Bus`. Nothing Cockpit-facing.
- 2026-10-02: Quote tracker (D-2) built on branch `quote-tracker`; **not live yet** (database change awaiting the owner's approval). When live: `quote_options` gains `service`, `seats`, `hours_incl`, `km_incl`, `fees`; `quotes.shared` defaults to true; new RPC `quotes_tracker`. Nothing Cockpit-facing. Quotes here remain reference only.
- 2026-10-01: D-1 boundary approved and confirmed in the owner's own words (16:27). R5 export frozen; owner has no active R5 use. No integration-facing schema changes made.
