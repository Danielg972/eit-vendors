// Vendor files, quote attachments, join proofs and feedback screenshots: checks the caller's personal link token, then signs uploads/downloads with the service key.
// Deployed as Supabase edge function "files" (verify_jwt = false). Version 9, 2 Oct 2026. Keep this file identical to the deployed source.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const BUCKET = "vendor-files", PROOFS = "member-proofs", FEEDBACK = "feedback-files";
const KINDS = ["Photo", "Receipt", "Price list", "Booking confirmation", "Contract", "Quote", "Kosher certificate", "Other"];
const TYPES = /^(image\/(jpeg|png|webp|heic|heif|gif)|application\/pdf)$/;
const NOT_ACTIVE = "Your link is not active. Ask Eretz Israel Tours for a new one.";
const ADMIN_ONLY = "Only Eretz Israel Tours can do that.";

async function sha256(s: string) {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
}
const safeName = (n: unknown) => String(n || "file").replace(/[^\w.\-]+/g, "_").slice(-80) || "file";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Bad request" }, 400); }
  const { token, action } = body || {};
  if (typeof token !== "string" || token.length < 20) return json({ error: NOT_ACTIVE }, 401);
  const { data: m } = await db.from("members").select("id,email,name,is_admin,status,proof_path").eq("token_hash", await sha256(token)).maybeSingle();
  if (!m || m.status === "revoked") return json({ error: NOT_ACTIVE }, 401);

  // a quote's files are visible only to its owner and the admin. Quotes are shared with colleagues without the
  // owner's name (v9), and an attached email or PDF would give away who got the quote and for which client.
  const quoteAccess = async (qid: string, _needEdit: boolean) => {
    const { data: q } = await db.from("quotes").select("id,vendor_id,owner,shared").eq("id", qid).maybeSingle();
    if (!q) return null;
    if (!(m.is_admin || q.owner === m.email)) return null;
    return q;
  };
  // colleagues never receive each other's email addresses
  const scrub = (f: any) => { f.mine = f.uploaded_by === m.email; if (!m.is_admin) delete f.uploaded_by; return f; };

  try {
    // ---- join proof: allowed while the request is pending ----
    if (action === "proof_upload_url") {
      const path = `${m.id}/${Date.now().toString(36)}-${safeName(body.file_name)}`;
      const { data, error } = await db.storage.from(PROOFS).createSignedUploadUrl(path);
      if (error) throw error;
      return json({ path, upload_token: data.token });
    }
    if (action === "proof_confirm") {
      const path = String(body.path || ""), mime = String(body.mime_type || "");
      if (!path.startsWith(m.id + "/")) return json({ error: "Bad file path" }, 400);
      if (!TYPES.test(mime)) { await db.storage.from(PROOFS).remove([path]); return json({ error: "Upload a photo or a PDF." }, 400); }
      if (m.proof_path && m.proof_path !== path) await db.storage.from(PROOFS).remove([m.proof_path]);
      const { error } = await db.from("members").update({ proof_path: path, proof_mime: mime }).eq("id", m.id);
      if (error) throw error;
      return json({ ok: true });
    }

    if (m.status !== "approved") return json({ error: "Your request hasn't been approved yet." }, 403);

    if (action === "proof_view") {
      if (!m.is_admin) return json({ error: ADMIN_ONLY }, 403);
      const { data: who } = await db.from("members").select("proof_path").eq("id", String(body.member_id)).maybeSingle();
      if (!who?.proof_path) return json({ error: "No proof uploaded." }, 404);
      const { data, error } = await db.storage.from(PROOFS).createSignedUrl(who.proof_path, 600);
      if (error) throw error;
      return json({ url: data.signedUrl });
    }
    // ---- feedback screenshots ----
    if (action === "feedback_upload_url" || action === "feedback_confirm" || action === "feedback_view") {
      const { data: f } = await db.from("feedback").select("id,author,file_path").eq("id", String(body.feedback_id)).maybeSingle();
      if (!f) return json({ error: "That feedback no longer exists." }, 404);
      const mine = f.author === m.email;
      if (action === "feedback_view") {
        if (!m.is_admin && !mine) return json({ error: "Not yours." }, 403);
        if (!f.file_path) return json({ error: "No file attached." }, 404);
        const { data, error } = await db.storage.from(FEEDBACK).createSignedUrl(f.file_path, 600);
        if (error) throw error;
        return json({ url: data.signedUrl });
      }
      if (!mine) return json({ error: "Not yours." }, 403);
      if (action === "feedback_upload_url") {
        const path = `${f.id}/${Date.now().toString(36)}-${safeName(body.file_name)}`;
        const { data, error } = await db.storage.from(FEEDBACK).createSignedUploadUrl(path);
        if (error) throw error;
        return json({ path, upload_token: data.token });
      }
      const path = String(body.path || ""), mime = String(body.mime_type || "");
      if (!path.startsWith(f.id + "/")) return json({ error: "Bad file path" }, 400);
      if (!TYPES.test(mime)) { await db.storage.from(FEEDBACK).remove([path]); return json({ error: "Attach a screenshot, photo or PDF." }, 400); }
      const { error } = await db.from("feedback").update({ file_path: path }).eq("id", f.id);
      if (error) throw error;
      return json({ ok: true });
    }
    if (action === "list") {
      let q = db.from("vendor_files").select("*").eq("vendor_id", String(body.vendor_id));
      if (body.quote_id) {
        if (!(await quoteAccess(String(body.quote_id), false))) return json({ files: [] });
        q = q.eq("quote_id", String(body.quote_id));
      } else q = q.is("quote_id", null);
      if (!m.is_admin) q = q.or(`private.eq.false,uploaded_by.eq.${m.email}`);
      const { data, error } = await q.order("created_at", { ascending: false });
      if (error) throw error;
      if (data.length) {
        const { data: urls } = await db.storage.from(BUCKET).createSignedUrls(data.map((f) => f.path), 3600);
        (urls || []).forEach((u, i) => { (data[i] as any).url = u?.signedUrl || null; });
        const emails = [...new Set(data.map((f) => f.uploaded_by))];
        const { data: who } = await db.from("members").select("email,name,role,is_admin").in("email", emails);
        const byEmail = Object.fromEntries((who || []).map((w) => [w.email, w]));
        data.forEach((f: any) => { const w = byEmail[f.uploaded_by]; f.by = w ? { name: w.is_admin ? "Eretz Israel Tours" : w.name, role: w.role, admin: w.is_admin } : { name: "A colleague", role: "", admin: false }; });
      }
      return json({ files: data.map(scrub) });
    }
    if (action === "sign_upload") {
      const vid = String(body.vendor_id || "");
      const { data: v } = await db.from("vendors").select("id").eq("id", vid).maybeSingle();
      if (!v) return json({ error: "That supplier no longer exists." }, 404);
      if (body.quote_id && !(await quoteAccess(String(body.quote_id), true))) return json({ error: "Only the person who added this quote, or Eretz Israel Tours, can add files to it." }, 403);
      const path = `${vid}/${Date.now().toString(36)}-${crypto.randomUUID().slice(0, 6)}-${safeName(body.file_name)}`;
      const { data, error } = await db.storage.from(BUCKET).createSignedUploadUrl(path);
      if (error) throw error;
      return json({ path, upload_token: data.token });
    }
    if (action === "confirm") {
      const vid = String(body.vendor_id || ""), path = String(body.path || "");
      if (!path.startsWith(vid + "/")) return json({ error: "Bad file path" }, 400);
      const mime = String(body.mime_type || "");
      if (!TYPES.test(mime)) { await db.storage.from(BUCKET).remove([path]); return json({ error: "Only photos and PDFs are allowed." }, 400); }
      let quote_id: string | null = null;
      if (body.quote_id) { const qa = await quoteAccess(String(body.quote_id), true); if (!qa) { await db.storage.from(BUCKET).remove([path]); return json({ error: "Not allowed." }, 403); } quote_id = qa.id; }
      const row = { vendor_id: vid, path, file_name: String(body.file_name || "file").slice(0, 200), mime_type: mime,
        size_bytes: Number(body.size_bytes) || 0, kind: KINDS.includes(body.kind) ? body.kind : "Other", uploaded_by: m.email, quote_id, private: !!body.private };
      const { data, error } = await db.from("vendor_files").insert(row).select().single();
      if (error) { await db.storage.from(BUCKET).remove([path]); throw error; }
      return json({ file: scrub(data) });
    }
    if (action === "delete") {
      const { data: f } = await db.from("vendor_files").select("*").eq("id", String(body.file_id)).maybeSingle();
      if (!f) return json({ ok: true });
      if (!m.is_admin && f.uploaded_by !== m.email) return json({ error: "Only Eretz Israel Tours or the person who added this file can remove it." }, 403);
      await db.from("vendor_files").delete().eq("id", f.id);
      await db.storage.from(BUCKET).remove([f.path]);
      return json({ ok: true });
    }
    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    return json({ error: (e as Error).message || "Something went wrong" }, 500);
  }
});
