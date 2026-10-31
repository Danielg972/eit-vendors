// D-69: the words of the alerts match the approved mock-up. Run: deno test -A supabase/tests/job_alerts/messages_test.ts
import { emailFor, pushFor, type Job, type Row } from "../../functions/job-alerts/messages.ts";
const job: Job = { id: "00000000-0000-0000-0000-000000000001", kind: "guide", title: "Sample: Old City, full day", date_from: "2026-11-22", date_to: "",
  hours: "08:00 to 16:00", region: "Jerusalem Old City", start_place: "Jaffa Gate", pax: "Sample family of 6", langs: "English", needs: "licensed",
  price: "1400", currency: "ILS", per: "day", vat: "including_vat", days: [] };
const row = (event: string, j: Job = job): Row => ({ id: "r1", event, channel: "email", about: "", to: "sample@invalid.test", key: "k".repeat(36), job: j });
function has(s: string, part: string, what: string) { if (!s.includes(part)) throw new Error(`${what}: "${part}" not in:\n${s}`); }
function not(s: string, part: string, what: string) { if (s.includes(part)) throw new Error(`${what}: "${part}" should not be in:\n${s}`); }

Deno.test("phone notification title and body as the mock-up", () => {
  const p = pushFor(row("job_new"));
  if (p.title !== "New guide job · Sun 22 Nov") throw new Error(p.title);
  has(p.body, "Sample: Old City, full day · Jerusalem Old City · ₪1,400 per day", "body");
  has(p.body, "עבודה חדשה למדריך/ה · 1,400 ₪ ליום", "Hebrew line");
  if (!p.url.endsWith("#job=" + job.id)) throw new Error(p.url);
});
Deno.test("email subject and body as the mock-up, English then Hebrew, footer", () => {
  const m = emailFor(row("job_new"), "https://x/#unsub=k", "https://x/#contact");
  if (m.subject !== "New job: guide, Sun 22 Nov, Jerusalem Old City, ₪1,400 per day") throw new Error(m.subject);
  for (const part of ["Sample: Old City, full day", "₪1,400", "VAT included", "Sun, 22 Nov 2026", "08:00 to 16:00", "Jerusalem Old City", "Sample family of 6", "Licensed guide", "See the job and answer", "#job=" + job.id,
    "only for the job board", "Stop job emails", "Contact Eretz Israel Tours", "replies aren't read", "#unsub=k", "#contact"]) has(m.html, part, "html");
  if (m.text.indexOf("See the job and answer") > m.text.indexOf("עבודה חדשה")) throw new Error("Hebrew before English");
  not(m.html + m.text, "Daniel", "never Daniel");
});
Deno.test("day-by-day lines go in, in day order", () => {
  const j = { ...job, date_from: "2026-11-22", date_to: "2026-11-24", days: [{ d: "2026-11-24", text: "Sample: Yad Vashem", hours: "" }, { d: "2026-11-22", text: "Sample: Kotel tunnels", hours: "08:00 to 15:00" }] };
  const m = emailFor(row("job_new", j), "u", "c");
  has(m.text, "Day 1 · Sun 22 Nov: Sample: Kotel tunnels, 08:00 to 15:00", "day 1");
  has(m.text, "Day 3 · Tue 24 Nov: Sample: Yad Vashem", "day 3");
  if (m.text.indexOf("Day 1") > m.text.indexOf("Day 3")) throw new Error("order");
});
Deno.test("the other alerts have their own words", () => {
  if (pushFor(row("job_given")).title !== "The job is yours") throw new Error("given");
  if (pushFor(row("job_available")).title !== "Someone is available") throw new Error("available");
  if (pushFor(row("group_review")).title !== "A colleague posted a job: share to the jobs group?") throw new Error("group");
  has(pushFor(row("group_review")).url, "#jobs=group", "group link");
  has(pushFor(row("job_closed")).title, "closed", "closed");
});
