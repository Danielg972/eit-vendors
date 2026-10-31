// D-69 (31 Oct 2026): the job-alerts sender. Supabase Edge Function "job-alerts", verify_jwt = false (it checks its own
// secret). Called every 5 minutes by pg_cron + pg_net (see the last section of supabase/migrations/2026-10-31b_job_alerts.sql).
//
// It refuses any caller without the header x-alerts-secret equal to the secret ALERTS_SECRET, or a Bearer token equal
// to the service-role key. It then:
//   1. stops if now is inside a hold: Shabbat and Yom Tov in Israel (candle lighting, 40 minutes before sunset in
//      Jerusalem, to havdalah) or 23:00 to 07:00 Israel time (holds.ts). Nothing is marked; the rows wait.
//   2. asks the database (_alerts_due, service key) for the waiting rows of the channels it can send now: push when the
//      VAPID keys are set, email when RESEND_API_KEY is set. Rows of a channel it cannot send stay waiting, not failed.
//   3. sends each one (web push with npm:web-push, email with Resend's HTTP API) and marks it sent, failed, or waiting
//      again when the service was busy (_alert_mark). A phone the push service says is gone (404 or 410) is switched off
//      for good (_push_mark).
// Secrets: VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (mailto:… or https://…), RESEND_API_KEY, ALERTS_SECRET.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are given to every Edge Function by Supabase.
// Nothing it sends names the poster or carries anyone's email or phone; the recipient's own address is only the "to".
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";
import { holdAt } from "./holds.ts";
import { APP, FROM, emailFor, pushFor, type Row } from "./messages.ts";

const env = (k: string) => (Deno.env.get(k) || "").trim();
const SERVICE = env("SUPABASE_SERVICE_ROLE_KEY");
const db = createClient(env("SUPABASE_URL"), SERVICE, { auth: { persistSession: false } });
const json = (o: unknown, status = 200) => new Response(JSON.stringify(o), { status, headers: { "Content-Type": "application/json" } });

function same(a: string, b: string) {
  if (!a || !b || a.length !== b.length) return false;
  let x = 0; for (let i = 0; i < a.length; i++) x |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return x === 0;
}
function allowed(req: Request) {
  const s = env("ALERTS_SECRET"), h = req.headers.get("x-alerts-secret") || "";
  const bearer = (req.headers.get("authorization") || "").replace(/^Bearer\s+/i, "");
  return (s.length >= 24 && same(h, s)) || (SERVICE.length > 0 && same(bearer, SERVICE));
}

async function sendPush(r: Row): Promise<[string, string]> {
  const p = pushFor(r), subs = r.subs || [];
  if (!subs.length) return ["skipped", "no phone"];
  const payload = JSON.stringify({ title: p.title, body: p.body, url: p.url, tag: p.tag });
  let ok = 0, busy = 0; const errs: string[] = [];
  for (const s of subs) {
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 86400, urgency: "normal" });
      ok++; await db.rpc("_push_mark", { p_endpoint: s.endpoint, p_ok: true, p_gone: false });
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode || 0;
      await db.rpc("_push_mark", { p_endpoint: s.endpoint, p_ok: false, p_gone: code === 404 || code === 410 });
      if (code === 429 || code >= 500 || code === 0) busy++;
      errs.push("push " + (code || "error"));
    }
  }
  if (ok) return ["sent", errs.join(", ")];
  return [busy ? "waiting" : "failed", errs.join(", ")];
}

async function sendEmail(r: Row, key: string): Promise<[string, string]> {
  const unsub = APP + "#unsub=" + encodeURIComponent(r.key), contact = APP + "#contact";
  const m = emailFor(r, unsub, contact);
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: "Bearer " + key, "Content-Type": "application/json", "Idempotency-Key": "alert-" + r.id },
    body: JSON.stringify({ from: FROM, to: [r.to], subject: m.subject, html: m.html, text: m.text,
      headers: { "List-Unsubscribe": "<" + unsub + ">" } }),
  });
  if (res.ok) return ["sent", ""];
  const t = (await res.text()).slice(0, 200);
  return [res.status === 429 || res.status >= 500 ? "waiting" : "failed", "email " + res.status + " " + t];
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  if (!allowed(req)) return json({ error: "not allowed" }, 401);
  const now = new Date(), hold = holdAt(now);
  if (hold) return json({ held: hold.why, until: hold.until.toISOString() });
  const vapid = env("VAPID_PUBLIC_KEY") && env("VAPID_PRIVATE_KEY") && env("VAPID_SUBJECT");
  const resend = env("RESEND_API_KEY");
  const channels = [...(vapid ? ["push"] : []), ...(resend ? ["email"] : [])];
  if (!channels.length) return json({ waiting: "no channel set up yet" });
  if (vapid) webpush.setVapidDetails(env("VAPID_SUBJECT"), env("VAPID_PUBLIC_KEY"), env("VAPID_PRIVATE_KEY"));
  const { data, error } = await db.rpc("_alerts_due", { p_limit: 50, p_channels: channels });
  if (error) return json({ error: error.message }, 500);
  const rows = (data || []) as Row[];
  const done: Record<string, number> = {};
  for (const r of rows) {
    let st: [string, string];
    try { st = r.channel === "push" ? await sendPush(r) : await sendEmail(r, resend); }
    catch (e) { st = ["waiting", String((e as Error).message || e).slice(0, 200)]; }
    await db.rpc("_alert_mark", { p_id: r.id, p_status: st[0], p_error: st[1] });
    done[st[0]] = (done[st[0]] || 0) + 1;
  }
  return json({ rows: rows.length, ...done, channels });
});
