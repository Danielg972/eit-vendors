# The Inner Circle – Israel Guide: decisions

*Called the Israel Suppliers Master List until 2 October 2026 (D-6).*

Decisions that bind this project. Newest first. Each entry says who decided, when, and on what evidence.

*D-12, D-14 and D-16 were built on the branch `guide-for-clients` at the same time as D-15, and rebuilt on top of it before anything of theirs touched production. See the note under D-15.*

*D-15 (limited members) was first recorded as D-12 by mistake, for a few minutes on 3 Oct; D-12 was already taken on that branch.*

---

## D-37 · The hike's map: marked trails drawn over it, a link to Mapeak; the route file box names the apps (live since 10 October 2026)

**Decided by:** the owner (Eretz Israel Tours), 10 October 2026, evening.

**In his words:** 20:17, "israel hiking map is now called mapeak. does that change anything? ... it even ha public hikes listed on it. can we use those and integrate mapeak into app?" 20:23, "lets try all of them and see whoich works best. i just sent the email.." 20:50, after trying the trial copy: "Open map showed the hike. Open in mapeak. Showed map but not hike. Yes 18202 how did you find that?" 20:55: "Marked trail layers are fine. The open map function is fine too. What if someone downloads the gpx can they get a pop up. Saying open in and chooses mapeak or amud Anan?"

**What was found about Mapeak (its own pages, read 10 October):** the same licence under the new name ("Tiles © Mapeak under CC BY-NC-SA 3.0"), a paid Pro subscription, terms that give no permission to show its map or copy its content elsewhere, and public routes that come from OpenStreetMap's trail records and from partners (Nakeb, KKL) by their permission. So Mapeak's map and its public routes are not taken into the app without Mapeak's written yes. The owner sent the request to support@mapeak.com on 10 October; no answer yet.

**What is live:**

- **Marked trails over the map.** Waymarked Trails' picture of the marked trails OpenStreetMap holds, laid over the hike's map on the page and on the open map, with the Israeli colour marks. A button on the open map takes it off and puts it back. Its terms, read on its own site: use on other sites is allowed at a moderate rate, with OpenStreetMap and Waymarked Trails named; both are credited on the map. The app takes and keeps no trail data.
- **"Open in Mapeak"** on the open map: a plain link to Mapeak's own map at the start of the hike. It shows the place, not the hike; nothing of the hike is handed to Mapeak.
- **The route file box.** On Android the phone itself asks which app opens a saved route file, and only after the file is tapped; the page cannot raise that question. The box now says so step by step, names Mapeak and Amud Anan, says that Mapeak is the new name of Israel Hiking Map, and after saving says what to tap next. This last part answers his question of 20:55 and went live with the rest; it is his to send back.

**Tried and not built:**

- **Reading a walk's trail colour from OpenStreetMap.** Around his walk from Har Gamal the records hold green 18202, red 18201, black 18240 and others; 29 of 30 points of his recording lie within 35 m of green 18202, and he confirmed it ("Yes 18202"), so that mark is now on his hike. The public look-up service answered one time in three and took seven seconds: fit for a look-up when a route is added, not for every phone.
- **Showing the hike itself in Mapeak.** Mapeak opens a route from a web address (`mapeak.com/url/` and the address of the file; seen to ask its own server for a sample file). That would need the hike's route to be fetchable for a short time by anyone holding the address, and hands the route to Mapeak: who sees what, the owner's. He asked about the saved file instead, which needs none of that.

**Who sees what:** unchanged inside the app. New to the outside: a phone showing a hike's map now also asks `tile.waymarkedtrails.org` for pictures of that area. It joins the privacy line still to be written for OpenStreetMap (terms, the week's release).

**Checked:** `hike_page_walk.py` 106 checks, `preview_walk.py` 200. On the trial copy in the owner's Chrome: the trails drew over his walk with their colour marks. On his phone, by his word: the open map showed the hike and Mapeak opened at the place.

**Not checked:** the reworded route file box on a phone.

---

## D-36 · Hikes open to every colleague; a box that says how to allow location (live since 8 October 2026)

**Decided by:** the owner (Eretz Israel Tours), 8 October 2026, 23:45 Israel time.

**In his words:** "So have a pop-up tell g them what to do and make the hikes live fore everyone. And can we add more hikes?" Sent after a picture from his phone of the open map on Ein Ovdat with the message "Your phone did not give its place. Allow location for this site, then try again."

**What that picture settled:** "Where am I" failed on his phone because Chrome there had not been allowed to use location for the site. The app was not at fault, but its message vanished after a few seconds and did not say where to allow it.

**What is done:**

- **The box** (`hkWhereHelp`). When the phone or browser refuses, a box stays on screen with the steps for that kind of device: Chrome on Android (and what to do when Location is not listed), an installed copy on Android, an iPhone, a computer. "Try again" asks the phone again. It says the member's place is drawn on his own screen and sent nowhere. Front end only.
- **Hikes are open to every approved member**: the setting `hikes_for` is `all`, set in the database the way the Team tab's own switch sets it. Colleagues and organisations now see the Hikes tab, the 33 hikes, and can add hikes (each waits for Eretz Israel Tours' approval) and reports. The switch on the Team tab turns it back.

**Opened on the owner's word with two things still open, both terms changes for the week's release (G13), neither yet written into the terms:**

- a line in the privacy notice that a hike's map is fetched from OpenStreetMap's server, which sees the phone's internet address and the area looked at;
- the no-responsibility line for hikes, which is also on the lawyer's list. The hike's page carries its own notice meanwhile.

**Checked:** `hike_page_walk.py` 97 checks (the box for Android, iPhone, computer, at 320 wide; "Try again", Escape, closing the map; no watch left running); `preview_walk.py` 200. After the setting: every approved member counted as seeing Hikes.

**Not checked:** the box on a real phone; whether the installed copy's "Site settings" step is worded as Samsung phones word it.

**The box rewritten, 9 October 2026, about 14:40, on the owner's word ("Rewrite in app how to fix location").** The first box sent him to the page of this one site, where there was no Location to switch: a site that was never asked is not listed there, and he uses the copy on his home screen, which has no Chrome menu. What worked on his phone was switching location on for Chrome as a whole. The box now gives the two switches that decide it on Android, in order: Chrome's own (Chrome, three dots, Settings, Site settings, Location), then the phone's permission for Chrome (Settings, Apps, Chrome, Permissions, Location), then "Try again". On the home-screen copy it says to open Chrome itself. It adds that switching these on only lets a site ask. It opens at its first line. iPhone and computer steps are unchanged. Which of the two switches was off on his phone is not known; he did not say. Checked: `hike_page_walk.py` 102 checks. Not seen: on a phone.

**"Can we add more hikes?":** yes. A second list is being put together for him to choose from, as the first was.

---

## D-35 · The hike's page: a real map with the route on it (live since 8 October 2026)

**Live since 8 October 2026, about 22:40, on the owner's word.** He tried the trial copy on his phone and wrote at 22:35: "Open map works full screen 2 where am I doesn't work file saves ask Israel hiking map Route saved. Make it live no one uses the app anyway". So, on his Android phone: the map opens full screen; the saved route file was taken by Israel Hiking Map (as this session reads his words); "Where am I" did not work. Why it did not is not known: he did not say what the phone showed. The likeliest cause was the app's own doing: he was far from the hike, and the first version then refused to show him at all. That is changed before go-live: his place always comes onto the map, the map widens to hold him and the hike, and it says how many kilometres away he is. If the cause was the phone not giving its place, the page says so and how to allow it. Pull request #31 merged (main 7fdb20c); front end only; D-34 went live with it. Seen on the live app a few minutes later, in the owner's Chrome on his computer: his hike Ein Ovdat opens with the real map, the route on it, Start and End, and the credit. The trial copy at `/next/` now only sends on to the app (pull request #34). Not seen since go-live: a phone.

**Decided by:** the owner (Eretz Israel Tours), 8 October 2026, 20:45 Israel time, after trying the trial copy of D-34 on his phone.

**In his words:** "The route on the page: new, so you can see the walk without any other app. It is a line drawing, not a map. It's a line not on any map... It's useless. The Google map start and end doesn't help either because it just opens Google maps. And you can't see both at once. Why can't you integrate open maps? Honestly I couldn't. Really tell the difference in old and new"

**What is built** (branch `hike-page-fixes`, on top of D-34; front end only, no database change):

- **A map leads the hike's page.** OpenStreetMap, with the recorded route drawn on it as a line and start and end marked together. It stays still on the page so the page scrolls under a finger. "Open the map", or a tap on the map, opens it over the whole screen: it moves and zooms, start and end each offer Waze and Google Maps to that exact point, and "Where am I" shows the member's own place against the route.
- **A hike with no recording** shows its start and end together on the map when their map links carry a point; the page says no route is recorded. A short Google link carries no point, so such a hike has no map until someone adds a recording.
- **Height along the walk**: a small chart of the recording's heights, above its length, climb, descent, lowest and highest point.
- **The page's order**: map, key facts in one band, "Open the map", region and status, warnings, the four tiles (Waze and Google Maps now say "to the start"), then the sections of D-34.
- **Gone:** the line drawing as the normal view (it is now only what shows when the map cannot load), and the four separate "where the recording starts/ends" buttons (they are on the map's own points).

**Where the map comes from, and on what terms:**

- **Map pictures:** OpenStreetMap's own server (`tile.openstreetmap.org`), free, under its tile usage policy, read 8 October 2026: the credit "© OpenStreetMap contributors" stays on the map, only what is on screen is fetched, nothing is fetched ahead or kept for use without a connection. The service makes no promise to stay up, and may block heavy use. With one user this is nothing; with the whole membership it is still light, but it is a service the app does not control.
- **The drawing library:** Leaflet 1.9.4 (BSD licence), copied unchanged from its published package into `vendor/leaflet-1.9.4/` (checksums compared), served from this site, loaded only when a map is first needed.
- **Israel Hiking Map**, the map guides know, with the trail colours: **not used.** Its tiles are licensed for non-commercial use, and its own FAQ says showing the map in another site is "in coordination with the authors" and commercial use needs their word. It is one address to change in the code once they agree. **Asking them is the owner's.**

**Who sees what:** unchanged inside the app. New to the outside: when a hike's page shows a map, the member's phone asks OpenStreetMap's server for the map pictures of that area, which shows that server the phone's internet address, the area looked at, and this site's address; nothing about the member or the hike. "Where am I" is worked out on the phone and drawn there; the place is sent nowhere (when the map widens to include the member, the pictures then fetched are of that area). **The privacy notice does not yet say this. It must before Hikes opens to colleagues** (a terms change, the owner's, G13). Today only Eretz Israel Tours sees Hikes.

**Checked:** `hike_page_walk.py`, 91 checks, map pictures stood in for (the test machine cannot reach OpenStreetMap): the line and points on the map, the credit seen and not covered, the still map does not trap scrolling, the open map, "Where am I" (near, far, slow, refused, and that the phone stops being asked when the map closes), a hike with start and end only, with an end only, with nothing; map pictures not arriving; the library or its style sheet not arriving. `preview_walk.py`, 200. A second agent attacked the first version: six faults and a list of small ones, fixed (GPS left running after a slow fix, a dead End point, a half-drawn map when the style sheet fails, the open-map button covering a point, the page saying a recording did not exist when it had only failed to load, a named Google place giving the middle of the screen as its point).

**Seen on the trial copy, 8 October, about 21:50, in the owner's Chrome on his computer:** his own hike Ein Ovdat with the real map: the map pictures came from OpenStreetMap, the recorded route lay on the trail the map draws, Start and End were marked, the credit showed, the figures read 2.09 km and a climb of about 120 m, and the open map came up with "Where am I" and "Whole route".

**Not checked, and it matters:** nothing on a real phone; iPhone; "Where am I" with a real phone's place; the phone's Back button does not close the open map (the app has no handling of Back anywhere).

**Open, the owner's:** whether "Where am I" works for him now, and what the phone says if not; asking the Israel Hiking Map authors; the privacy line before Hikes opens to colleagues.

---

## D-34 · The hike's page: laid out as a finished page, map links that open, a route file that can be used (live since 8 October 2026, with D-35)

**Decided by:** the owner (Eretz Israel Tours), 8 October 2026, about 18:30 Israel time, testing the live Hikes tab on his Android phone (Chrome, a Samsung) after adding a route file to his own hike.

**In his words** (spoken, as transcribed; "Anode dot" is his hike Ein Ovdat):

- "I uploaded a GPX file to Anode dot, and it the layout of the page does not look good. It looks like um, just the layout's not good. It doesn't look like a finished page. It looks like a tab. The edit page looks better, now the start and finish destination Google Map link doesn't open, doesn't show me anything. First start and end."
- "GPX file when I tried to open it it didn't open in any kind of app."
- With a picture of the route file box showing "Could not hand the file over. Save it instead.": "Ein ovdat android". Asked whether a hiking app is installed on that phone: "Yes".

**What was found:**

- **Route file.** The box offered "Open in a hiking app" because the browser said it could pass a file on. Chrome on Android then refuses a GPX file (it passes on pictures, sound, video, text and PDF only), which is the message he got. The stored file was whole: 3,365 points. Whether the saved file then opens depends on a hiking app on the phone that takes GPX files; that part has not been seen on a phone.
- **Start and end.** His start and end are pasted Google Maps short links. The page did build the right link (seen in a phone-sized test: a tap opened a new tab on that address). Why his phone showed nothing is not known. The likely cause is that a short link opened in a new tab is left as an empty tab when the phone tries to pass it to the Maps app. It is a guess until he tries the change.
- **Layout.** The page was a region line, four tiles and one long list of rows; the form, with its named groups, read as the more finished of the two.

**What was built** (front end only, `index.html`; no table, function, grant or policy change):

- **The page is in sections:** the key facts first (distance, usual time, difficulty) as three tiles, then the warnings (cliffs, firing zone), the Waze / Google Maps / Route file / Add report tiles, then "Getting there" (start and end), "The trail" (markers and the route), "The place" (the park, as before), "Important notes", the reports and "Before every trip". Nothing the old page showed is gone.
- **Start and end** each show their words, then a Google Maps button and a Waze button, each only when the place gives it something to go by: Google Maps takes a Google Maps link from the text, else the point a Waze link carries, else a search for the words; Waze takes a Waze link, else the point a Google Maps link carries, else the words. Nothing is searched by the hike's name any more (the two tiles at the top still fall back to it). A place that is only a pasted link says "A pin on the map".
- **On Android a map link asks the phone for the app itself** (Google Maps or Waze), and carries the web address as the way out when the app is missing. Elsewhere, and inside a bare in-app web view, it stays an ordinary link in a new tab. Only an address the page accepted as Google Maps or Waze, or built itself, is ever turned into an app link, and the app is named by the page, never by the address.
- **The route is drawn on the page**: the recorded line, north at the top, with its length, climb and descent (moves of 10 m or more only, shown as "about"), lowest and highest point, and buttons that open the first and the last point of the recording in Google Maps and Waze. Parts of a track are kept apart, so a gap is neither counted nor drawn; a file with a track and a route uses the track. It says it is a sketch, not a map. The file is fetched once per hike and version when its page opens.
- **The route file box** no longer offers handing the file to an app on Android. It says what to do: save the file, open it from the hiking app (or tap it in Downloads and choose the app), and that nothing can open it until such an app is installed. Where a browser offers to pass the file and then refuses, the dead button goes and the same steps show.
- **The file handed over** is the stored route with three things added around it: the XML opening line, and the hike's name on the file and on its track, so a hiking app shows a name. What is stored is unchanged.

**Who sees what:** unchanged. The route file was already open to every member who can see the hike; the page now fetches it when the hike opens instead of when the button is tapped.

**Checked:** `supabase/tests/hikes/hike_page_walk.py`, new: 58 checks as an Android phone at 411, 360 and 320 wide, an Android in-app web view, an iPhone-like browser that passes files on, one that offers and refuses, and a computer; the page's own helpers are called with made-up routes and places and their figures and links compared with figures worked out in the test. `preview_walk.py`: 200 checks; it now ends with a failing exit code when a check fails. A second agent attacked the first version (security of the app links and the markup, the route figures, the layout at five widths, the tests themselves) and its findings were fixed: a fact tile cut off on 360-wide phones, a file broken by some hike names, figures wrong for files with more than one line, climb overstated on noisy heights, "start and end in one place" judged in picture dots, and seven faults the tests did not notice.

**Not checked, and it matters:** nothing here has been seen on a real Android phone. The app links follow Chrome's documented form, and whether they cure "doesn't open" is not known until the owner taps them. Whether a saved route file opens in Israel Hiking Map or Amud Anan on his phone is not known either. iPhone Safari, Samsung Internet and Firefox were not run.

**Open:**

- The supplier pages' Waze and Google Maps buttons are still ordinary links in a new tab. If the app links cure the fault on his phone, the same change belongs there; if those buttons already work on his phone, the cause of fault 2 is something else.
- A route file opened in one tap in Israel Hiking Map needs a web address the map's site can fetch the file from, which would be a new, public, short-lived link to a route file: the owner's decision (who sees what), and the site's way of opening a file by address has to be confirmed first.
- A real map under the line (a map library and map tiles from another site) was left out on purpose: a new outside dependency is the owner's call.

**Status:** built on the branch `hike-page-fixes`. **Not live.**

## D-32 · Hikes and parks: a hike names its park, parks hold brochures, start and end open Google Maps (live for Eretz Israel Tours since 8 Oct 2026)

**Decided by:** the owner (Eretz Israel Tours), 8 October 2026, between 15:12 and 15:34 Israel time, a few minutes after the Hikes tab went live (D-31).

**In his words:**

- 15:12: "Some hikes are connected to national parks. for instance right now I want to add Ein ovdat which I just did today and it's part of that nature reserve perhaps for something like that a see the link hike should be there which will take you to the hike page also for the national parks they all have brochures. There should be a place where they're uploaded."
- 15:14: "Also start and end. Location should. Open Google maps"
- 15:21: "Also the moked teva page link. Only opens general.. Nothing specific to this hike"
- 15:34: "Also, most places that have hikes have different variations of hikes. Like Ein Gedi might have Nachal David. Or the D-U-D-I-M caves. Etc. There are many ways to do Nachal Prat also. So one card should have many different hike options."

**How it was read:**

- A hike can be connected to the supplier it lies in: the national park, nature reserve or site. The link works both ways. The hike's page names the park and opens the park's page; the park's page lists its hikes and opens each one.
- A park's page has a place for its brochure. Brochures are a new kind of file on a supplier, next to photos, price lists and the rest, and show near the top of the page.
- On a hike's page the start and the end are each tappable and open Google Maps.
- The links under "Before every trip" should be about this hike. Moked Teva has no page for one hike that could be linked to (its site could not be read from the session to check), so the park's own page comes first and Moked Teva is named as the whole-country page it is.
- A place with several hikes is one card in the list, holding every hike there. The place is the park or site the hikes are connected to, so this needs nothing new in the database. A hike connected to no place stays on its own.

**What was built:**

- **The hike form** has a field "Part of a park or site". It offers the suppliers the member can see whose category, or one of their "also offers", is National Parks or Attraction / Site: None first, then the places in the hike's region, then the rest by name. With more than eight places a search box narrows the list.
- **The hike's page** shows "Part of" with the park's name, which closes the hike and opens the park's page. Under it: the park's opening hours and last entry as its own page holds them, marked Verified or Unverified; "Book entry" when the park has a booking link (web links only, in a new tab); "Brochure" when the park has one (several open a short list).
- **The park's page** shows its brochure near the top, under the hours, and a section "Hikes here" with each hike's name, distance and usual time, and "Add a hike here", which opens the hike form with the place and its region chosen. A supplier that is not a park or site and has no hikes shows nothing. A park or site with no brochure offers "Add brochure".
- **The list of hikes** shows one card per place inside each region: the place's name, how many hikes it has, and under it every hike there. The card's head opens the place's page. Hikes connected to no place share a plain card below. The search finds a hike by its place.
- **Before every trip**, on a hike's page: first the park's own page, when the hike has a park and the park has a website ("its own page, for closures and changes"), then Moked Teva, worded as trail updates and firing zones for the whole country, with a line saying it has no page for one hike.
- **Start and end**, on the hike's page and inside each report, open Google Maps in a new tab. Only two kinds of link are ever built: a Google Maps link found in the text (the same test as the buttons at the top), or a Google Maps search for the text. A Waze link in the text is never opened as Google Maps: the search is used, by the text, or by the hike's name when no text is left. Any other link in the text stays text. The Waze and Google Maps buttons at the top are as they were.

**Who sees what:**

- A hike never shows a supplier to a member who cannot open that supplier. The database sends the park's id only when the supplier exists, is not hidden, and the member is Eretz Israel Tours or has the supplier's section (`_hike_park`). To anyone else the hike reads as having no park: no name, no hours, no booking, no brochure. An organisation without the sites section gets every hike, and no park on any of them.
- A member can only connect a hike to a supplier he can see himself; anything else is refused with "Choose the place from the list."
- Brochures are open to every member who can open the supplier, organisations included, like photos and kosher certificates. A brochure marked "only me and Eretz Israel Tours" stays private. An organisation still never gets a guide's or agent's price list, receipt, contract, booking confirmation or quote.
- Names only, as before: nothing here sends a member's email, phone or licence number.

**Implementation choices, his to change:**

- The link is the supplier's id on the hike, with no foreign key. A supplier taken off the list, merged or hidden leaves the id where it is, and the hike reads as having no park until the supplier is there again.
- A hidden supplier reads as no park for everyone, Eretz Israel Tours included, and cannot be chosen.
- An older copy of the page, which does not send the park, leaves it as it is. The page itself sends the park with a new hike, and with a change only when the member changed it in the form: a member who cannot see a hike's park is shown None, and his save of another field does not take the park off.
- Setting or changing the park on a waiting hike counts as a change to it, like any other field: an approval of the version read before is refused (D-31).
- The picker offers National Parks and sites only. **Which other suppliers should be offered is the owner's to widen.**
- The hours on a hike's page are shown as text with Verified or Unverified. Marking hours as verified stays on the park's own page.
- "Book entry" and the brochure open in a new tab without passing the app's address on.
- Preview mode has three sample parks and sites (real place names, every detail invented and marked as a sample), three sample hikes connected to them, one sample brochure, and a second sample organisation that has no sites section, to show what such a member gets.

**Database, two files:**

- `supabase/migrations/2026-10-08c_brochure_kind.sql`: one statement, the list of kinds a supplier's file can have gains Brochure. It takes the old list off and puts the new one in its place, so **the owner runs it himself in the SQL editor** (rulebook G5). Safe to run twice. It must be run before the new files function and the new page go live.
- `supabase/migrations/2026-10-08b_hikes_parks.sql`: adds and replaces only, safe to run twice. One new column, `hikes.vendor_id`, with a length check and an index. One new internal helper, `_hike_park`, not callable from outside. Three functions replaced: `_hike_json` (one new key, `vendor_id`), `hike_save` (takes the key `vendor_id`; everything else, its lock order and every earlier check as they were) and `_file_visible` (Brochure joins Photo and Kosher certificate as a kind open to organisations). 154 functions become 155.
- The files edge function, version 12 in the repository: Brochure added to the kinds it takes and to the kinds open to organisations. **Not deployed.**

**Checked (on a local PostgreSQL 16):** a database built from `supabase/schema.sql`, one built from the schema before D-31 with all three files run twice, and one built from the schema on `main` with files c and b run twice each have the same functions, the same roles allowed to call each one, the same columns, constraints, indexes and triggers on every table, and the same privileges and row security on every table and sequence. 225 checks in `supabase/tests/hikes/` as Eretz Israel Tours, two guides and two organisations (156 before); the 98 limited-member checks still pass; the probe for the live database returns what its header lists on the local copies and leaves nothing behind. In preview (`supabase/tests/hikes/preview_walk.py`), 186 checks at phone and desktop size as Eretz Israel Tours, a guide, an organisation that sees sites and one that does not, with no page errors and nothing running off the side of the screen (84 before).

**Not checked:** production (nothing has been run there); PostgreSQL 17; the files edge function, which was changed by hand and read, not run (no Deno on the build machine; its text passes a syntax check only); uploading and opening a real brochure through the live files function; a real phone; whether a tap on start or end opens the Google Maps app on a phone; Safari and Firefox. No second session has tried to break this change yet (D-31 had four such rounds).

**Open:**

- **For the lawyer's list:** brochures are the Parks Authority's own handouts. Members upload them for colleagues' use inside the app only. They are never placed on a client-facing page. Whether keeping copies for colleagues is in order is a question for a lawyer.
- Which suppliers besides National Parks and sites the picker should offer: the owner's to widen.
- The line in the terms, and the Hebrew side, as for D-31.

**Status: live since 8 October 2026, about 16:40 Israel time**, on the owner's word at 16:31 ("Make. Them live."). Hikes are still open to Eretz Israel Tours only, so colleagues see the brochure kind and nothing else of this until he opens Hikes. In order: the owner ran `2026-10-08c_brochure_kind.sql` himself in the SQL editor (16:33, "I think I did it in supabase"; the list of kinds was read afterwards and holds Brochure); `2026-10-08b_hikes_parks.sql` went through the connector in two parts (`hikes_parks_2026_10_08b_part1_column_helper_hike_json`, `part2_hike_save_file_visible`); all 155 function fingerprints equal `supabase/tests/hikes/expected_fingerprints.txt`, with 30 tables, 91 functions callable from outside, 0 table grants and 0 policies; the files function was deployed as version 12 and its deployed source read back equal to the repository file; `supabase/tests/hikes/production_probe.sql` returned every expected value and left nothing behind; then pull request #30 was merged by the session. Not checked: the files function answering a real call (the session cannot reach it), a real upload of a brochure, the live page in a browser, a real phone.

---

## D-31 · Hikes: official marked trails, with a report after the walk (live for Eretz Israel Tours since 8 Oct 2026)

**Live since 8 October 2026, about 15:02 Israel time, for Eretz Israel Tours only.** The owner merged pull request #28 himself at 14:57 ("Merged"). The database file was then run on production through the connector, in parts (`hikes_2026_10_08_part1_tables` to `part5_set_setting_whoami`), with `whoami` last so the tab appeared only once everything behind it was in place. Checked after (G4): 30 tables, 154 functions, 91 callable from outside, 0 table grants, 0 policies; all 154 function fingerprints equal `supabase/tests/hikes/expected_fingerprints.txt`; the three new tables equal the schema record (columns, constraints, indexes, row security); `supabase/tests/hikes/production_probe.sql` returned every expected value and left nothing behind (0 hikes, 0 reports, 0 route files, no probe member, no `hikes_for` row). Colleagues do not have the tab: `hikes_for` is not set, which reads as Eretz Israel Tours only. Not checked: the live page in a browser (no browser was reachable from the session), a real phone, a route file opened in a hiking app.

**For the next session that sends SQL through the connector:** the connector turns a written-out character code of the form backslash-u-four-hex-digits into the character itself before the SQL reaches the database. `_hike_gpx_put` arrived with the two characters instead of the two codes: same behaviour, different text, so its fingerprint differed. It was sent again inside a `do` block that swaps a placeholder for the backslash (`hikes_2026_10_08_part2b_gpx_put_exact_text`), and now equals the repository to the letter. Other backslash forms (`\.`, `\s`, `\x01`) arrive unchanged. Compare fingerprints after every part, before the part that switches a feature on.

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 8 October 2026, in steps between 09:14 and 12:06 Israel time.

**In his words:**

- 09:14: "Put in the pipeline a hikes tab - gpx, important notes, distance, how long it typically takes. If putting in for after then group size, ages, difficult level, cliffs (fear of heights), water shoes, start location, end location, points of interest, firing zone, water, bathrooms, can you eat on hike. Etc."
- 09:17: "We can scrape websites for hiking in Israel like hiking the holy land, trail, lovloveisrael, any others?facebook?reddit, Hebrew and English, as well as מוקד טבע, sort by region"
- 10:45: "2 I think to enter after hike 3 yes and can update 4 yes as long as it's been updated in last few years. Any Israel hiking websites Agreed on all points. We take no. Responsibility for the info on the app message or disclaimer" (2 = the longer list is a report entered after the hike; 3 = organisations see hikes and can update; 4 = hikes may be taken from websites.)
- 11:34, of the mock-up: "Can you add trail markers and numbers"
- 11:53, of the mock-up with the choices listed: "Looks great!"
- 12:06: "I think build it now, why not? Number two, I don't know what trail means. It has to be an official marked trail. Hiking trail number or color is not mandatory. You can write for 3 , unverified. And aside from that, GPX needs to open on an app. You can offer suggestions. Israel hiking map.  Or Amud aNan."

**What it is:** a Hikes tab. A hike is an official marked trail: its name and region, a route file (GPX), important notes, the distance and the usual time, where it starts and ends, and the trail markers on the way (colour and trail number, in walking order, both optional). After walking it, a member adds a report: the date, group size, youngest and oldest, difficulty, cliffs, water shoes, points of interest, firing zone, water on the route, drinking water, bathrooms, whether you can eat on the way, and anything else. The hike's page shows a summary of the reports and each report with the name of who wrote it.

**The rules he set:**

- Only official marked trails are listed. The form asks for a tick; without it nothing is saved.
- Hikes are shown sorted by region.
- Organisations (limited members) see hikes and can add hikes and reports, like every other member.
- Hikes may be taken from Israeli hiking websites, in Hebrew or English, when the page was updated in the last few years. With the mock-up he accepted 3 years. A page that shows no date is taken and shown as Unverified, "date not known".
- What is taken from a website is its facts in the app's own words, with a link to the page; the page's text, pictures and route file are not copied. A hike from a website shows as **Unverified** until a member has reported walking it (rulebook E2). Facebook and Reddit are not read in bulk.
- A route file comes from a member's own recording or a route he drew on an open map. It must open in a hiking app; the app names Israel Hiking Map and Amud Anan.
- The firing zone answer says only whether the route crosses one. The app never says a route is open.
- Group size and ages are numbers. No client's name and no trip details go in any field (rulebook D6, D7).
- The app carries a message that no responsibility is taken for hike information. Wording as he approved it on the mock-up: "Hike details are colleagues' reports and notes taken from websites. Eretz Israel Tours and the members take no responsibility for them. Check the route, the weather and any firing zone yourself before every trip."

**Accepted with the mock-up (11:53), his to change:** any member may add a hike, and a new one shows to colleagues once Eretz Israel Tours has approved it; the Hikes tab sits between Quotes and Jobs; a report shows its writer's name; every hike links to Moked Teva's safety pages; markers are entered with the hike, not with the report.

**Implementation choices, his to change:**

- A member can change his own hike while it waits for approval. Once it is approved only Eretz Israel Tours changes it; everyone else has "Suggest a change", which goes to Feedback with the hike named.
- Eretz Israel Tours approves the version it read. If the writer changed the hike, its route file or his own reports on it after that, the approval is refused and the hike has to be opened again.
- Nothing is ever removed from the database: a hike taken off the list, a report taken off and a route file taken off are marked and kept. Eretz Israel Tours can put a hike back.
- One route file per hike. A report can bring a route file only when the hike has none.
- Only the route is kept from a file: its points, their heights and the names of marked spots (up to 200 spots, 60 characters a name). The recorder's name and email, the date and times of the walk, the name he gave the recording and the file's own name are left out: the page writes a new file from the points alone before sending it, and the database takes that form and nothing else. Every route file is called `route.gpx`; when saved it takes the hike's name.
- The summary takes the most common answer, except cliffs and firing zone: one report saying yes is enough.
- In a start or end place, only a Waze or Google Maps link becomes a button; any other link stays as plain text.
- A member may add 20 hikes and 30 reports a day.
- Reports of an organisation are marked "Organisation". Organisations read all reports on hikes (they read guides' reviews of suppliers on transportation only, D-15; a hike is not a supplier).
- The 3-year rule is asked when a hike is added or its page year is changed, not when an older entry is corrected.
- The message about responsibility is in the app from the start. The matching line in the terms waits for the week's terms release (rulebook G13) and for a lawyer; **no terms change is in this branch**.

**Opens to Eretz Israel Tours first (rulebook G2):** a new setting, `hikes_for`: `admin` (only Eretz Israel Tours; the default) or `all`. The switch is in the Team tab.

**Database (`supabase/migrations/2026-10-08_hikes.sql`; it only adds and replaces):** three new tables, `hikes`, `hike_reports`, `hike_gpx`, closed like every other table (row security on, no grant, no policy). Six new internal helpers (`_hikes_on`, `_hike_visible`, `_hike_markers_clean`, `_hike_json`, `_hike_detail_json`, `_hike_gpx_put`), none callable from outside. Seven new calls: `hikes_list`, `hike_detail`, `hike_save`, `hike_decide`, `hike_report_save`, `hike_report_hide`, `hike_gpx`. Two functions replaced, each gaining only the hikes switch: `whoami` (two new keys, `hikes` and `hikes_for`) and `set_setting`. 141 functions become 154.

**Not in this branch:** loading hikes from websites (a data job for after the tab is live, each source first read for what it allows); a map on the page; the Hebrew side; a line in the welcome tour; the terms line.

**Checked (on a local PostgreSQL 16; production is PostgreSQL 17, see Not checked):** a database built from `supabase/schema.sql` and one built from the schema before this change with the file run twice have the same functions, columns, constraints and indexes; 156 checks in `supabase/tests/hikes/` as Eretz Israel Tours, two guides and an organisation; the 98 limited-member checks still pass; the probe for the live database returns what it should on the local copy and leaves nothing behind. In preview (`supabase/tests/hikes/preview_walk.py`), 84 checks at phone and desktop size as Eretz Israel Tours, a guide and an organisation, with no page errors. A second session that wrote none of it tried to break it in four rounds, on the database and through the page. It found, among smaller things: a hike could be swapped between the moment Eretz Israel Tours read it and the approval; a route file could carry the recorder's name, email and times, and its own file name; a crafted route file could keep the database busy for minutes; a save already under way could land on a hike just approved. All of it was fixed and is in the checks; its fourth round found nothing it would hold the change for, and the three small points it raised then were fixed afterwards and are covered by the author's checks only.

**Not checked:** production itself (the file has not been run there); PostgreSQL 17; a real phone; opening a route file in Israel Hiking Map or Amud Anan, which depends on the phone's own "open with"; Safari and Firefox.

**For a lawyer, before it opens to colleagues:** the message about responsibility (a notice may not remove responsibility for safety information); reports that name where and when a group walked; taking facts from other websites.

**Status:** built on the branch `hikes-tab`. **Not live.** The database file has not been run on production and nothing is merged.

---

## D-30 · A real client's details never appear anywhere public; example text and sample data are invented (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 7 October 2026, 13:11 Israel time, after a read-only report.

**In his words:** "replace it" and "rewrite history and make a rule that private client data never shows up publicly for anyone".

**What was found:** the example text in the box "For which trip or client? (private)", in the quote form and in the booking sheet form, and two lines of the preview's sample data, used a real client's family name. The sample quote also repeated that trip's first day, head count and the date the quote was received. Every member saw the two example texts. This repository is public, and anyone can download the page file without a member link.

**The rule (rulebook D7):** nothing about a real client or a real trip goes anywhere that is public or that members can see. That covers the code, example text, sample data, tests, the files in this repository, commit messages, pull request and issue text, preview pictures, and any document shared outside Eretz Israel Tours. Example and sample data are invented, say "Sample", and do not copy a real trip's name, dates, head count or prices. A real client's details stay in Eretz Israel Tours' private notes and private Drive. Before a session pushes anything, it searches what it is pushing for the client names in those private records.

**What was changed:**

- Both example texts now read `Sample family, May 2027`.
- The preview's sample booking sheet is labelled `Sample family, Nov 2026`.
- The preview's sample quote is titled `Sample family, 6 days`, with invented dates (7–12 March 2027), 16 people, received 1 September 2026, valid to 28 February 2027.
- Front end only (`index.html`, four lines). No database change, no terms change. The example texts are hints in an empty box, and the sample data runs only in preview, so nothing a member can do changes.
- The history of this repository is to be rewritten so that the name is in no commit of any branch. Not yet done; see `docs/STATUS.md` for where that stands.

**Checked:** in preview at phone size as Eretz Israel Tours and as an organisation: both forms show the new example text; the sample quote and the sample booking sheet show under their new labels; the Quotes tab draws; no page errors; the name is nowhere in the page that is served or in any file of the repository. On the live site after the merge, read once, read only: the page it serves holds the new example text twice and the name nowhere. Pull request, issue and comment text on GitHub was searched for client names: none. **Not checked:** nobody has opened the two forms on the live site.

**Status:** the replacement is live since 7 Oct 2026, about 13:16, on the owner's word of 13:11 ("replace it"); pull request #25. The rewrite of the history is NOT done.

---

## D-29 · Prices on a driver's or bus company's page: every vehicle size, airport transfers to and from Ben Gurion, agent price (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 7 October 2026, 12:31 Israel time. He had just added an independent van driver with five vehicle sizes and airport transfers.

**In his words:** "pricing for drivers needs to have all of the options of vehicle size. it needs airport transfer Ben Gurion - (add City) and (add city) Ben Gurion needs agent price".

**Decision:** on a Transport supplier (an independent van driver or a bus company) a price says which vehicle size it is for, an airport transfer says which way and which city, and the price is entered as an agent price.

**Changed the same day, on his word at 12:43, after the first preview:** "i think it should be in a dropdown format of all the relevant pricing - a list is too daunting". It could mean the form or the list of saved prices, so both were changed and shown to him again.

**What was built (implementation choices; change on request):**

- "Add price" on a Transport supplier is a short form of drop-downs. **What is the price for?** is one drop-down: Airport transfer Ben Gurion → city, Airport transfer city → Ben Gurion, Airport transfer both ways at the same price, Day rate, Per hour, Something else. The "both ways" choice was not asked for; it is saved as one line marked "each way".
- **City** (for a transfer) is a drop-down of 39 towns that ends with "Another city…", which opens a box to type any city.
- **Vehicle size** is a drop-down of all seven sizes (bus, midibus, the four van sizes, car). It is required for a transfer, a day rate and an hourly rate. A driver with one size has it filled in.
- **Agent or public price?** is a drop-down, "Agent price" first and the default, and the price box is named after the one chosen ("Agent price, one way"). An organisation never sees this choice and its line is never an agent rate (C3), as before.
- Season and the note are folded under one line, "Season, extra charges, a note". Where the price is from and the date it was checked stay in view (E4).
- Not asked for: **"Save + add another"**, which opens the next line with the same kind, city, vehicle, VAT and source, so a driver's whole list can be typed in a row.
- **On the supplier's page** a Transport supplier's prices are no longer one long list. They sit under headings that open on a tap: Airport transfers, Day rate, Per hour, Other prices, each with its count. With more than one vehicle size on the page, a **Vehicle size** drop-down above them keeps only that size. With three prices or fewer the groups start open. Inside a group a line is named without repeating the heading ("Ben Gurion → Jerusalem · Van, up to 8 seats").
- The kind, the route and the vehicle are written into the line's name ("Airport transfer: Ben Gurion → Jerusalem · Van, up to 8 seats"). Front end only (`index.html`): no table, column or database function changed, so who sees a price is exactly as before. Lines already on the list are untouched; they open under "Something else" and are listed under "Other prices".
- A transfer is saved per vehicle, a day rate per day, an hourly rate per hour; "For", child ages and group size are not asked for those three.
- Suppliers that are not Transport keep the form and the flat price list they had.

**Checked:** in preview, 52 checks at phone and desktop size as Eretz Israel Tours, as a colleague and as an organisation: every vehicle size offered; both directions and both ways; a city from the list and a typed city; agent and public; the refusals (no city, no vehicle size); the groups, their counts, the size drop-down; edit opens a saved line with its parts set; an older free-text line saves unchanged; "Save + add another" keeps "Suggest for everyone" and the reason; an organisation's line is an organisation rate and it is shown no agent rate; a jeep supplier's form and list are as before; no page errors. 160 names written and read back the same. **Not checked:** on the live site; on a real phone; by a session other than the one that built it. The limited-member database checks were not run again because the database is not touched.

**Status:** live since 7 Oct 2026, about 13:00, on his word at 12:57: "go live". He was shown two sets of preview pictures first; the second, the drop-down form and the prices in groups, is what went live. Front end only. No terms change, no database file. Not yet tried on the live site by a person.

---

## D-28 · Gaza Envelope is a region (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 17:37 Israel time.

**In his words:** "add Gaza Envelope - עוטף עזה as a region".

**Decision:** the region list gains **Gaza Envelope - עוטף עזה**, written as he wrote it.

**What was changed (implementation choices; change on request):**

- It sits after "Negev & Arava" in the list. It is offered wherever a region is chosen: the supplier form, where a driver is based, and a job.
- As with every region, its button on the supplier list appears once a supplier a member can see is in it.
- Front end only (`index.html`, one line). The database takes any region text up to 60 characters, so nothing changes there.

**Suppliers moved into it, on his word:** four suppliers that were under "Negev & Arava", all four hidden and waiting for review: Burnt Vehicles Compound (Tkuma), Garden of Heroism and Remembrance (Sderot), Nova Festival Memorial Site (Re'im), The Salad Trail (Talmei Yosef). Asked whether to move them, he said at 17:42: "yes to both". Only the region of those four rows was changed.

**Checked:** in preview at phone and desktop size: the region is offered on the supplier form and is saved as chosen; with one sample supplier placed in it, its button shows on the list and filters to that supplier. No page errors. **Not checked:** on the live site.

**Status:** live since 5 Oct 2026, about 17:45, on his word at 17:42: "yes to both" (go live, and move the four suppliers). Shown the preview picture first. Front end only, plus the region of four supplier rows. No terms change. Until one of the four is approved or another supplier is put in the region, colleagues see it in the forms but not as a filter button.

---

## D-27 · "Did they check your reservation?" is asked at national parks only (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 17:23 Israel time.

**In his words:** "shimshons farm is private and i got a popup about reservations, that isnt relevant there".

**Decision:** the question whether a reservation was actually checked belongs to national parks, where booking is the official rule and the gate does not always ask. A private supplier is booked with the supplier, so there is nothing to report.

**What caused it:** the reservation bar and its one-time pop-up were built for national parks. Since the supplier findings import of 4 October, 38 suppliers that are not parks carry a reservation setting (activities, museums, wineries, restaurants): 19 "required", 16 "recommended", 3 "not needed" (read from the live database on 5 October, 17:40). The pop-up opened on the 19 marked "required", 9 of which colleagues can see; the "They checked / Not checked" buttons showed on all 35 marked "required" or "recommended", 18 of which colleagues can see.

**What was changed (implementation choices; change on request):**

- The pop-up, the "Colleagues reported" line and the "They checked / Not checked" buttons show only on entries in the category National Parks. Parks are unchanged.
- Any other supplier with a reservation setting shows one plain line and no question: "Book ahead: by reservation only", "Reservation recommended" or "No reservation needed". The wording "Book ahead: by reservation only" is the session's, in place of "Reservation officially required".
- The "Reserve ahead" label on the supplier list is unchanged.
- Front end only (`index.html`). Nothing in the database changes and no supplier's setting was changed.

**Left as it is:** one answer already given on a private supplier (Eretz Israel Tours, "they checked", Shimshon's Farm, 5 October at 17:21) stays in the database and no longer shows anywhere. Removing it is a delete, which is the owner's to run.

**Checked:** in preview, before and after, at phone and desktop size, as Eretz Israel Tours and as an organisation: a private supplier marked required, recommended, not needed and not set; a national park marked required. No page errors. **Not checked:** on the live site.

**Status:** live since 5 Oct 2026, about 17:40, on his word at 17:34: "yes go live". Shown the before and after pictures first. Front end only. No terms change.

---

## D-26 · "Hours counted from": "Leaving the depot" becomes "When the bus turns on" (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 16:47 Israel time.

**In his words:** "Hours counted from / The pick-up  Leaving the depot  - change leaving the depot to from time bus stops". That could be read three ways, so he was asked what the second choice should say, and answered: "when the bus turns on".

**Decision:** the second choice under "Hours counted from" reads **When the bus turns on**. The first, **The pick-up**, is unchanged.

**What was changed (implementation choices; change on request):**

- English: "When the bus turns on" on the guide's form, "when the bus turns on" on the sheet and on the company's page, and in the plain WhatsApp message with blanks.
- **Hebrew:** "התנעת האוטובוס", so the sheet reads "השעות נספרות מ־ התנעת האוטובוס". It replaces "היציאה מהחניון". Proposed by the session; shown to him and approved at 17:18 ("yes and make live").
- What is stored does not change (the value is still `depot`), so nothing in the database changes and a sheet that already holds this choice simply reads the new words.
- **The quote a confirmed sheet leaves** in the Quotes tab already says "Hours counted from when the bus turns on.": the owner ran `supabase/migrations/2026-10-05c_quote_wording.sql` himself at about 17:15 (see D-25).

**Checked:** in preview at phone size: the guide's form, the company's form, and the finished sheet. **Not checked:** on the live site; whether bus companies read "התנעת האוטובוס" the way he means it.

**Status:** live since 5 Oct 2026, about 17:25, on his word at 17:18: "yes and make live". Front end only. No terms change. With the database file he ran at 17:15, the sheet and the quote of a confirmed sheet now use the same words.

---

## D-25 · The guide can leave terms off a booking sheet, by tick box (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 15:44 Israel time.

**In his words:** "can make "all of the terms youre expecting" removable by box. meaning if i want to send without the "tip" or ;mileage etc". In the same message he settled the open point of D-24: "keep" (the optional "Where to" for each day stays).

**Decision:** each of the terms on a booking sheet can be taken off that sheet with a tick box.

**How it was read (his to correct):** a term left off is off the sheet altogether. The company is not asked about it, neither side's sheet shows it, and it is not flagged as "not stated". Leaving a field empty already meant "I don't propose anything here, the company fills it in"; this is the further step of not asking at all.

**What was built (implementation choices; change on request):**

- **Eight tick boxes** at the top of "Terms you expect", all ticked to begin with: Hours and overtime (hours in a day, where they are counted from, the extra hour), Mileage (km in a day, the extra km), Kvish 6 and tolls, Parking, Driver tip, Cancellation policy, Other extras, Payment. **The price and its VAT cannot be taken off.** "Anything else" stays as free text.
- **Unticking a box** takes its fields out of the form, keeps what was typed in the others, and leaves that term off the sheet the company gets: its page does not ask for it, and the plain WhatsApp message with blanks does not list it.
- **The warnings follow:** nothing left off is listed under "not stated", and with Cancellation policy left off the company is not warned that it left the policy empty.
- **Stored** in one new column, `bookings.terms_off`. The database also drops a term that was left off from anything the company sends, so it cannot be added back from the company's side.
- **Part of what both sides accept:** taking a term off (or putting one back) after the company accepted clears its acceptance and sends the sheet back to it. A term put back comes back empty and is asked again.
- **The sheet's closing line is unchanged:** "Anything not written here will not be charged." So a term left off is one the company cannot charge for under the sheet. Whether that wording holds up is one of the points already listed for a lawyer (the booking sheet's closing line).
- **The quote a confirmed sheet leaves** in the Quotes tab says nothing about a cancellation policy that was left off the sheet. This part came later the same day: it sits in the one function the connector will not send without his confirmation, so the owner ran `supabase/migrations/2026-10-05c_quote_wording.sql` himself at about 17:15 ("done"). The same file makes the quote say "Hours counted from when the bus turns on." (the words he gave at 16:47 for the second choice under "Hours counted from"; the wording on the sheet itself is a separate change that waits for his word). Checked on production straight after: 141 functions, every fingerprint equal to the tested copy, only `_booking_to_quote` changed, and a rolled-back probe gave the expected conditions on both quotes and showed an organisation nothing of the probe's name, client or note.

**Checked:** 12 further checks in `supabase/tests/booking_day_times/run.sh` (33 in all): the list keeps only known groups; a term left off is gone from what the guide expects; the company cannot add it back; an old copy of the app keeps the list; a term taken off after acceptance leaves the agreed terms and sends the sheet back; a term put back is asked again. In preview at phone size: the boxes, the form, the plain message, reopening, the company's form and sheet, and the cancellation warning with and without the policy on the sheet. **Not checked:** on the live site; on a real phone; at desktop size; by a session other than the one that built it.

**Status:** live since 5 Oct 2026, about 16:10. Asked whether to go live with D-24 and D-25 together, he said at 15:57: "yes go live." The database file `supabase/migrations/2026-10-05b_booking_day_times.sql` went through the connector this time (it holds nothing the connector asks him to confirm). Checked on production straight after: 27 tables, 141 functions (138 before), 0 table grants, 0 policies; every function's fingerprint equals the tested copy (`supabase/tests/production_fingerprints.txt`); the three helpers cannot be called from outside; and a rolled-back probe as a guide and as an organisation (`supabase/tests/booking_day_times/production_probe.sql`) came back as expected and left nothing behind. Then the branch was merged. Production had no booking sheets at the time.

---

## D-24 · On a booking sheet of more than one day, each day has its own pick-up time and estimated finish (live)

**Decided by:** the owner (Eretz Israel Tours), in the Vendor Master Claude session (master agent), 5 October 2026, 15:34 Israel time.

**In his words:** "each day needs its own start and finsh time. there should be be timated. for instance this is what the itinerary looks like." With it he attached one of his own trip itineraries, where each bus day has its own pick-up time and an estimated return, some still to be set. The itinerary is a client document and is not kept in these records (D6).

**Decision:** on a booking sheet for more than one day, every day carries its own start time and its own finish time, and the finish is an estimate.

**What was built (implementation choices; change on request):**

- **The form:** when a sheet has more than one day, a block "Times for each day" lists the chosen days. Each has a pick-up time, a finish time ("to about") and an optional "Where to". The single pick-up time and drop-off time fields are hidden then; pick-up place and drop-off place stay, one for all days. **Same times every day** copies the first day's times to the rest.
- **"Where to" for each day was not asked for.** It was added because the itinerary he showed has a different region each day and a bus price depends on where the bus goes. It is optional. Asked whether to keep it, he said at 15:44: "keep".
- **What the company sees:** under the date line, one line for each day, Hebrew with English under it: "ד׳ 18.11 · איסוף 08:30 · סיום משוער 18:00 · ים המלח" / "Wed 18 Nov · pick-up 08:30 · finish about 18:00". A day with a pick-up time and no finish reads "finish time to follow"; a day with nothing reads "times to follow". Also in the WhatsApp plain message and the printed sheet.
- **Every finish time is worded as an estimate** ("סיום משוער", "finish about"). Nothing else on the sheet says what an estimate means for overtime: the hours included in a day and the price of an extra hour are the company's to fill in, as before.
- **Stored** in one new column, `bookings.day_plan` (`{"2026-10-20": {"start":"08:30","end":"18:00","route":"…"}}`). Empty means the sheet's one pick-up and drop-off time apply to every day, so sheets made before this are unchanged. When every day has the same times and no "Where to", nothing is stored per day and the sheet shows one pick-up and one drop-off time, as before.
- **The times are part of what both sides accept:** a time changed after the company accepted clears its acceptance and comes back to it in red (D-5, item 10). Taking a day off the sheet takes its times with it.
- A one-day sheet is unchanged. Sheets of more than 31 days get no per-day block.

**Checked:** `supabase/tests/booking_day_times/run.sh` (21 checks: the change file run twice on the earlier schema gives the same functions and columns as the schema record; sheets made before the change read exactly as they did; bad times, days not on the sheet and empty entries are dropped; an old copy of the app keeps the times; a time changed after acceptance goes back to waiting; an organisation sees only its own sheets). The 98 limited-member checks and the 26 day-picker checks still pass. In preview, at phone and desktop size, as Eretz Israel Tours: fill in, save, plain message, reopen, same times every day, and the company's page. **Not checked:** on the live site; on a real phone; by a session other than the one that built it; in preview as an organisation; the red marking of a changed time on the company's page was checked in the database only, not looked at.

**Status:** live with D-25; see its status line for the go-live checks.

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
