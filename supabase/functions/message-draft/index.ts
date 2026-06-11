import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Message draft: Paul dumps stream-of-consciousness about a dog or an appointment;
// this has Claude turn it into a short, warm, personal message he could send the
// client. TEST ONLY for now: it returns a draft to Paul, it never sends. Later it
// feeds the post-appointment send. Auth + client/dog context come from
// admin_riker_context (raises for non-admins). verify_jwt off + CORS like riker.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? Deno.env.get("Claude Anthropic CFO Key");
const MODEL = "claude-sonnet-4-6";

async function logUsage(usage: { input_tokens?: number; output_tokens?: number } | undefined) {
  if (!usage) return;
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/agent_costs`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, Prefer: "return=minimal" },
      body: JSON.stringify({ agent_key: "message-draft", model: MODEL, input_tokens: usage.input_tokens ?? 0, output_tokens: usage.output_tokens ?? 0 }),
    });
  } catch (_) { /* cost logging never blocks the draft */ }
}

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...CORS } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const auth = req.headers.get("Authorization") || "";
    if (!auth) return json({ ok: false, error: "unauthorized" }, 401);
    if (!ANTHROPIC_KEY) return json({ ok: false, error: "no Anthropic key secret found" }, 400);

    const { client_id, thoughts } = await req.json();
    if (!thoughts || !String(thoughts).trim()) return json({ ok: false, error: "nothing to work with" }, 400);

    const ctxRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_riker_context`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON, Authorization: auth },
      body: JSON.stringify({ p_client_id: client_id ?? null }),
    });
    if (!ctxRes.ok) return json({ ok: false, error: "not authorized" }, 403);
    const ctx = await ctxRes.json();

    const system = [
      "You write a short, warm, genuine message that Paul, the owner of Dog Gone Clean (a mobile dog-grooming business), could send a client after their appointment.",
      "You are given Paul's rough stream-of-consciousness notes about the dog or the visit, plus the client and dog names.",
      "Pull out what is worth saying to the client and write it as if from Paul: personal and specific (use the dog's name and a real detail from his notes), never salesy, never generic filler, no flattery he did not mean.",
      "Keep it to one short paragraph a person would actually text or email. Plain warmth, not corporate. No corporate jargon (no 'reach out', 'circle back'). No em dashes.",
      "If his notes do not contain anything genuinely worth sending, say so honestly in the 'note' field and leave the draft short or empty rather than inventing sentiment.",
      'Respond as ONE JSON object, output only the JSON: {"draft": string, "note": string}. "note" is a one-line aside to Paul (not part of the message), e.g. what you keyed on or that there was not much to use.',
    ].join(" ");

    const userMsg = "Client + dogs:\n" + JSON.stringify(ctx) + "\n\nPaul's notes:\n" + String(thoughts).trim();

    const aRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": ANTHROPIC_KEY!, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 700, thinking: { type: "disabled" }, system,
        messages: [{ role: "user", content: userMsg }],
      }),
    });
    const aText = await aRes.text();
    if (!aRes.ok) throw new Error(`anthropic ${aRes.status}: ${aText}`);
    const aJson = JSON.parse(aText);
    await logUsage(aJson.usage);
    const raw: string = (aJson.content ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("").trim();

    let out: any;
    try {
      const s = raw.indexOf("{");
      out = JSON.parse(s >= 0 ? raw.slice(s, raw.lastIndexOf("}") + 1) : raw);
    } catch {
      out = { draft: raw, note: "" };
    }
    return json({ ok: true, draft: out.draft || "", note: out.note || "" });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
