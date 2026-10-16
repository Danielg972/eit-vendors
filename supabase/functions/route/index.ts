// A hike's route file at a public address, for "Open in Mapeak" (D-53, 16 Oct 2026). Mapeak opens a route from a web
// address (https://mapeak.com/url/<the address, encoded>); Mapeak's own server then fetches the file, with no headers of
// ours, so this function asks for none: no member link, no key.
// Deployed as Supabase edge function "route" (verify_jwt = false). Version 1. Keep this file identical to the deployed source.
//
//   GET https://<project>.supabase.co/functions/v1/route/<code>.gpx   (also /route/<code> and /route?c=<code>)
//
// <code> is the 32-letter code that hike_route_link gives a member who may see the hike. The database function
// _hike_route_public (callable with the service key only) gives the GPX text for that code, and only while the route
// file is not removed and its hike is approved. Anything else is a 404 with no detail.
// What is sent is the route only: the GPX the app stores holds points, heights and the names of marked spots, never who
// recorded or added it (hkCleanGpx on the page, _hike_gpx_put in the database). As a second guard, anything personal a
// GPX file can carry (metadata, author, email, link, name, desc, time, extensions) is cut out before it is sent, and a
// body that is not the app's own form is refused.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const CODE = /^[A-Za-z0-9_-]{32}$/;
const HEAD = '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="The Inner Circle">';
const base = { "Access-Control-Allow-Origin": "*", "X-Content-Type-Options": "nosniff", "Referrer-Policy": "no-referrer" };
const notFound = () => new Response("Not found", { status: 404, headers: { ...base, "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } });

// Everything but the route itself goes. Spot names (<wpt><name>) are kept: they are the marked spots of the hike.
function clean(body: string): string | null {
  if (!body.startsWith(HEAD) || !body.endsWith("</gpx>")) return null;
  let t = body;
  for (const tag of ["metadata", "author", "email", "link", "desc", "cmt", "src", "time", "extensions", "copyright", "keywords"]) {
    t = t.replace(new RegExp(`<${tag}\\b[^>]*/>|<${tag}\\b[^>]*>[\\s\\S]*?</${tag}>`, "g"), "");
  }
  t = t.replace(/<(trk|rte)>\s*<name>[\s\S]*?<\/name>/g, "<$1>");   // a track's own name (the app stores none)
  return '<?xml version="1.0" encoding="UTF-8"?>\n' + t;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: { ...base, "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS" } });
  if (req.method !== "GET" && req.method !== "HEAD") return notFound();
  let code = "";
  try {
    const u = new URL(req.url);
    const last = decodeURIComponent(u.pathname.split("/").filter(Boolean).pop() || "");
    code = u.searchParams.get("c") || (last === "route" ? "" : last.replace(/\.gpx$/i, ""));
  } catch { return notFound(); }
  if (!CODE.test(code)) return notFound();
  try {
    const { data, error } = await db.rpc("_hike_route_public", { p_code: code });
    if (error || typeof data !== "string" || !data) return notFound();
    const out = clean(data);
    if (!out) return notFound();
    return new Response(req.method === "HEAD" ? null : out, {
      status: 200,
      headers: { ...base, "Content-Type": "application/gpx+xml; charset=utf-8", "Content-Disposition": 'inline; filename="route.gpx"', "Cache-Control": "public, max-age=60" },
    });
  } catch { return notFound(); }
});
