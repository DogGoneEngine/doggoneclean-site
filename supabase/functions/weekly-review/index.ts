import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// The chief-of-staff weekly review. Synthesizes the week across departments into
// one short memo. Runs Mondays via the weekly-review cron, authenticated by
// x-cfo-secret. Reads the Anthropic key from the edge secret.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? Deno.env.get("Claude Anthropic CFO Key");
const MODEL = "claude-sonnet-4-6";

async function logUsage(usage: { input_tokens?: number; output_tokens?: number } | undefined) {
  if (!usage) return;
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/agent_costs`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, Prefer: "return=minimal" },
      body: JSON.stringify({ agent_key: "weekly-review", model: MODEL, input_tokens: usage.input_tokens ?? 0, output_tokens: usage.output_tokens ?? 0 }),
    });
  } catch (_) { /* cost logging never blocks the run */ }
}


async function sb(path: string, init: RequestInit) {
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, ...(init.headers ?? {}) },
  });
  if (!res.ok) throw new Error(`${path} failed ${res.status}: ${await res.text()}`);
  return res.json();
}
const rpc = (fn: string, body: unknown) => sb(`/rest/v1/rpc/${fn}`, { method: "POST", body: JSON.stringify(body) });

async function expectedSecret(): Promise<string | null> {
  const rows = await sb(`/rest/v1/app_secrets?name=eq.cfo_cron_secret&select=value`, { method: "GET" });
  return Array.isArray(rows) && rows[0] ? rows[0].value : null;
}
function dollars(c: number | null): string { return c == null ? "unknown" : "$" + (c / 100).toLocaleString("en-US", { maximumFractionDigits: 0 }); }

Deno.serve(async (req) => {
  try {
    const want = await expectedSecret();
    if (!want || req.headers.get("x-cfo-secret") !== want) {
      return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }
    if (!ANTHROPIC_KEY) return new Response(JSON.stringify({ ok: false, error: "no Anthropic key" }), { status: 400, headers: { "Content-Type": "application/json" } });

    const m = await rpc("weekly_review_data", {});
    const hasCosts = (m.expenses_30d_cents ?? 0) > 0;
    const facts = {
      revenue_last_30d: dollars(m.revenue_30d_cents),
      business_costs_last_30d: hasCosts ? dollars(m.expenses_30d_cents) : "none recorded yet",
      net_last_30d: hasCosts ? dollars(m.net_30d_cents) : "same as revenue, no costs recorded yet",
      revenue_per_hour_30d: m.revenue_per_hour_30d != null ? `$${m.revenue_per_hour_30d}` : "not yet measurable",
      prior_month_revenue_per_hour: m.prev_revenue_per_hour != null ? `$${m.prev_revenue_per_hour}` : "unknown",
      visits_last_7d: m.visits_last_7d,
      visits_last_30d: m.visits_last_30d,
      retention_open_alerts: m.retention_open_alerts,
      pricing_below_rate_alerts: m.pricing_open_alerts,
      compliance_due_soon: m.compliance_due_soon,
      compliance_overdue: m.compliance_overdue,
      upcoming_appointments_next_7d: m.upcoming_appointments_7d,
      total_clients: m.total_clients,
      standing_clients: m.standing_clients,
    };

    const system = [
      "You are the chief of staff for Dog Gone Clean, a mobile dog-grooming business owned by Paul.",
      "Write Paul's weekly business review from the REAL figures given.",
      "Lead with the single most important thing across the whole business this week, then briefly touch money (revenue, net if costs are recorded, and revenue per hour with its trend), retention (open overdue-client alerts), pricing (clients flagged below the rate), and compliance (anything due or overdue).",
      "Be concrete and brief: four to six sentences. End with the one action most worth taking this week.",
      "Use ONLY the figures provided; never invent a number. If costs are not recorded yet, say so in one short clause.",
      "No corporate jargon (no 'reach out', 'circle back', 'bandwidth', 'free up'). No em dashes.",
      'Respond as a single JSON object: {"title": string (<= 60 chars), "body": string, "severity": "info" | "signal" | "alert"}. Output only the JSON.',
    ].join(" ");

    const aRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": ANTHROPIC_KEY!, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({ model: MODEL, max_tokens: 800, thinking: { type: "disabled" }, system,
        messages: [{ role: "user", content: "This week's figures:\n" + JSON.stringify(facts, null, 2) }] }),
    });
    const aText = await aRes.text();
    if (!aRes.ok) throw new Error(`anthropic ${aRes.status}: ${aText}`);
    const aJson = JSON.parse(aText);
    await logUsage(aJson.usage);
    const rawText: string = (aJson.content ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("").trim();
    const tokens = (aJson.usage?.input_tokens ?? 0) + (aJson.usage?.output_tokens ?? 0);
    let title = "Weekly review"; let body = rawText; let severity = "info";
    try { const s = rawText.indexOf("{"); const p = JSON.parse(s >= 0 ? rawText.slice(s, rawText.lastIndexOf("}") + 1) : rawText);
      if (p.title) title = String(p.title).slice(0, 80); if (p.body) body = String(p.body);
      if (["info", "signal", "alert"].includes(p.severity)) severity = p.severity; } catch { /* raw */ }

    const id = await rpc("weekly_review_save", { p_title: title, p_body: body, p_severity: severity, p_evidence: m, p_model: MODEL, p_tokens: tokens });
    return new Response(JSON.stringify({ ok: true, briefing_id: id, title, body, severity, tokens }, null, 2), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
