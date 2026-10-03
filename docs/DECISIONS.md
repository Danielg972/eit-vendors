# The Inner Circle – Israel Guide: decisions

*Called the Israel Suppliers Master List until 2 October 2026 (D-6).*

Decisions that bind this project. Newest first. Each entry says who decided, when, and on what evidence.

---

## D-13 · Food nearby only on entries with a physical address (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 3 October 2026, 21:16 Israel time.

**In his words:** "food nearby is only on entries with a phsical address not a service provider like guide, rappeling, jeep, bus etc."

**Decision:** the Food nearby section belongs to places, not to service providers.

**Implementation choices (not owner decisions; change on request):** "a place" is decided by category (Hotel, Restaurant, Winery, Attraction / Site, National Parks), plus Activity and Other unless the entry is tagged jeep, ATV / RZR or rappelling. The whole Adventure category counts as a service provider. Tips already saved on service providers stay in the database, unseen.

**Status:** front end only; live since 3 Oct 2026 (pull request #8 merged).

---

## D-12 · Limited members: organisations that are not in tourism (live)

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
- **Terms** `2026-10-03b` add section 2c (organisations) and a line in section 6. Every member accepts again on next opening.

**Left as it was (known, small):** the function that asks to remove a price line (`price_delete`) was not changed. It works by the line's internal id, which a limited member is never sent for an agent line.

**To check with a lawyer:** terms 2c; the credentials text is personal data now stored; showing what one organisation paid to others.

**Status:** live since 3 Oct 2026, about 21:40. Database change on production (two connector migrations, `limited_members_2026_10_03b_part1_columns_helpers` and `_part2_rpcs`), `files` function v10 deployed, code on `main`. Tested on a local database (74 checks as an organisation, a guide and Eretz Israel Tours; guides' and Eretz Israel Tours' results unchanged), in a browser against that database, and by a rolled-back probe on production; see README. Not yet tried on the live site by a person.

---

## D-11 · Jobs between colleagues, and My days (live for Eretz Israel Tours only)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session, 2 October 2026, 17:16 Israel time (the idea) and 3 October 2026, 20:02–20:47 (the mock-up, the go-ahead to build, and the go-ahead to go live).

**In his words:** "I would like to have an option, starting with myself and later with other people, to have anonymous requests for tour guides or other providers that might be on the site. The price will be listed, as will the details of the job. Each participant will get a notification or perhaps I will get to choose from a list of relevant guides based on the filters. It will be sent to them by WhatsApp or by a notification from the app." On availability: "if I had Google Calendar integration for the people in the app so I could see at a glance their availability and they can share their availability." On the mock-up (3 Oct, 20:13): "it looks good. Is there other calendar integration that makes sense outside of Google calendars? Is there an easy way for them to update their calendar availability?" On the suggestion to build tap-and-automatic availability and an "Add to my calendar" button now, and a pasted calendar link later (20:19): "OK let's do that. I'll take your suggestion". On the preview (20:47): "Looks good. Let's make it live for beta version. Make it live for me".

**Decisions:**

1. **Members can post jobs for colleagues, anonymously, with the price and the details listed.**
2. **It starts with Eretz Israel Tours and opens to others later.**
3. **A job goes either to everyone it fits or to people the poster picks from a filtered list.**
4. **Availability is kept by tapping days, and filled in automatically when a job is given.** Jobs can be added to the member's own calendar. Reading members' calendars through a pasted link comes later.
5. **Build it in preview first, to try before it goes live.**
6. **Live as a beta, for Eretz Israel Tours only** (3 Oct, 20:47). Colleagues do not see it until he changes the setting.

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

**Status:** live since 3 Oct 2026, 21:04, for Eretz Israel Tours only (terms `2026-10-03a`). The session that built it was not allowed to push to `main` or to apply SQL containing DELETE, so the owner merged pull request #7 and ran `supabase/migrations/2026-10-03_jobs_last_step.sql` in the SQL editor himself. Checked afterwards on production: 107 functions, all as tested, and the whole flow passed in a rolled-back probe; see README.

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
