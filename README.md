# Israel Suppliers Master List

Shared vendor list for Eretz Israel Tours colleagues. Static single-page app (GitHub Pages) on a free Supabase project.

- **App:** `index.html` (+ `manifest.json`, icons). Live at https://danielg972.github.io/eit-vendors/
- **Database:** Supabase project `EIT Vendors` (ref `wjuqtjlrtcywjaspjpwu`, Frankfurt), org `EIT Vendors` (Free). Completely separate from eit-builder.
- **Access:** no passwords or email. People ask to join from the app with their role, license number and a photo of their license (private bucket `member-proofs`, visible only to Daniel via the `files` function); Daniel approves in the Team tab. Each person has a personal link (`?k=…`); only its SHA-256 hash is stored. All data goes through token-checked RPC functions (`vendors_list`, `vendor_save`, …); tables are closed to direct access.
- **Files:** private bucket `vendor-files` (photos/PDFs, 10 MB). The `files` edge function checks the link and signs uploads/downloads.
- **Review:** colleague adds/edits are `pending` until Daniel approves. Only approved vendors go into the R5 export.
- **R5 export:** Review tab → `{ "_exportFormatVersion": 3, "_tripVendors": [...], "days": [] }` with R5's exact 33 field keys + `id` (`vendor_` + 7 base-36 chars). Importing through R5's trip importer clears the open trip view, so save the trip first. R5 itself is never modified.
- **Keep-alive:** `.github/workflows/keep-alive.yml` pings the database every 3 days so the free project doesn't pause.
- The publishable key in `index.html` is meant to be public; data is protected by the personal links.
