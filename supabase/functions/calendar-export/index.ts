import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Calendar export. The mirror direction: serves the app's own appointments
// (bath_appointments) so Paul's Google Apps Script can write them into the
// "Dog Gone Clean" Google calendar, kept current on its 15-minute trigger.
// This lets the new system run visibly in parallel with the old one: every
// appointment the app knows about shows up on a calendar Paul can watch next
// to his existing one, and when the two agree day after day the cutover is
// safe. Secret-gated (same cfo_cron_secret as calendar-ingest). The Apps
// Script tags each event it creates so the inbound read skips them and the
// calendar->app->calendar loop never closes. Source lives at
// supabase/apps-script-calendar.gs.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Statuses that should not appear on the mirror calendar at all.
const HIDE = new Set(["cancelled", "no_show", "skipped"]);

async function sb(path: string, init: RequestInit = {}) {
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, ...(init.headers ?? {}) },
  });
  if (!res.ok) throw new Error(`${path} ${res.status}: ${await res.text()}`);
  return res.json();
}
async function secret(name: string): Promise<string | null> {
  const rows = await sb(`/rest/v1/app_secrets?name=eq.${name}&select=value`, { method: "GET" });
  return Array.isArray(rows) && rows[0] ? rows[0].value : null;
}

function money(cents: number | null): string | null {
  if (!cents || cents <= 0) return null;
  return `$${(cents / 100).toFixed(2)}`;
}

// Compose the calendar event the mirror should show. Title stays clean (the
// client name, pencil-marked when tentative); the detail Paul verifies against
// goes in the description. The last line is the sentinel the inbound read keys
// off to skip its own mirror, alongside the event tag.
function shape(a: any) {
  const name = String(a?.subscriber?.client?.name ?? "").trim();
  if (!name) return null;
  if (a?.subscriber?.client?.exclude_from_everything) return null;
  if (HIDE.has(a.status)) return null;

  const tentative = a.status === "tentative";
  const dogs = a.dog_count ?? 1;
  const title = `${tentative ? "(pencil) " : ""}${name}`;
  const lines = [
    "Dog Gone Clean appointment (app mirror)",
    `Status: ${a.status}`,
    `Dogs: ${dogs}`,
    `Service: ${a.service_type ?? "full_groom"}`,
  ];
  const price = money(a.amount_cents);
  if (price) lines.push(`Price: ${price}`);
  if (a.notes) lines.push(`Location: ${a.notes}`);
  lines.push(`[dgc-mirror] ${a.id}`);

  return {
    appt_id: a.id,
    title,
    start: a.scheduled_start,
    end: a.scheduled_end ?? a.scheduled_start,
    location: a.notes ?? null,
    description: lines.join("\n"),
    tentative,
  };
}

Deno.serve(async (req) => {
  try {
    const want = await secret("cfo_cron_secret");
    if (!want || req.headers.get("x-cfo-secret") !== want) {
      return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }

    // Same window the inbound sync uses: 2 days back, a full year forward.
    let from: string, to: string;
    try {
      const body = req.method === "POST" ? await req.json() : {};
      from = body?.from ?? new Date(Date.now() - 2 * 86400000).toISOString();
      to = body?.to ?? new Date(Date.now() + 366 * 86400000).toISOString();
    } catch {
      from = new Date(Date.now() - 2 * 86400000).toISOString();
      to = new Date(Date.now() + 366 * 86400000).toISOString();
    }

    const rows = await sb(
      `/rest/v1/bath_appointments?select=id,scheduled_start,scheduled_end,status,service_type,dog_count,amount_cents,notes,` +
      `subscriber:bath_subscribers(client:clients(name,exclude_from_everything))` +
      `&scheduled_start=gte.${encodeURIComponent(from)}&scheduled_start=lte.${encodeURIComponent(to)}` +
      `&status=not.in.(cancelled,no_show,skipped)&order=scheduled_start`, { method: "GET" });

    const events = (Array.isArray(rows) ? rows : []).map(shape).filter((x) => x);
    return new Response(JSON.stringify({ ok: true, from, to, events }, null, 2), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
