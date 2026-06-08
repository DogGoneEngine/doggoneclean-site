import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// The CFO department head. Pulls real numbers from the books (cfo_brief_data),
// has Claude write a short owner-facing briefing in the CFO's voice, and saves
// it to the feed (cfo_save_briefing). Recommend, never act. Runs daily via the
// cfo-daily-briefing cron, authenticated by the x-cfo-secret shared secret
// (mirrors the send-notification pattern). verify_jwt is off; the secret guard
// is the auth. Reads the Anthropic key from the ANTHROPIC_API_KEY edge secret
// (falls back to the "Claude Anthropic CFO Key" name Paul originally used).

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? Deno.env.get("Claude Anthropic CFO Key");
const MODEL = "claude-sonnet-4-6";

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

function dollars(cents: number | null): string {
  if (cents == null) return "unknown";
  return "$" + (cents / 100).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}

Deno.serve(async (req) => {
  try {
    const want = await expectedSecret();
    const got = req.headers.get("x-cfo-secret");
    if (!want || got !== want) {
      return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }
    if (!ANTHROPIC_KEY) {
      return new Response(JSON.stringify({ ok: false, error: "no Anthropic key secret found" }), { status: 400, headers: { "Content-Type": "application/json" } });
    }

    const m = await rpc("cfo_brief_data", { p_window_days: 90 });
    const facts = {
      window_days: m.window_days,
      visits: m.visits,
      distinct_clients: m.clients,
      collected: dollars(m.revenue_cents),
      priced_visits: m.priced_visits,
      timed_visits: m.timed_visits,
      revenue_per_hour: m.revenue_per_hour != null ? `$${m.revenue_per_hour}` : "not yet measurable",
      prior_window_revenue_per_hour: m.prev_revenue_per_hour != null ? `$${m.prev_revenue_per_hour}` : "unknown",
      no_shows: m.no_shows,
      accounts_receivable_count: m.ar_count,
      accounts_receivable_value: dollars(m.ar_cents),
      top_clients_by_collected: (m.top_clients ?? []).map((t: any) => ({ name: t.name, visits: t.visits, collected: dollars(t.collected_cents) })),
    };

    const system = [
      "You are the CFO of Dog Gone Clean, a mobile dog-grooming business owned by Paul.",
      "You are given REAL figures computed directly from the books. Write a short CFO note to Paul.",
      "Lead with the single most important finding, then give one clear recommendation and the reason for it.",
      "Revenue per hour (the on-site rate) is the number the business is run on; treat changes in it as the headline when relevant.",
      "Use ONLY the figures provided. Never invent or estimate a number that is not given.",
      "No corporate jargon (no 'reach out', 'circle back', 'bandwidth', 'free up'). No em dashes. Three to five sentences.",
      'Respond as a single JSON object: {"title": string (<= 60 chars), "body": string, "severity": "info" | "signal" | "alert"}. Output only the JSON.',
    ].join(" ");

    const aRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": ANTHROPIC_KEY!, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 600, thinking: { type: "disabled" }, system,
        messages: [{ role: "user", content: "Here are the last 90 days of figures:\n" + JSON.stringify(facts, null, 2) }],
      }),
    });
    const aText = await aRes.text();
    if (!aRes.ok) throw new Error(`anthropic ${aRes.status}: ${aText}`);
    const aJson = JSON.parse(aText);
    const rawText: string = (aJson.content ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("").trim();
    const tokens = (aJson.usage?.input_tokens ?? 0) + (aJson.usage?.output_tokens ?? 0);

    let title = "CFO briefing"; let body = rawText; let severity = "info";
    try {
      const s = rawText.indexOf("{");
      const parsed = JSON.parse(s >= 0 ? rawText.slice(s, rawText.lastIndexOf("}") + 1) : rawText);
      if (parsed.title) title = String(parsed.title).slice(0, 80);
      if (parsed.body) body = String(parsed.body);
      if (["info", "signal", "alert"].includes(parsed.severity)) severity = parsed.severity;
    } catch { /* raw fallback */ }

    const briefId = await rpc("cfo_save_briefing", { p_title: title, p_body: body, p_severity: severity, p_evidence: m, p_model: MODEL, p_tokens: tokens });
    return new Response(JSON.stringify({ ok: true, briefing_id: briefId, title, body, severity, tokens }, null, 2), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
