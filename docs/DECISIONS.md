# The Inner Circle – Israel Guide: decisions

*Called the Israel Suppliers Master List until 2 October 2026 (D-6).*

Decisions that bind this project. Newest first. Each entry says who decided, when, and on what evidence.

*D-12, D-14 and D-16 were built on the branch `guide-for-clients` at the same time as D-15, and rebuilt on top of it before anything of theirs touched production. See the note under D-15.*

*D-15 (limited members) was first recorded as D-12 by mistake, for a few minutes on 3 Oct; D-12 was already taken on that branch.*

---

## D-24 · On a booking sheet of more than one day, each day has its own pick-up time and estimated finish (built; NOT live, waiting for the owner)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 15:34 Israel time.

**In his words:** "each day needs its own start and finsh time. there should be be timated. for instance this is what the itinerary looks like." With it he attached one of his own trip itineraries, where each bus day has its own pick-up time and an estimated return, some still to be set. The itinerary is a client document and is not kept in these records (D6).

**Decision:** on a booking sheet for more than one day, every day carries its own start time and its own finish time, and the finish is an estimate.

**What was built (implementation choices; change on request):**

- **The form:** when a sheet has more than one day, a block "Times for each day" lists the chosen days. Each has a pick-up time, a finish time ("to about") and an optional "Where to". The single pick-up time and drop-off time fields are hidden then; pick-up place and drop-off place stay, one for all days. **Same times every day** copies the first day's times to the rest.
- **"Where to" for each day was not asked for.** It was added because the itinerary he showed has a different region each day and a bus price depends on where the bus goes. It is optional and comes out on his word.
- **What the company sees:** under the date line, one line for each day, Hebrew with English under it: "ד׳ 18.11 · איסוף 08:30 · סיום משוער 18:00 · ים המלח" / "Wed 18 Nov · pick-up 08:30 · finish about 18:00". A day with a pick-up time and no finish reads "finish time to follow"; a day with nothing reads "times to follow". Also in the WhatsApp plain message and the printed sheet.
- **Every finish time is worded as an estimate** ("סיום משוער", "finish about"). Nothing else on the sheet says what an estimate means for overtime: the hours included in a day and the price of an extra hour are the company's to fill in, as before.
- **Stored** in one new column, `bookings.day_plan` (`{"2026-10-20": {"start":"08:30","end":"18:00","route":"…"}}`). Empty means the sheet's one pick-up and drop-off time apply to every day, so sheets made before this are unchanged. When every day has the same times and no "Where to", nothing is stored per day and the sheet shows one pick-up and one drop-off time, as before.
- **The times are part of what both sides accept:** a time changed after the company accepted clears its acceptance and comes back to it in red (D-5, item 10). Taking a day off the sheet takes its times with it.
- A one-day sheet is unchanged. Sheets of more than 31 days get no per-day block.

**Checked:** `supabase/tests/booking_day_times/run.sh` (21 checks: the change file run twice on the earlier schema gives the same functions and columns as the schema record; sheets made before the change read exactly as they did; bad times, days not on the sheet and empty entries are dropped; an old copy of the app keeps the times; a time changed after acceptance goes back to waiting; an organisation sees only its own sheets). The 98 limited-member checks and the 26 day-picker checks still pass. In preview, at phone and desktop size, as Eretz Israel Tours: fill in, save, plain message, reopen, same times every day, and the company's page. **Not checked:** on the live site; on a real phone; by a session other than the one that built it; in preview as an organisation; the red marking of a changed time on the company's page was checked in the database only, not looked at.

**Status:** on the branch `booking-day-times`. The database file `supabase/migrations/2026-10-05b_booking_day_times.sql` has NOT been run on production. It adds one column and one helper and replaces four functions; nothing is deleted or dropped. It must be run before the branch is merged.

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

## D-11 · Jobs between colleagues, and My days (live; colleagues receive jobs, Eretz Israel Tours posts)

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
