import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Calendar ingest. Receives appointment rows pushed from Paul's Google Apps
// Script (which reads his calendar natively, no service-account key needed -
// Google blocks SA keys by default on new projects), mirrors them into
// bath_appointments via _sync_appointments, and prunes anything cancelled/moved
// out of the window via _sync_prune. Secret-gated. The Apps Script source lives
// at supabase/apps-script-calendar.gs.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

Deno.serve(async (req) => {
  try {
    const want = await secret("cfo_cron_secret");
    if (!want || req.headers.get("x-cfo-secret") !== want) {
      return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }
    const body = await req.json();
    const events = Array.isArray(body?.events) ? body.events : [];
    const result = await rpc("_sync_appointments", { p_events: events });
    let pruned = 0;
    if (body?.from && body?.to) {
      const keep = events.map((e: any) => e.external_id).filter(Boolean);
      pruned = await rpc("_sync_prune", { p_keep: keep, p_from: body.from, p_to: body.to });
    }
    return new Response(JSON.stringify({ ok: true, received: events.length, ...result, pruned }, null, 2), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
