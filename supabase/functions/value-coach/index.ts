import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// The Valuation coach (business_value_in_sight). Weekly, secret-gated: reads
// the live business valuation and the levers behind it (value_coach_data),
// has Claude write the two or three highest-leverage moves to raise what the
// business is worth, and cards Today. Recommends, never acts. Supersedes its
// own previous open card so the feed never stacks stale coaching.

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
      body: JSON.stringify({ agent_key: "value-coach", model: MODEL, input_tokens: usage.input_tokens ?? 0, output_tokens: usage.output_tokens ?? 0 }),
    });
  } catch (_) { /* cost logging never blocks the run */ }
}

async function sb(path: string, init: RequestInit) {
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, ...(init.headers ?? {}) },
  });
  if (!res.ok) throw new Error(`${path} failed ${res.status}: ${await res.text()}`);
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}
const rpc = (fn: string, body: unknown) => sb(`/rest/v1/rpc/${fn}`, { method: "POST", body: JSON.stringify(body) });

async function expectedSecret(): Promise<string | null> {
  const rows = await sb(`/rest/v1/app_secrets?name=eq.cfo_cron_secret&select=value`, { method: "GET" });
  return Array.isArray(rows) && rows[0] ? rows[0].value : null;
}
function dollars(c: number | null): string { return c == null ? "unknown" : "$" + Math.round(c / 100).toLocaleString("en-US"); }

Deno.serve(async (req) => {
  try {
    const want = await expectedSecret();
    if (!want || req.headers.get("x-cfo-secret") !== want) {
      return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }
    if (!ANTHROPIC_KEY) return new Response(JSON.stringify({ ok: false, error: "no Anthropic key" }), { status: 400, headers: { "Content-Type": "application/json" } });

    const m = await rpc("value_coach_data", {});
    const facts = {
      value_range: `${dollars(m.value_low_cents)} to ${dollars(m.value_high_cents)}`,
      method: m.method === "sde" ? "earnings multiple (real cost data)" : "revenue multiple (expense ledger still thin)",
      ttm_revenue: dollars(m.ttm_revenue_cents),
      growth_vs_prior_year_pct: m.growth_pct,
      recurring_revenue_share_pct: m.recurring_share_pct,
      expenses_recorded_ttm: dollars(m.expenses_ttm_cents),
      top3_client_concentration_pct: m.top3_concentration_pct,
      active_clients_ttm: m.active_clients_ttm,
      unpaid_completed_appointments: m.ar_open_count,
      open_capacity_alerts: m.open_capacity_alerts,
      open_winback_cards: m.open_winback_cards,
    };

    const system = [
      "You are the valuation coach for Dog Gone Clean, a mobile dog-grooming business owned by Paul (solo operator, pivoting to recurring no-haircut dog grooming).",
      "Your one job: raise what the business would sell for. You are given the live valuation and the real levers behind it.",
      "How the number moves: growth raises the multiple and the base; recurring-revenue share raises the multiple (it is the moat a buyer pays for); recording business expenses unlocks the more accurate earnings method; lower top-client concentration reduces buyer risk; documented operations that run without Paul raise every multiple; unpaid completed visits and unfilled capacity are leaks.",
      "Write the TWO or THREE highest-leverage moves THIS WEEK, each one concrete and small enough to actually do, each with the why in one clause. Lead with the single biggest lever. Never invent a number not given.",
      "No corporate jargon (no 'reach out', 'circle back', 'bandwidth'). No em dashes. Five sentences maximum.",
      'Respond as a single JSON object: {"title": string (<= 60 chars), "body": string, "severity": "info" | "signal"}. Output only the JSON.',
    ].join(" ");

    const aRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": ANTHROPIC_KEY!, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 600, thinking: { type: "disabled" }, system,
        messages: [{ role: "user", content: "This week's valuation picture:\n" + JSON.stringify(facts, null, 2) }],
      }),
    });
    const aText = await aRes.text();
    if (!aRes.ok) throw new Error(`anthropic ${aRes.status}: ${aText}`);
    const aJson = JSON.parse(aText);
    await logUsage(aJson.usage);
    const raw: string = (aJson.content ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("").trim();

    let title = "Raising the business value"; let body = raw; let severity = "info";
    try {
      const s = raw.indexOf("{");
      const p = JSON.parse(s >= 0 ? raw.slice(s, raw.lastIndexOf("}") + 1) : raw);
      if (p.title) title = String(p.title).slice(0, 80);
      if (p.body) body = String(p.body);
      if (["info", "signal"].includes(p.severity)) severity = p.severity;
    } catch { /* raw fallback */ }

    // Supersede the previous open coaching card, then post the new one.
    await sb(`/rest/v1/briefings?agent_key=eq.value_coach&status=in.(new,read)`, {
      method: "PATCH",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ status: "resolved", disposition: "Superseded by this week's coaching card.", acted_at: new Date().toISOString() }),
    }).catch(() => {});
    await sb(`/rest/v1/briefings`, {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ agent_key: "value_coach", department: "finance", severity, title, body, status: "new" }),
    });

    return new Response(JSON.stringify({ ok: true, title, body, severity }, null, 2), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
