// D-69: the hold windows of the job-alerts sender. Run: deno test -A supabase/tests/job_alerts/holds_test.ts
import { holdAt, israelTime } from "../../functions/job-alerts/holds.ts";
const il = (t: Date) => new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Jerusalem", weekday: "short", day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(t);
function eq(a: unknown, b: unknown, what: string) { if (a !== b) throw new Error(`${what}: got ${a}, want ${b}`); }

Deno.test("Tuesday 23:30 is held until Wednesday 07:00", () => {
  const h = holdAt(israelTime(2026, 11, 17, 23, 30));   // Tue 17 Nov 2026
  eq(h?.why, "night", "why"); eq(il(h!.until), "Wed, 18 Nov 2026, 07:00", "until");
});
Deno.test("Tuesday 06:59 is held until 07:00 the same day", () => {
  const h = holdAt(israelTime(2026, 11, 17, 6, 59));
  eq(il(h!.until), "Tue, 17 Nov 2026, 07:00", "until");
});
Deno.test("Tuesday 12:00 goes now", () => { eq(holdAt(israelTime(2026, 11, 17, 12, 0)), null, "hold"); });
Deno.test("Friday 15:00 goes now (before candle lighting)", () => {
  eq(holdAt(israelTime(2026, 11, 20, 15, 0)), null, "hold");   // Fri 20 Nov 2026; candle lighting about 16:01
});
Deno.test("Friday after candle lighting is held until after havdalah", () => {
  const h = holdAt(israelTime(2026, 11, 20, 16, 30));
  eq(h?.why, "shabbat_yomtov", "why");
  const u = il(h!.until); if (!u.startsWith("Sat, 21 Nov 2026, 17:")) throw new Error("until " + u);
});
Deno.test("Shabbat noon is held until after havdalah, not until 07:00", () => {
  const h = holdAt(israelTime(2026, 11, 21, 12, 0));
  eq(h?.why, "shabbat_yomtov", "why"); if (!il(h!.until).startsWith("Sat, 21 Nov 2026, 17:")) throw new Error(il(h!.until));
});
Deno.test("Saturday after havdalah goes now", () => { eq(holdAt(israelTime(2026, 11, 21, 18, 0)), null, "hold"); });
Deno.test("Friday night 23:30 (Shabbat) is held until after havdalah", () => {
  const h = holdAt(israelTime(2026, 11, 20, 23, 30));
  eq(h?.why, "shabbat_yomtov", "why"); if (!il(h!.until).startsWith("Sat, 21 Nov 2026, 17:")) throw new Error(il(h!.until));
});
Deno.test("First day of Pesach 2027 in Israel (Thu 22 Apr) is held until after havdalah that evening", () => {
  const h = holdAt(israelTime(2027, 4, 22, 12, 0));
  eq(h?.why, "shabbat_yomtov", "why");
  const u = il(h!.until); if (!u.startsWith("Thu, 22 Apr 2027, 19:")) throw new Error("until " + u);
});
Deno.test("Erev Pesach 2027 after candle lighting is held", () => {
  const h = holdAt(israelTime(2027, 4, 21, 19, 0));
  eq(h?.why, "shabbat_yomtov", "why"); if (!il(h!.until).startsWith("Thu, 22 Apr 2027, 19:")) throw new Error(il(h!.until));
});
Deno.test("The second day of Pesach 2027 in Israel is Chol HaMoed: Thursday night 21:00 goes now", () => {
  eq(holdAt(israelTime(2027, 4, 22, 21, 0)), null, "hold");
});
Deno.test("Rosh Hashana 2026 follows Shabbat (Sat 12 and Sun 13 Sep): Saturday 21:00 is still held, until Sunday night", () => {
  const h = holdAt(israelTime(2026, 9, 12, 21, 0));
  eq(h?.why, "shabbat_yomtov", "why");
  const u = il(h!.until); if (!u.startsWith("Sun, 13 Sept 2026, 19:")) throw new Error("until " + u);
});
Deno.test("Saturday night after havdalah but past 23:00 is held until 07:00", () => {
  const h = holdAt(israelTime(2026, 11, 21, 23, 15));   // Saturday night after havdalah, but past 23:00
  eq(h?.why, "night", "why"); eq(il(h!.until), "Sun, 22 Nov 2026, 07:00", "until");
});
