import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Riker: parse one spoken/typed appointment update into a structured plan that
// admin_riker_apply can write. PROPOSES only; it never writes. Authenticates the
// caller as an admin by calling admin_riker_context with their own JWT (that RPC
// raises for non-admins), which also returns the client + dogs the parse may
// touch. Claude returns strict JSON; the frontend shows it for a one-tap confirm.
// Reads the Anthropic key from ANTHROPIC_API_KEY (falls back to Paul's name).

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? Deno.env.get("Claude Anthropic CFO Key");
const MODEL = "claude-sonnet-4-6";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  try {
    const auth = req.headers.get("Authorization") || "";
    if (!auth) return json({ ok: false, error: "unauthorized" }, 401);
    if (!ANTHROPIC_KEY) return json({ ok: false, error: "no Anthropic key secret found" }, 400);

    const { utterance, client_id } = await req.json();
    if (!utterance || !String(utterance).trim()) return json({ ok: false, error: "nothing said" }, 400);

    // Admin check + context, using the caller's own token.
    const ctxRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_riker_context`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON, Authorization: auth },
      body: JSON.stringify({ p_client_id: client_id ?? null }),
    });
    if (!ctxRes.ok) return json({ ok: false, error: "not authorized" }, 403);
    const ctx = await ctxRes.json();

    const today = new Date().toLocaleDateString("en-US", { weekday: "long", year: "numeric", month: "long", day: "numeric" });
    const fixedClient = !!client_id;

    const system = [
      "You are Riker, the data clerk for Dog Gone Clean, a mobile dog-grooming business owned by Paul.",
      "Paul speaks a short note about an appointment he just finished. Turn it into a structured plan of record updates.",
      `Today is ${today}.`,
      fixedClient
        ? "The client is already fixed (a contact sheet is open). Use the provided client and dogs."
        : "No client is open. Resolve which client Paul named using the provided client list (match name or any alias). If you cannot resolve exactly one, set matched=false and list candidates.",
      "Only ever use id values that appear in the provided context. Never invent an id, a dog, a price, or a fact Paul did not say.",
      "The vibe score is 1 to 5: 1 unsafe/aggression, 2 poor, 3 average, 4 cooperative, 5 a joy. Map words like 'a five', 'great', 'terror', 'bit me' sensibly; only set a score Paul actually gave.",
      "service_type is one of full_groom, bath, nails or null. payment_method is one of square_in_person, stripe_card, cash, wallet or null (map 'card'->square_in_person unless he says Stripe; 'venmo'/'apple pay'/'google pay'->wallet). amount_cents is dollars times 100.",
      "A standing instruction, access/gate change, or anything about how to do the work next time goes in client_note (household-level) or dog_notes (about one dog). Behavior or condition seen this visit goes in visit.visit_notes.",
      "If he gave a score, money, minutes, or what was done, include a visit object; otherwise visit is null.",
      "Write a short plain summary of exactly what will be recorded, so Paul can confirm in one tap. No corporate jargon. No em dashes.",
      'Respond as ONE JSON object, output only the JSON: {"matched": boolean, "client_id": string|null, "client_name": string|null, "candidates": [{"id":string,"name":string}], "summary": string, "visit": null | {"service_type": string|null, "work_done": string|null, "visit_notes": string|null, "actual_minutes": number|null, "amount_cents": number|null, "payment_method": string|null, "dog_scores": [{"dog_id": string, "dog_name": string, "score": number}]}, "client_note": string|null, "dog_notes": [{"dog_id": string, "dog_name": string, "text": string}]}',
    ].join(" ");

    const userMsg = "Context:\n" + JSON.stringify(ctx) + "\n\nPaul said:\n" + String(utterance).trim();

    const aRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": ANTHROPIC_KEY!, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 1200, thinking: { type: "disabled" }, system,
        messages: [{ role: "user", content: userMsg }],
      }),
    });
    const aText = await aRes.text();
    if (!aRes.ok) throw new Error(`anthropic ${aRes.status}: ${aText}`);
    const aJson = JSON.parse(aText);
    const raw: string = (aJson.content ?? []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("").trim();

    let plan: any;
    try {
      const s = raw.indexOf("{");
      plan = JSON.parse(s >= 0 ? raw.slice(s, raw.lastIndexOf("}") + 1) : raw);
    } catch {
      return json({ ok: false, error: "could not parse the update", raw }, 200);
    }

    // When a sheet is open, the client is non-negotiable.
    if (fixedClient) {
      plan.client_id = client_id;
      plan.matched = true;
      if (ctx?.client?.name) plan.client_name = ctx.client.name;
    }
    return json({ ok: true, plan });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
