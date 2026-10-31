// D-69: the words of each alert, English first, then Hebrew (the owner, 31 Oct 2026). Same labels as the app (jobMsg,
// JOB_KINDS, JOB_PER, JOB_VAT in index.html). The price is shown. Nobody is named: the job comes without its poster.
export const APP = "https://vendors.eretzisraeltours.com/";
export const FROM = "The Inner Circle – Israel Guide <jobs@eretzisraeltours.com>";

export type Job = { id: string; kind: string; title: string; date_from: string; date_to: string; hours: string; region: string; start_place: string;
  pax: string; langs: string; needs: string; price: string; currency: string; per: string; vat: string; days: Array<{ d: string; text: string; hours: string }> };
export type Row = { id: string; event: string; channel: "push" | "email"; about: string; to: string; key: string; job: Job;
  subs?: Array<{ endpoint: string; p256dh: string; auth: string }> | null };

const KINDS: Record<string, [string, string]> = { guide: ["Guide", "מדריך/ה"], guide_vehicle: ["Guide with vehicle", "מדריך/ה עם רכב"],
  van_driver: ["Van driver", "נהג/ת ואן"], jeep_driver: ["Jeep driver", "נהג/ת ג׳יפ"], other: ["Someone else", "איש/אשת מקצוע"] };
const PER: Record<string, [string, string]> = { day: ["per day", "ליום"], job: ["for the whole job", "לכל העבודה"], hour: ["per hour", "לשעה"], vehicle: ["per vehicle", "לרכב"] };
const VAT: Record<string, [string, string]> = { including_vat: ["VAT included", "כולל מע״מ"], plus_vat: ["plus VAT", "בתוספת מע״מ"], not_applicable: ["no VAT", "ללא מע״מ"] };
const NEEDS: Record<string, string> = { licensed: "Licensed guide", eshkol: "Eshkol license (D1)", midbari: "Midbari 4x4 vehicle", gun: "Carries a gun", shabbat: "Shomer Shabbat" };
const SIGN: Record<string, string> = { ILS: "₪", USD: "$", EUR: "€" };

const d12 = (iso: string) => new Date(iso + "T12:00:00Z");
const fmt = (iso: string, o: Intl.DateTimeFormatOptions, loc = "en-GB") => { try { return d12(iso).toLocaleDateString(loc, { timeZone: "UTC", ...o }); } catch { return iso; } };
const WD = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], MO = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
export const shortDate = (iso: string) => { const t = d12(iso); return isNaN(+t) ? iso : WD[t.getUTCDay()] + " " + t.getUTCDate() + " " + MO[t.getUTCMonth()]; };   // Sun 22 Nov
const longDate = (iso: string) => { const t = d12(iso); return isNaN(+t) ? iso : WD[t.getUTCDay()] + ", " + t.getUTCDate() + " " + MO[t.getUTCMonth()] + " " + t.getUTCFullYear(); };   // Sun, 22 Nov 2026
const heDate = (iso: string) => fmt(iso, { weekday: "short", day: "numeric", month: "numeric", year: "numeric" }, "he-IL");
const range = (j: Job, f: (s: string) => string) => j.date_to && j.date_to !== j.date_from ? f(j.date_from) + " – " + f(j.date_to) : f(j.date_from);
export const kindEn = (j: Job) => (KINDS[j.kind] || ["Job", "עבודה"])[0];
const kindHe = (j: Job) => (KINDS[j.kind] || ["Job", "עבודה"])[1];
const num = (p: string) => Number(p || 0).toLocaleString("en-US");
export const money = (j: Job) => (SIGN[j.currency] || "₪") + num(j.price);
const perEn = (j: Job) => (PER[j.per] || PER.day)[0];
const perLine = (j: Job) => [perEn(j), VAT[j.vat] ? VAT[j.vat][0] : ""].filter(Boolean).join(", ");
const moneyHe = (j: Job) => num(j.price) + " " + (SIGN[j.currency] || "₪") + " " + (PER[j.per] || PER.day)[1] + (VAT[j.vat] ? " " + VAT[j.vat][1] : "");
const dayLines = (j: Job) => {
  const list = Array.isArray(j.days) ? j.days.filter((x) => x && (x.text || x.hours)) : [];
  if (!j.date_to || list.length === 0) return [] as string[];
  const all: string[] = []; for (let t = d12(j.date_from); t <= d12(j.date_to) && all.length < 62; t = new Date(+t + 864e5)) all.push(t.toISOString().slice(0, 10));
  return list.map((x) => ({ x, i: all.indexOf(x.d) })).filter((y) => y.i >= 0).sort((a, b) => a.i - b.i)
    .map(({ x, i }) => "Day " + (i + 1) + " · " + shortDate(x.d) + ": " + [x.text, x.hours].filter(Boolean).join(", "));
};
export const jobLink = (j: Job) => APP + "#job=" + j.id;
const esc = (s: string) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));

// ---- phone notifications: a title, a short body, and where a tap goes ----
export function pushFor(r: Row): { title: string; body: string; url: string; tag: string } {
  const j = r.job, link = jobLink(j), tag = r.event + ":" + j.id;
  const priceLine = money(j) + " " + perEn(j);
  switch (r.event) {
    case "job_new":
      return { title: `New ${kindEn(j).toLowerCase()} job · ${shortDate(j.date_from)}`,
        body: [j.title, j.region, priceLine].filter(Boolean).join(" · ") + "\n" + `עבודה חדשה ל${kindHe(j)} · ${num(j.price)} ${SIGN[j.currency] || "₪"} ${(PER[j.per] || PER.day)[1]}`, url: link, tag };
    case "group_review":
      return { title: "A colleague posted a job: share to the jobs group?",
        body: [kindEn(j), j.title, shortDate(j.date_from), priceLine].filter(Boolean).join(" · ") + "\nעמית/ה פרסם/ה עבודה: לשתף בקבוצת העבודות?", url: APP + "#jobs=group", tag };
    case "job_given":
      return { title: "The job is yours", body: `"${j.title}", ${range(j, shortDate)}, was given to you. Their name and phone are in the app.\nהעבודה שלך. השם והטלפון באפליקציה.`, url: link, tag };
    case "job_closed":
      return { title: r.about === "taker" ? "A job you had was cancelled" : "A job you answered is closed",
        body: `"${j.title}", ${range(j, shortDate)}, is no longer open.\nהעבודה נסגרה.`, url: link, tag };
    case "job_available":
      return { title: "Someone is available", body: `A colleague said they're available for "${j.title}". Tap to choose.\nעמית/ה פנוי/ה לעבודה. הקישו כדי לבחור.`, url: link, tag: tag + ":" + r.id };
  }
  return { title: "The Inner Circle", body: j.title, url: link, tag };
}

// ---- email: subject, HTML and plain text ----
export function emailFor(r: Row, unsubscribeUrl: string, contactUrl: string): { subject: string; html: string; text: string } {
  const j = r.job, link = jobLink(j);
  const rows: Array<[string, string]> = [["Date", range(j, longDate)], ["Hours", j.hours], ["Starts at", j.start_place], ["Region", j.region],
    ["Group", j.pax], ["Language", j.langs], ["Must have", (j.needs || "").split(",").filter(Boolean).map((k) => NEEDS[k] || k).join(", ")]];
  const days = dayLines(j);
  let subject = "", lead = "", heLead = "", button = "See the job and answer", heButton = "לפרטים ולתשובה", url = link;
  switch (r.event) {
    case "job_new":
      subject = `New job: ${kindEn(j).toLowerCase()}, ${shortDate(j.date_from)}${j.region ? ", " + j.region : ""}, ${money(j)} ${perEn(j)}`;
      lead = "A colleague posted a job on the Inner Circle job board that fits you."; heLead = "עבודה חדשה בלוח העבודות של המעגל הפנימי";
      break;
    case "group_review":
      subject = `A colleague posted a job: share to the jobs group? (${kindEn(j).toLowerCase()}, ${shortDate(j.date_from)})`;
      lead = "A colleague posted this job. Share it to the Inner Circle – Jobs WhatsApp group, or mark it not for the group.";
      heLead = "עמית/ה פרסם/ה עבודה. לשתף בקבוצת העבודות בוואטסאפ?"; button = "Open the list for the jobs group"; heButton = "לרשימה"; url = APP + "#jobs=group";
      break;
    case "job_given":
      subject = `The job is yours: ${j.title}, ${shortDate(j.date_from)}`;
      lead = "The colleague who posted this job gave it to you. Their name and phone are in the app."; heLead = "העבודה שלך. השם והטלפון באפליקציה.";
      button = "Open the job"; heButton = "לפרטים";
      break;
    case "job_closed":
      subject = `${r.about === "taker" ? "Cancelled" : "Closed"}: ${j.title}, ${shortDate(j.date_from)}`;
      lead = r.about === "taker" ? "The colleague who posted this job cancelled it. Its days were taken off My days." : "You said you were available for this job. It is now closed.";
      heLead = "העבודה נסגרה."; button = "Open the job"; heButton = "לפרטים";
      break;
    case "job_available":
      subject = `Someone is available: ${j.title}, ${shortDate(j.date_from)}`;
      lead = "A colleague said they're available for your job. Open it to see who, and to give it to them."; heLead = "עמית/ה פנוי/ה לעבודה שלך.";
      button = "See who is available"; heButton = "לפרטים";
      break;
  }
  const heLine = [kindHe(j), range(j, heDate), j.region, moneyHe(j)].filter(Boolean).join(" · ");
  const footEn = "You get this because you are a member of The Inner Circle – Israel Guide. This email is only for the job board.";
  const text = [lead, "", kindEn(j) + ": " + j.title, money(j) + " " + perLine(j), ...rows.filter((x) => x[1]).map(([k, v]) => k + ": " + v),
    ...(days.length ? ["", ...days] : []), "", button + ": " + url, "", heLead, heLine, heButton + ": " + url, "", "—", footEn,
    "Stop job emails (one tap): " + unsubscribeUrl, "Contact Eretz Israel Tours (in the app): " + contactUrl,
    "Please don't reply to this email; replies aren't read."].join("\n");
  const html = `<!doctype html><html><body style="margin:0;background:#f3f5f1;font-family:Rubik,Arial,sans-serif;color:#16261e">
<div style="max-width:560px;margin:0 auto;background:#fff;padding:20px 18px">
<p style="margin:0 0 10px;font-size:15px">${esc(lead)}</p>
<div style="color:#b8742a;font-size:12px;font-weight:600;letter-spacing:.06em;text-transform:uppercase">${esc(kindEn(j))}</div>
<h2 style="margin:4px 0 8px;font-weight:400;font-size:21px">${esc(j.title)}</h2>
<div style="font-family:'IBM Plex Mono',monospace;font-size:22px">${esc(money(j))} <span style="font:13px Arial,sans-serif;color:#4a5a50">${esc(perLine(j))}</span></div>
<table role="presentation" style="width:100%;border-collapse:collapse;margin:10px 0;font-size:14px">${rows.filter((x) => x[1]).map(([k, v]) => `<tr><td style="color:#7c8a80;padding:3px 10px 3px 0;vertical-align:top;white-space:nowrap">${esc(k)}</td><td style="padding:3px 0">${esc(v)}</td></tr>`).join("")}</table>
${days.length ? `<div style="background:#e8ede5;border-radius:8px;padding:8px 10px;margin:8px 0;font-size:13.5px">${days.map(esc).join("<br>")}</div>` : ""}
<p style="margin:16px 0"><a href="${esc(url)}" style="display:inline-block;background:#1f3a2e;color:#fff;text-decoration:none;border-radius:10px;padding:10px 16px;font-size:15px">${esc(button)}</a></p>
<div dir="rtl" lang="he" style="text-align:right;font-size:14.5px;border-top:1px solid #eee;padding-top:10px"><b>${esc(heLead)}</b><br>${esc(heLine)}<br><a href="${esc(url)}" style="color:#2c5140">${esc(heButton)}</a></div>
<div style="border-top:1px solid #eee;margin-top:16px;padding-top:10px;font-size:12px;color:#777">${esc(footEn)}<br>
<a href="${esc(unsubscribeUrl)}" style="color:#2c5140">Stop job emails</a> (one tap) · <a href="${esc(contactUrl)}" style="color:#2c5140">Contact Eretz Israel Tours</a> (opens in the app)<br>
Please don't reply to this email; replies aren't read.</div></div></body></html>`;
  return { subject, html, text };
}
