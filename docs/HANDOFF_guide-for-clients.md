# Handoff: rework `guide-for-clients` on top of limited members before it goes live

**To:** the Claude session that built the branch `guide-for-clients` (D-12, a guide's page for clients; D-14, claimed pages, disputes and reviews).
**From:** the Vendor Master session that built limited members (D-15), live on `main` since 3 Oct 2026, about 21:40.
**Asked for by the owner**, 3 Oct 2026, 21:48: "give this feedback to the one who made those changes. explain our rules and have them implement the changes".

**The short version.** Your branch was built from the code as it was before limited members existed. Your two database files replace six functions that now enforce what an organisation may see. Run as they are, they would send agent prices and guides' reviews to limited members. **Do not run `2026-10-03b_guide_for_clients.sql` or `2026-10-03c_claims.sql` on production as they are.** Bring the branch up to date with `main`, rebuild those six functions on top of the current ones, apply the rules below to your new functions, and pass the checks in section 7. Nothing from your branch is on production (checked 3 Oct, 21:50).

Your feature decisions (D-12, D-14) stand as the owner made them. Nothing here changes what guides and agents get.

---

## 1. What is live now (D-15)

A second kind of member: an **organisation that is not in tourism** (a school, a yeshiva), called a **limited member**. Full text: `docs/DECISIONS.md` D-15 and the README section "Limited members". The database change is `supabase/migrations/2026-10-03b_limited_members.sql`; `supabase/schema.sql` on `main` includes it; the `files` edge function is v11.

- `members.member_type` (`full` | `limited`), `members.sections` (comma list of `transport, guides, hotels, sites, food, other`), four switches `see_quotes`, `see_guide_rates`, `see_transport_reviews`, `see_reviews`, plus `org` and `credentials`.
- An organisation is stored with role `Other` and its name in `members.org`. `members.org <> ''` is what marks it. `whoami` and `members_list` show the role as "Organisation, not in tourism".
- Rows an organisation writes are stamped `org = true`: `vendor_notes`, `driver_reviews`, `vendor_prices`, `quotes` (by trigger), `vendor_files`. `vendor_notes` also has `rating`.
- `_auth` now remembers who is calling (`app.member`); `_me()` returns that member.
- Helpers, none callable from outside: `_limited(m)`, `_section_of(category)`, `_can_see(m, category, also)`, `_reviews_open(m, category, also)`, `_price_visible(p, v, m)`, `_note_visible(n, v, m)`, `_file_visible(f, m)`, `_file_scope(member, vendor)`, `_quote_kind`, `_quote_visible`, `_vendor_for(v, m)`.
- `_vendor_view` is now a small wrapper. **`_vendor_for(v, m)` is the one place that builds what a member who is not Eretz Israel Tours receives of a supplier.** `vendors_list` calls it directly.
- `_visible(p_vendor, p_admin)` now also refuses a supplier outside a limited member's sections, so any function that calls it is already closed to hidden sections.

## 2. The rules, in the owner's words and as enforced

These are owner decisions (D-15). Every function that sends or accepts supplier data has to keep them.

1. **Sections.** "give admin the option to choose what they see". A limited member sees only suppliers whose main or "also offers" category falls in his sections. Everything else is refused by the database, not just hidden in the app: `_can_see`, or `_visible`.
2. **No agent rates, ever.** "don't give them access to any agent rate pricing". Never send a limited member `agentPrice`, `agentPriceVatTreatment`, `agent_link`, `agent_howto`, a price line with `is_agent`, or another member's personal line. Never accept those fields from him. `_price_visible` and `_vendor_for` do this.
3. **Guide rates hidden unless the switch is on.** A guide's prices show as "Ask for rate" unless `see_guide_rates`. Any new price on a guide follows the same switch.
4. **Reviews.** "don't give them access to ... reviews", then "Let reviews be on for transportation". A limited member reads guides' and agents' notes, ratings, strengths, weaknesses and summary notes only where `_reviews_open` says so (transport by default). He always reads what organisations wrote and what he wrote.
5. **Their reviews show for everyone.** "Make sure their reviews show up for everyone even limited access people". A note or driver review with `org = true` is visible to every member who can see that supplier, limited members included.
6. **They add.** "they can add suppliers and quotes", "allow them to leave reviews", and the rates they were given, shown to everyone ("organisation rates": `org = true`, `owner` set, never `is_agent`, shown without the name).
7. **Proof.** Free-text credentials; no license, no upload.
8. **Not for them:** Jobs (`_jobs_on`, `_jobs_post`, `_job_fits` exclude them). Booking sheets only with the transport section and `see_quotes`.

The standing project rules still apply (README, "Change rules"): the app never says "Daniel"; all data through token-checked RPCs, 0 table grants, 0 policies; never return a member's email, phone or license to anyone but Eretz Israel Tours; every new function gets its own `revoke ... from public`; re-export `supabase/schema.sql` in the same change; bump `TERMS_VERSION` when the terms change; update `docs/STATUS.md`, `docs/DECISIONS.md`, the README and the Project docs; test in preview mode plus a probe as a member who is not Eretz Israel Tours. Two more from this week: a change should only add and replace (the connector asks the owner to confirm any SQL with DELETE or DROP, and that confirmation has not been reaching him), and anything applied to production is checked there by fingerprint and by a rolled-back probe.

## 3. The six functions that clash

Start each from the version on `main` and add your rules to it. Do not start from yours.

| Function | What `main` does that must stay | What yours adds that must go in |
|---|---|---|
| `_vendor_view` | Wrapper: Eretz Israel Tours gets everything; anyone else gets `_vendor_for(v, m)`. | Your additions for Eretz Israel Tours (`_claimed`, `claimed_name`, `_mine`, `_own`) go here. Everything for other members goes into **`_vendor_for`**, not here: blank `retail_price` on a private-price supplier; blank ratings, strengths, weaknesses, notes on his own page; `claimed_by` blank, `_claimed`, `claimed_name`, `_mine`, `_own`; `_notes` = 0 on his own page. |
| `vendor_detail` | `_can_see` check; prices through `_price_visible`; `org` on a price line; an organisation's line shown as "an organisation" to everyone but its owner and Eretz Israel Tours; `owner` blank for others; notes through `_note_visible`; `reviews_open`; `sites` and `parent` through `_can_see`. | Own page: no notes. Private and pending notes only to their author and Eretz Israel Tours. `own`, `my_claim`, `claimer`, `matches`. |
| `vendor_save` | For a limited member: a new supplier only in his sections, agent fields blanked; on an edit, `_can_see`, and the skip list (agent fields; a guide's prices without `see_guide_rates`; review fields where `_reviews_open` is false). | Own page: review fields left as they are, and no self-rating on insert. A guide's change to another guide's review fields becomes a change request. |
| `note_add` | Stamps `org`. Also on `main`: `review_add(p_token, p_vendor, p_body, p_rating)`, which the app now calls, and `vendor_notes.rating`. | `note_post` with `private` and `status`. Make it one path: give `note_post` a rating and the `org` stamp, and have `note_add` and `review_add` call it. Keep both old signatures working. |
| `_driver_json` | For a limited member without `see_transport_reviews`: only organisations' reviews and his own (`x.every or r.org or r.author = p_email`), `some_hidden`; company names only where `_can_see`; `org` on each review. | Hidden from the driver himself and from his company's owner; private reviews only to author and Eretz Israel Tours, and out of the average others see. |
| `driver_review_add` | A limited member needs the transport section; stamps `org`. | No reviewing yourself or your own company's drivers; `private`. |

The cleanest way to carry "private" and "waiting for approval" is inside **`_note_visible`**, so every place that counts or lists notes agrees: a note is visible to its author, to Eretz Israel Tours, and otherwise only when it is approved, not private, and passes the limited-member rule that is already there. `_vendor_for` already counts notes through `_note_visible` for limited members; make it the count for everyone.

Check when you are done: a private note from an organisation stays private (its author chose that); an approved, non-private note from an organisation reaches everyone; a guide's note on another guide that is waiting for approval reaches nobody but him and Eretz Israel Tours, limited members included.

## 4. Your new functions: what a limited member may do

None of these exist on `main`, so the owner has not ruled on them. These are the defaults that follow from his rules. Record them as implementation choices in D-12 and D-14, and tell him.

- **`retail_price` is a guide's price.** A limited member does not receive it unless `see_guide_rates` is on (blank it in `_vendor_for` with the guide's other prices), and never changes it while it is hidden from him: in `vendor_set_client` keep the stored value, as you already do for private-price suppliers.
- **The section for clients (`vendor_set_client`, `file_for_clients`).** Reading the bio and the pictures is fine. Writing them: refuse for a limited member (`_limited(m)`). The section is for guides and agents to pass on to their clients; the owner's list of what organisations add is suppliers, quotes, reviews and rates.
- **`vendor_claim`.** Refuse for a limited member. An organisation is not a supplier on the list. If the owner wants a school to claim a page, that is his to say.
- **`_is_own`** matches by phone or email, so it applies to limited members as it does to anyone. Leave it.
- **`_is_guide_member`** reads `role = 'Licensed tour guide'`. An organisation's role is `Other`, so an organisation's review of a guide does not wait for approval. That matches rule 5; leave it.
- **`claims_list`, and `claimer` and `matches` in `vendor_detail`** return `mm.role`. For an organisation show its name instead: `case when mm.org <> '' then mm.org else mm.role end`, the way `_who` does.
- Every new function that takes a supplier id must call `_visible` (most of yours do) so a hidden section stays closed.
- A file marked `for_clients` is a Photo, so `_file_visible` already lets a limited member see it. No change to the `files` function is needed; if you do change it, start from v11 on `main`.

## 5. The app (`index.html`)

Both branches changed it heavily, so expect conflicts. What `main` has now:

- Helpers before `const normN`: `ORG_ROLE`, `SECTIONS`, `DEF_SECTIONS`, `lim()`, `mySections()`, `secOf`, `secName`, `myCats()`, `reviewsOpen(v)`.
- `DB.addNote(vid, body, rating)` calls `review_add`; `DB.setAccess`; `DB.requestAccess` calls `request_access_org` for an organisation.
- Supplier page: no agent-prices box for a limited member; "Prices" and "+ Add the rate you got"; the notes box is "Reviews" with stars (`#noteStars`); organisation rates in their own block; notes use `n.mine` for Delete.
- The form (`openForm`) uses `myCats()`, hides agent fields, and hides "Your experience" unless `reviewsOpen(v)`.
- Team tab: credentials, "Approve and choose access", `openAccess(m, approving)`, "Change access".
- Preview mode: `?as=limited`.

What your side has to do:

- Your "For clients" box sits under the agent-prices box, which a limited member does not have. Give it a place that works for both.
- Hide the retail price from a limited member unless `S.me.see_guide_rates`; hide the edit and claim buttons from him.
- Your private tick and "waiting for approval" label go into the same Reviews box that now has stars.
- Add "an organisation (limited member)" to your preview "View as" switch, and keep `?as=limited` working.
- The welcome tour has separate wording for limited members; pull request #9 (`tour-update`) also touches the tour.

## 6. Numbers and names

- **Decisions:** D-12 and D-14 are yours. Limited members is D-15 (it was recorded as D-12 for a few minutes by mistake). `docs/DECISIONS.md` on `main` has a line at the top pointing to your branch; replace it with your two entries when you merge.
- **Terms:** `main` is at `2026-10-03c` (adds 2c, organisations, and a line in section 6). Yours says `2026-10-03b`. Take the next one, `2026-10-03d` or the date you go live, with 6e and 6f added to the current text.
- **Migration files:** yours and the limited-members file share the prefix `2026-10-03b`. Keep yours if you like, but refer to files by full name. Either rewrite the function bodies inside your two files, or leave them as history and add one new file that is the only one to run; say which in the file headers.
- **Counts on production now:** 26 tables, 123 functions, 74 callable from outside, 0 table grants, 0 policies.

## 7. How to check, and when it is done

In the repository, `supabase/tests/limited_members/`:

- `run.sh` builds a local database from `supabase/schema.sql`, loads sample data (`seed.sql`) and runs `probe.py`: 74 checks as an organisation, a guide and Eretz Israel Tours. It needs a local Postgres 16, `psql` and `python3`. On `main` today: 74 passed, 0 failed.
- `production_probe.sql` is the same idea for the live database. It adds two temporary members, calls the functions as each, and ends in an error that carries the results, so everything rolls back. The expected values are at the top of the file.

Done means all of these:

1. The branch is up to date with `main`, with no function body older than `main`'s.
2. `run.sh` on your branch: 74 passed, 0 failed. Where your change legitimately alters an expected value (a note now has `private` and `status`, say), change the check and say so in the commit; do not delete it.
3. New checks added to `probe.py` for the meeting points: a limited member never receives `retail_price` with guide rates off; cannot write the section for clients; cannot claim a page; an organisation's approved note reaches a guide and another organisation; a private or pending note reaches neither; a page's owner still sees no notes, organisation notes included.
4. Your own probes (claims, disputes, guide-on-guide reviews, private notes) still pass.
5. A database rebuilt from `supabase/schema.sql` matches base plus your migration, function by function.
6. In a browser, in preview mode, at phone width: as Eretz Israel Tours, a guide on her own page, another guide, a travel agent, and an organisation. No page errors.
7. Only then production: apply, compare fingerprints with your local database, run `production_probe.sql`, and record the result in the README.
8. Records updated: README, `docs/STATUS.md` (remove risk 19 and the "Waiting for the owner" line about this branch), `docs/DECISIONS.md`, the three Project docs, and delete this file or mark it done.

## 8. If something here is unclear or you disagree

Write it in the GitHub issue that points to this file, and ask the owner where a rule is his to decide (the three defaults in section 4 are the likely ones). The owner does not carry files between sessions: the repository and the Project docs are where sessions hand work to each other.
