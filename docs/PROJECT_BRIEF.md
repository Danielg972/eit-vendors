# Israel Suppliers Master List: project brief

*An introduction for other Eretz Israel Tours projects. Written 1 October 2026 by the Claude project that builds it ("Vender Master Sheet").*
*The companion technical audit is `docs/AUDIT_2026-10-01.md` in the same repo.*

---

## 1. Who I am

I am the Claude project that builds and runs the **Israel Suppliers Master List** for Eretz Israel Tours (EIT). The list is a private, app-like website, **https://vendors.eretzisraeltours.com**, where licensed guides, travel agents and tour operators share what they know about Israeli suppliers: hotels, guides, buses, jeeps, sites, national parks, restaurants and more.

I am a small, fast, separate project. I am **not** part of the EIT Builder / Cockpit software program and not under its change-process governance. I never touch the frozen R5 builder file. The only thing I hand the Builder is an import file it can read.

## 2. Why it exists (the problem)

Every guide and agent in Israel keeps their own scattered supplier knowledge: phone numbers in WhatsApp, prices in old emails, a winery that gives guides a free bottle, a bus company that overcharged, a park that now needs a reservation. That knowledge is:

- **repeated:** everyone asks the same questions;
- **lost:** it sits in one person's phone;
- **stale:** prices and contacts change and nobody hears.

EIT's own records have the same problem. Supplier facts are spread across Gmail, old Google Sheets and the Builder's local storage.

## 3. Goals

1. **One trusted, shared list** of Israeli tourism suppliers, kept current by the people who use them.
2. **Save colleagues time:** find a supplier, see real prices and terms, and call, WhatsApp, email or navigate in one tap.
3. **Protect quality:** core facts (contacts, main price, cancellation terms) are locked and change only with EIT's approval. Everything colleagues add carries their name.
4. **Keep it among professionals:** invite-only, proof of being a guide or agent, and never shown to suppliers.
5. **Feed EIT's own work:**
   - better, fresher supplier data for pricing and trip building;
   - an export into the R5 Builder;
   - emails and prices captured through BCC.
6. **Free to run:** free Supabase and GitHub Pages plans, on EIT's own domain.

## 4. Vision

**Near term (now):** about 50 invited colleagues use it as their everyday supplier phonebook and price notebook. EIT is the steward: it approves members, checks changes and keeps the core facts right.

**Medium term:**

- It becomes the **source of truth for EIT's supplier data**. The Builder and the pricing work read from it instead of keeping separate vendor lists.
- Colleagues' reports keep it current: "closed", "moved", "prices changed", new deals and agent sign-up links.
- AI fills in details from uploaded receipts, price lists and screenshots. This was discussed and deferred.

**Longer term (ideas only, nothing built):**

- Suppliers could pay for clearly labelled **sponsored offers or promotions** aimed at guides. Ratings and notes are never for sale, and the terms already promise this.
- Tap and booking tracking could show which suppliers colleagues actually use, which gives EIT negotiating weight.
- The aim is to help colleagues in a way that doesn't look like EIT benefiting at their expense. Trust in the list comes first.

## 5. Principles (the rules this project lives by)

- **Colleagues only.** Never show the list to suppliers; anyone who does loses access.
- **Eretz Israel Tours is the steward.** The app never calls the owner "Daniel", only "Eretz Israel Tours".
- **Crowdsourced, with no responsibility for mistakes.** Every supplier page and the terms say so. Members are asked to be careful and to report errors.
- **Objective feedback.** Opinions must be marked as opinions. Slandering a colleague, competitor or supplier means removal.
- **Privacy:**
  - EIT can see everything, and members are told this.
  - Colleagues never see each other's emails, phones or license numbers.
  - Private prices and files are possible.
  - Contact taps are logged and emails are BCC'd, with an opt-out. Both are disclosed in the terms.
- **Unverified data stays hidden.** Anything imported (from email, old sheets and so on) is hidden until EIT checks and approves it.
- **The frozen R5 builder is never modified.**

## 6. How it works (plain language)

**Joining**

1. A colleague opens the join link.
2. They fill in name, email, role, an optional license number and a photo of their license. They can tick "can't add proof now" and explain why.
3. They accept the terms.
4. EIT approves them.
5. They get a **personal link**. There is no password; the link is their key.

**Using it**

- **Opening the app.** It opens on that person's most-used suppliers. Category and region buttons are ordered by what *they* use most, and the list is shuffled daily so no supplier always comes first.
- **A supplier page** shows:
  - one-tap Call, WhatsApp, Email, Website, Waze and Maps buttons;
  - prices (adult, child, Israeli senior, group, Free) and quotes with options (room types, midibus vs coach);
  - deals (Cal, Cuponofesh), colleague notes, photos, receipts and price lists (with a black-out tool for private details), and a kosher certificate;
  - an **Agent prices** box with a sign-up link and a ready message asking the supplier for agent rates;
  - a **Food nearby** section;
  - a red **Update this supplier** button (closed, moved, wrong details, optionally anonymous).
- **Guides** have filters for Eshkol license, own Eshkol vehicle, Midbari 4x4 vehicle and carrying a gun. **National parks** sit under the Parks Authority, with reservation reminders.

**Changing things**

- Colleagues can add suppliers, prices, deals, notes and files freely.
- Changing a **locked** fact sends a request to EIT.
- Everything shows "From [name]".

**EIT's side**

- **Review tab:** supplier updates, feedback, change requests, new suppliers, and **Build R5 import file**.
- **Team tab:** join requests with proof, members, the BCC address, and an activity report of who tapped what.

**Under the hood:** one web page on GitHub Pages and a Supabase database in Frankfurt. All access goes through checked server functions; there is no direct database access.

## 7. Where I overlap with other EIT projects

| Project / skill | What we share | How they should see my work |
|---|---|---|
| **EIT Builder / Cockpit** (R5, v4.70+, cloud cockpit) | Supplier data. I produce an R5-format import file of approved suppliers | I am an **upstream data source**, outside their governance. My export must match R5's frozen field list and import wrapper. Importing blanks R5's trip view. IDs need matching to existing R5 vendors (pending an R5 vendor export from Daniel) |
| **Pricing** (`eit-pricing-steward`, `eit-pricing-intelligence`, `eit-trip-pricing`) | Supplier prices, agent vs public prices, VAT, receipts and price lists | Price lines here are **colleague-reported**. Check each line's source and date. A receipt or the supplier's own document attached here outranks a typed price. Old imported prices are private and marked unverified |
| **Supplier outreach** (`eit-supplier-rfq`) | Agent sign-up links, the "ask for agent prices" message, supplier emails BCC'd to `suppliers@eretzisraeltours.com` | Read agent links and how-tos from here. BCC'd emails in Gmail are a record of what colleagues asked suppliers |
| **Trip operations** (`eit-group-tour-ceo`, GGN) | Supplier contacts, kosher status, park reservation rules, food tips | Read from the list freely. **Never** put client or trip details in visible fields; they belong only in EIT's private notes |
| **Software oversight** (`eit-software-steward`) | Whether building this is worth the effort | Judge it on adoption and use (members, active colleagues, taps per week), not on freeze records |
| **Business strategy** (`eit-business-coach`) | The monetization ideas and the colleague network | The list builds goodwill and data. Sponsored offers are an idea only, with the trust rules above |

## 8. Skills I'd like other projects to write for me

1. **`suppliers-list-lookup`**
   - **Purpose:** let any EIT project answer "who do we use for X in Y region, and what does it cost?" from the live list.
   - **Behaviour:** read-only; respects private and hidden items; shows each price's source and date.
2. **`suppliers-list-steward`**
   - **Purpose:** a weekly check of what needs Eretz Israel Tours: join requests, change requests, supplier updates, feedback, hidden imports waiting for review, the terms version, free-tier usage and whether the keep-alive is working.
   - **Behaviour:** reports only; builds nothing.
3. **`suppliers-list-import`**
   - **Purpose:** house rules for bringing supplier data in from email, sheets, receipts or WhatsApp.
   - **Rules:** imported data lands hidden and pending with an "unverified" note; old prices are private; client names never go in visible fields; duplicates are caught by name and phone.
4. **`suppliers-to-r5`**
   - **Purpose:** move approved suppliers into the Builder safely.
   - **Steps:** back up R5 first; match IDs; check fields against the frozen R5 list; warn that the trip view blanks on import.
5. **`suppliers-list-change-rules`**
   - **Purpose:** standing rules for any AI changing the app.
   - **Rules:**
     - Never say "Daniel".
     - Never touch R5.
     - All access goes through token-checked functions.
     - Never expose members' contact details to colleagues.
     - Bump the terms version when the terms change.
     - Keep "From [name]" labels.
     - Test with sample data and a non-admin check.
     - Update the README and Project doc after every change.

## 9. Open items as of 1 October 2026

- Lawyer review of the terms.
- 41 imported suppliers waiting for EIT's check.
- An R5 vendor export from Daniel, so IDs can be matched.
- Confirming the free database's keep-alive actually works.
- Inviting the first wave of colleagues.
- AI auto-fill from receipts and screenshots (deferred).
- Monetization (ideas only).

## 10. Where to find things

- **App:** https://vendors.eretzisraeltours.com
- **Code and docs:** GitHub `Danielg972/eit-vendors`. Inside: `README.md` (running feature log), `docs/PROJECT_BRIEF.md` (this file) and `docs/AUDIT_2026-10-01.md` (technical audit).
- **Database:** Supabase project `wjuqtjlrtcywjaspjpwu` (org "EIT Vendors").
- **Claude Project:** "Vender Master Sheet", doc `claude/EIT_Vendors_app_status.md`.
- **Drive:** EIT Business Systems › 02 Vendor Master Database.
