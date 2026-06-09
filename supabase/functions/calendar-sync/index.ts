import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Recurring Google Calendar sync. Every 15 minutes (calendar-sync cron) this
// reads Paul's calendar with a Google service account, parses each grooming
// appointment, and mirrors it into bath_appointments via _sync_appointments,
// then prunes anything cancelled/moved out of the window. Secret-gated.
// No-ops gracefully until the google_service_account_json edge secret is set.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SA_JSON = Deno.env.get("google_service_account_json") ?? Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");

async function sb(path: string, init: RequestInit) {
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, ...(init.headers ?? {}) },
  });
  if (!res.ok) throw new Error(`${path} ${res.status}: ${await res.text()}`);
  return res.json();
}
const rpc = (fn: string, body: unknown) => sb(`/rest/v1/rpc/${fn}`, { method: "POST", body: JSON.stringify(body) });
async function secret(name: string): Promise<string | null> {
  const rows = await sb(`/rest/v1/app_secrets?name=eq.${name}&select=value`, { method: "GET" });
  return Array.isArray(rows) && rows[0] ? rows[0].value : null;
}

function b64urlBytes(b: Uint8Array): string {
  let s = ""; for (const x of b) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
const b64urlStr = (s: string) => b64urlBytes(new TextEncoder().encode(s));
function pemBytes(pem: string): Uint8Array {
  const b64 = pem.replace(/-----BEGIN [^-]+-----/, "").replace(/-----END [^-]+-----/, "").replace(/\s+/g, "");
  const bin = atob(b64); const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
async function accessToken(sa: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const head = b64urlStr(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64urlStr(JSON.stringify({
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/calendar.readonly",
    aud: "https://oauth2.googleapis.com/token", exp: now + 3600, iat: now,
  }));
  const input = `${head}.${claim}`;
  const key = await crypto.subtle.importKey("pkcs8", pemBytes(sa.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(input));
  const jwt = `${input}.${b64urlBytes(new Uint8Array(sig))}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  const j = await res.json();
  if (!res.ok) throw new Error("google token: " + JSON.stringify(j));
  return j.access_token;
}

function parseEvent(ev: any): any | null {
  if (!ev?.start?.dateTime || !ev?.end?.dateTime) return null; // skip all-day / holds without a time
  const summary = String(ev.summary || "").trim();
  if (!summary || /^reserve\b/i.test(summary) || /^(block|busy|hold|lunch|off)\b/i.test(summary)) return null;
  const name = summary.split(":")[0].trim();
  if (!name) return null;
  const desc = String(ev.description || "");
  const email = desc.match(/Email:\s*([^\s\n]+@[^\s\n]+)/i);
  const dogs = summary.match(/(\d+)\s*Dogs?\b/i) || desc.match(/Groom\s+(\d+)\s+Dog/i);
  const price = desc.match(/Price:\s*\$?([\d.]+)/i);
  return {
    external_id: ev.id,
    starts: ev.start.dateTime,
    ends: ev.end.dateTime,
    client_name: name,
    client_email: email ? email[1] : null,
    dog_count: dogs ? parseInt(dogs[1], 10) : null,
    service_type: /nail/i.test(summary) ? "nails" : "full_groom",
    amount_cents: price ? Math.round(parseFloat(price[1]) * 100) : null,
    notes: ev.location || null,
  };
}

Deno.serve(async (req) => {
  try {
    const want = await secret("cfo_cron_secret");
    if (!want || req.headers.get("x-cfo-secret") !== want) {
      return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }
    if (!SA_JSON) {
      return new Response(JSON.stringify({ ok: true, skipped: "no google_service_account_json secret set yet" }), { headers: { "Content-Type": "application/json" } });
    }
    const sa = JSON.parse(SA_JSON);
    const calId = (await secret("gcal_calendar_id")) ?? "primary";
    const token = await accessToken(sa);

    const from = new Date(Date.now() - 2 * 86400000);
    const to = new Date(Date.now() + 45 * 86400000);
    const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calId)}/events?` +
      new URLSearchParams({ timeMin: from.toISOString(), timeMax: to.toISOString(), singleEvents: "true", orderBy: "startTime", maxResults: "250" });
    const cres = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    const cal = await cres.json();
    if (!cres.ok) throw new Error("calendar: " + JSON.stringify(cal));

    const rows = (cal.items ?? []).map(parseEvent).filter((x: any) => x);
    const result = await rpc("_sync_appointments", { p_events: rows });
    const keep = rows.map((r: any) => r.external_id);
    const pruned = await rpc("_sync_prune", { p_keep: keep, p_from: from.toISOString(), p_to: to.toISOString() });

    return new Response(JSON.stringify({ ok: true, seen: rows.length, ...result, pruned }, null, 2), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
