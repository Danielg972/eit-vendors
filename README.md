# Israel Suppliers Master List

Shared vendor list for Eretz Israel Tours colleagues. Static single-page app (GitHub Pages) on a free Supabase project.

- **App:** `index.html` (+ `manifest.json`, icons). Live at https://vendors.eretzisraeltours.com/ (CNAME at SiteGround → danielg972.github.io; the old github.io address forwards)
- **Database:** Supabase project `EIT Vendors` (ref `wjuqtjlrtcywjaspjpwu`, Frankfurt), org `EIT Vendors` (Free). Completely separate from eit-builder.
- **Access:** no passwords or email. People ask to join from the app with their role, license number and a photo of their license (private bucket `member-proofs`, visible only to Daniel via the `files` function); Daniel approves in the Team tab. Each person has a personal link (`?k=…`); only its SHA-256 hash is stored. All data goes through token-checked RPC functions (`vendors_list`, `vendor_save`, …); tables are closed to direct access.
- **Files:** private bucket `vendor-files` (photos/PDFs, 10 MB). The `files` edge function checks the link and signs uploads/downloads.
- **Review:** colleague adds/edits are `pending` until Daniel approves. Only approved vendors go into the R5 export.
- **R5 export:** Review tab → `{ "_exportFormatVersion": 3, "_tripVendors": [...], "days": [] }` with R5's exact 33 field keys + `id` (`vendor_` + 7 base-36 chars). Importing through R5's trip importer clears the open trip view, so save the trip first. R5 itself is never modified.
- **Keep-alive:** `.github/workflows/keep-alive.yml` pings the database every 3 days so the free project doesn't pause.
- The publishable key in `index.html` is meant to be public; data is protected by the personal links.

## Features added 1 Oct 2026
- **Locked fields + change requests:** name, category, status, contacts, main price and cancellation terms are read-only for colleagues. Their edits to those fields become `change_requests` (with a required reason) that Daniel approves in Review. Other fields save directly.
- **Price lines** (`vendor_prices`): several prices per supplier (adult/child with ages/Israeli senior/group size/season, VAT, agent vs public, source, checked date). Colleagues suggest; Daniel approves.
- **Deals** (`vendor_deals`): card-club benefits, coupon sites, public codes, group tricks, with expiry. Open to all; remove by Daniel or the reporter.
- **Notes thread** (`vendor_notes`): dated tips from colleagues.
- **Private admin notes** (`vendor_admin_notes`): only Daniel sees them.
- **Contact buttons:** Call, WhatsApp (from WhatsApp field or an Israeli mobile), Email, Website, Waze.
- **Search suggestions** from supplier names, areas, contacts and categories.
- **Imported EIT suppliers:** 44 suppliers / 100 price lines gathered from Daniel's Gmail and Drive, stored with `hidden = true` and `review_status = 'pending'`. Colleagues can't see them until Daniel approves each one. Client/trip details and sources are only in the private admin note.
- **Feedback box** (`feedback` table, `feedback-files` bucket): ideas/bugs/questions with optional screenshot; Daniel sets status and replies in Review.
- **Quotes** (`quotes`, `quote_options`, `quote_lines`): one-off offers for specific dates with options as tabs (e.g. 35-seat midibus vs 50-seat coach), lines with unit/qty/× nights or days, % discounts, totals, conditions, valid-until and status. Private to the owner (and Daniel) unless shared; shared quotes never show the client/title, reference or private note. Attachments are `vendor_files` rows with `quote_id`. "Make standard price" copies a line into the supplier's price list.
- **Private prices:** `vendors.prices_private` hides a supplier's main price and all its price lines from colleagues (supplier and contacts stay visible); `vendor_prices.private` hides single lines. Only Daniel sets these. Colleagues' edits ignore price fields on private-price suppliers.
- **Terms and privacy:** join requires accepting the terms (`members.terms_version`, `terms_accepted_at`); approved members who haven't accepted the current version (`TERMS_VERSION` in index.html) see an accept screen. Terms text says Daniel can see everything, including items marked private. Draft text, not lawyer-reviewed.
- **National Parks:** category renamed to `National Parks` (mapped back to R5's `National Park` on export). `vendors.parent_id` links sites to an umbrella supplier (the Parks Authority → Herodion, Beit Guvrin, Masada, En Gedi, Stalactite Cave, En Mabo'a). `vendors.reservation` (required/recommended/not needed) shows a reservation bar; `reservation_reports` collects colleagues' "did they check your reservation?" answers. A one-time pop-up asks each person once per site.
- **Personal price lines:** `vendor_prices.owner` = a colleague's email marks their own line. Colleagues can add their own prices to any supplier (including private-price ones) without approval; only they and Eretz Israel Tours see them. Owners can edit/remove their own lines. "Suggest for everyone" still goes through approval.
