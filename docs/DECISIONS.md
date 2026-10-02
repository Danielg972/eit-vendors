# Israel Suppliers Master List: decisions

Decisions that bind this project. Newest first. Each entry says who decided, when, and on what evidence.

---

## D-3 · Driver reviews keyed by phone number; "bus", not "coach" (approved)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, 13:07 Israel time.

**In his words:** "Call them busses not coaches. Have reviews for drivers with phone numbers to add to confirm same driver. Drivers of busses for the companies and van drivers."

**Decisions:**

1. The app says **bus**, not coach.
2. **Drivers can be reviewed**: the bus companies' drivers and van drivers.
3. **The phone number identifies the driver.** It is entered so colleagues can confirm it is the same driver.

**Implementation choices (not owner decisions; change on request):** one driver per phone number across all suppliers, with reviews following him; reviews show the reviewer's name and role, in line with the standing "From [name]" rule (quotes are the only anonymous item, per D-2); a rating from 1 to 5 is required, tags and text optional; the author or Eretz Israel Tours can delete a review.

**To check with a lawyer:** drivers are individuals who are not members. Their names, work numbers and colleagues' reviews are now stored.

**Status:** built and rehearsed on branch `quote-tracker`, 2 Oct 2026. Goes live together with D-2.

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

**Status:** built and rehearsed on branch `quote-tracker`, 2 Oct 2026. Not live: the database change needs the owner's approval in Supabase (two approval prompts were cancelled), then the branch is merged.

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
