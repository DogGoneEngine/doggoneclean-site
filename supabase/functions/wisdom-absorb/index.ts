import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// The Archivist. Reads the wisdom inbox and proposes where each captured note
// belongs (oracle rule, client note, parking lot, field manual, or drop) AND its
// topic scope, in clean because-form. Recommend only; Paul files from the
// Knowledge Base floor. Daily via the wisdom-absorb cron (or admin_trigger_
// archivist on demand), secret-gated. Self-healing: re-queues anything it could
// not place this run. Paul does not categorize; the agent decides.

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
const HOMES = ["oracle_rule", "client_note", "parking_lot", "field_manual", "drop"];
const SCOPES = ["business", "client", "pricing", "operations", "growth", "finance", "compliance", "other"];

Deno.serve(async (req) => {
  try {
    const want = await expectedSecret();
    if (!want || req.headers.get("x-cfo-secret") !== want) {
      return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }
    if (!ANTHROPIC_KEY) return new Response(JSON.stringify({ ok: false, error: "no Anthropic key" }), { status: 400, headers: { "Content-Type": "application/json" } });

    const items: any[] = await rpc("wisdom_absorb_data", {});
    if (!Array.isArray(items) || items.length === 0) {
      await rpc("wisdom_absorb_finish", { p_count: 0, p_summary: "Inbox empty; nothing to triage." });
      return new Response(JSON.stringify({ ok: true, triaged: 0 }), { headers: { "Content-Type": "application/json" } });
    }

    const system = [
      "You are the Archivist for Dog Gone Clean, a mobile dog-grooming business owned by Paul.",
      "You triage captured notes (wisdom) and decide where each belongs and what it is about, then rewrite it cleanly. Paul does not categorize; you do.",
      "Homes: 'oracle_rule' (a general, durable business rule or principle), 'client_note' (something specific to one named client), 'parking_lot' (a future idea or deferred work), 'field_manual' (an equipment, trailer, or craft how-to), 'drop' (noise, a duplicate, or nothing durable).",
      "Scope (the topic): one of business, client, pricing, operations, growth, finance, compliance, other.",
      "Rewrite each as one clean statement in because-form: the decision or fact, then 'Because' and the reason. Keep Paul's meaning; do not invent facts. No em dashes, no corporate jargon.",
      "If a note already names a client (the 'client' field is set), it is almost always home 'client_note' and scope 'client'.",
      'Respond with ONLY a JSON array, one object per input note: [{"id": string, "home": a home, "scope": a scope, "statement": string, "reason": short string}]. No prose around it.',
    ].join(" ");

    const aRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": ANTHROPIC_KEY!, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 2000, thinking: { type: "disabled" }, system,
        messages: [{ role: "user", content: "Triage these notes:\n" + JSON.stringify(items) }],
      }),
    });
    const aText = await aRes.text();
    if (!aRes.ok) throw new Error(`anthropic ${aRes.status}: ${aText}`);
    const aJson = JSON.parse(aText);
    const raw: string = (aJson.content ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("").trim();
    const tokens = (aJson.usage?.input_tokens ?? 0) + (aJson.usage?.output_tokens ?? 0);

    let proposals: any[] = [];
    try { const s = raw.indexOf("["); proposals = JSON.parse(s >= 0 ? raw.slice(s, raw.lastIndexOf("]") + 1) : raw); } catch { proposals = []; }

    const counts: Record<string, number> = {};
    let saved = 0;
    for (const p of proposals) {
      if (!p || !p.id || !HOMES.includes(p.home) || !p.statement) continue;
      const scope = SCOPES.includes(p.scope) ? p.scope : null;
      await rpc("wisdom_save_proposal", { p_id: p.id, p_home: p.home, p_text: String(p.statement).slice(0, 1000), p_scope: scope });
      counts[p.home] = (counts[p.home] ?? 0) + 1;
      saved++;
    }

    const summary = saved === 0 ? "Could not triage the inbox this run." :
      "Triaged " + Object.entries(counts).map(([h, n]) => `${n} for ${h.replace("_", " ")}`).join(", ") +
      ". Open the Knowledge Base to file them.";
    await rpc("wisdom_absorb_finish", { p_count: saved, p_summary: summary, p_model: MODEL, p_tokens: tokens });

    return new Response(JSON.stringify({ ok: true, triaged: saved, counts }, null, 2), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
