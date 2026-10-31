// D-69: when an alert may go. Nothing is sent over Shabbat and Yom Tov in Israel, from candle lighting to havdalah,
// by Jerusalem times (candle lighting 40 minutes before sunset), and nothing from 23:00 to 07:00 Israel time.
// An alert held by either goes at the end of the hold (after havdalah, or at 07:00), whichever comes last.
// Times from @hebcal/core (Israel holiday schedule, il: true; havdalah as hebcal's default, 8.5° below the horizon).
import { CandleLightingEvent, HavdalahEvent, HebrewCalendar, Location } from "npm:@hebcal/core@6.14.7";

const TZ = "Asia/Jerusalem";
const NIGHT_FROM = 23, NIGHT_TO = 7;
const JERUSALEM = Location.lookup("Jerusalem")!;

// The wall-clock parts of an instant in Israel.
function parts(t: Date) {
  const f = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
  const o: Record<string, number> = {};
  for (const p of f.formatToParts(t)) if (p.type !== "literal") o[p.type] = Number(p.value);
  return { y: o.year, m: o.month, d: o.day, h: o.hour, mi: o.minute };
}
// An Israel wall-clock time (y, m 1-12, d, h, mi) as an instant.
export function israelTime(y: number, m: number, d: number, h: number, mi = 0): Date {
  let t = Date.UTC(y, m - 1, d, h, mi);
  for (let i = 0; i < 2; i++) {
    const p = parts(new Date(t));
    const asUtc = Date.UTC(p.y, p.m - 1, p.d, p.h, p.mi);
    t += Date.UTC(y, m - 1, d, h, mi) - asUtc;
  }
  return new Date(t);
}

// Shabbat and Yom Tov windows [candle lighting, havdalah] around a time, merged where they touch (Yom Tov next to Shabbat).
export function restWindows(around: Date): Array<[Date, Date]> {
  const start = new Date(around.getTime() - 3 * 864e5), end = new Date(around.getTime() + 12 * 864e5);
  const evs = HebrewCalendar.calendar({ start, end, location: JERUSALEM, il: true, candlelighting: true, candleLightingMins: 40 });
  const lights: Date[] = [], havs: Date[] = [];
  for (const e of evs) {
    const t = (e as unknown as { eventTime?: Date }).eventTime;
    if (!t) continue;
    if (e instanceof CandleLightingEvent) lights.push(t);
    else if (e instanceof HavdalahEvent) havs.push(t);
  }
  lights.sort((a, b) => +a - +b); havs.sort((a, b) => +a - +b);
  const out: Array<[Date, Date]> = [];
  for (const l of lights) {
    const h = havs.find((x) => +x > +l);
    if (!h) continue;
    const last = out[out.length - 1];
    if (last && +l <= +last[1]) { if (+h > +last[1]) last[1] = h; } else out.push([l, h]);
  }
  return out;
}

export type Hold = { until: Date; why: "shabbat_yomtov" | "night" } | null;

// null = may send now. Otherwise when the hold ends, and why.
export function holdAt(now: Date): Hold {
  let t = now, why: "shabbat_yomtov" | "night" | null = null;
  for (let i = 0; i < 6; i++) {
    const w = restWindows(t).find(([a, b]) => +t >= +a && +t < +b);
    if (w) { t = w[1]; why = why ?? "shabbat_yomtov"; continue; }
    const p = parts(t);
    if (p.h >= NIGHT_FROM || p.h < NIGHT_TO) {
      const day = p.h >= NIGHT_FROM ? new Date(Date.UTC(p.y, p.m - 1, p.d) + 864e5) : new Date(Date.UTC(p.y, p.m - 1, p.d));
      t = israelTime(day.getUTCFullYear(), day.getUTCMonth() + 1, day.getUTCDate(), NIGHT_TO, 0);
      why = why ?? "night";
      continue;
    }
    break;
  }
  return why ? { until: t, why } : null;
}
