# The Inner Circle – Israel Guide: decisions

*Called the Israel Suppliers Master List until 2 October 2026 (D-6).*

Decisions that bind this project. Newest first. Each entry says who decided, when, and on what evidence.

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
