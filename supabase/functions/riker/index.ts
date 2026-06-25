import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Riker: parse one spoken/typed note into a structured plan that
// admin_riker_apply can write. PROPOSES only; it never writes. Authenticates the
// caller as an admin by calling admin_riker_context with their own JWT (that RPC
// raises for non-admins), which also returns the client + dogs the parse may
// touch. Claude returns strict JSON; the frontend shows it for a one-tap confirm.
// Reads the Anthropic key from ANTHROPIC_API_KEY (falls back to Paul's name).
// Logs token usage to agent_costs so HR can show what each agent costs.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? Deno.env.get("Claude Anthropic CFO Key");
const MODEL = "claude-sonnet-4-6";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...CORS } });

async function logUsage(usage: { input_tokens?: number; output_tokens?: number } | undefined) {
  if (!usage) return;
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/agent_costs`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json", apikey: SERVICE_ROLE,
        Authorization: `Bearer ${SERVICE_ROLE}`, Prefer: "return=minimal",
      },
      body: JSON.stringify({
        agent_key: "riker", model: MODEL,
        input_tokens: usage.input_tokens ?? 0, output_tokens: usage.output_tokens ?? 0,
      }),
    });
  } catch (_) { /* cost logging never blocks the parse */ }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
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

    const today = new Date().toLocaleDateString("en-US", { weekday: "long", year: "numeric", month: "long", day: "numeric", timeZone: "America/New_York" });
    const fixedClient = !!client_id;

    const system = [
      "You are Riker, the data clerk for Dog Gone Clean, a mobile dog-grooming business owned by Paul.",
      "Paul speaks a short note. It may contain SEVERAL actions at once; capture all of them in one plan. Turn it into a structured plan of record updates.",
      `Today is ${today}.`,
      fixedClient
        ? "The client is already fixed (a contact sheet is open). Use the provided client and dogs."
        : "No client is open. Resolve which client Paul named using the provided client list (match name or any alias). If you cannot resolve exactly one, set matched=false and list candidates.",
      "Only ever use id values that appear in the provided context. Never invent an id, a dog, a price, or a fact Paul did not say.",
      "The vibe score is 1 to 5: 1 unsafe/aggression, 2 poor, 3 average, 4 cooperative, 5 a joy. Map words like 'a five', 'great', 'terror', 'bit me' sensibly; only set a score Paul actually gave.",
      "service_type is one of full_groom, bath, nails or null. payment_method is one of square_in_person, stripe_card, cash, wallet, paypal, cashapp, venmo or null (map 'card'->square_in_person unless he says Stripe; 'apple pay'/'google pay'/'samsung pay'->wallet; 'paypal'->paypal; 'cash app'/'cashapp'->cashapp; 'venmo'->venmo). wallet means a phone tap that settles through Square (Apple, Google, Samsung Pay); paypal, cashapp and venmo each settle to their own account and not Square, so keep them distinct and never fold them into wallet. amount_cents is what the client actually PAID (collected), dollars times 100. When Paul gives a separate price and payment ('charged 105, paid 120'), set charged_cents to the price charged, amount_cents to what was paid, and tip_cents to the difference when paid is more than charged (or to a tip he states outright). When he gives only one number, it is amount_cents (collected) and charged_cents and tip_cents stay null.",
      "A GETTING-IN or ARRIVAL instruction, how to reach or enter the home and announce yourself (a gate code, where to park, 'do not knock', 'text on arrival', 'use the side gate', 'ring the bell, not the knocker', 'a baby may be sleeping so do not knock'), goes in access_note as one short clause in Paul's OWN words. This is the 'Getting in' line shown on the appointment, so it has to be there to be seen at the door. Keep his wording and his strength; do not soften it ('be careful about knocking' is NOT 'knock quietly', and 'do not knock' stays 'do not knock'). access_note is NOT client_note (household facts and standing work preferences) and NOT onsite_update (who is physically at the house).",
      "A STANDING GROOMING INSTRUCTION for ONE dog, how to groom that dog every time (comb and blade lengths like '13mm comb on the body, 7F on the feet', the order to do things, and what to do or avoid on the groom such as 'no sanitary shave, she gets itchy' or 'do not cut her eyelashes'), goes in dog_standing, NOT dog_notes. This is the spec the operator reads at the door. dog_standing.text REPLACES that dog's current standing instructions, so when the context shows existing standing_instructions for the dog, include the parts that still apply and then add what Paul just said, and state the full resulting text in the summary. When Paul says 'this is a standing instruction, not a note', it is always dog_standing.",
      "dog_notes is for a durable FACT about a dog that is NOT the groom recipe (a health watch, a temperament trait, 'moved to Tampa', 'is the daughter's dog'). A household-level standing preference that is not about one dog goes in client_note. How the work went on THIS visit goes in visit.visit_notes.",
      "A fact about WHO IS PHYSICALLY AT THE HOUSE (a caregiver, who answers the door, who hands you the dog) goes in onsite_update as one short clause, e.g. 'Husband Alan.'; it appends to the who's-on-site field. Never bury a household person in client_note.",
      "A HOUSEHOLD NAME or 'also known as' (a name to file the household under so a search finds them, e.g. 'add her husband Zach Brown as a household name', 'they also go by the Smiths') goes in alias_add: an array of the names exactly as said. This is the searchable Also-known-as field, NOT who's-on-site and NOT a notify person.",
      "ONE person goes in ONE place. Pick the single field that matches what Paul asked: alias_add for a household name, onsite_update for who is at the house, notify_person for a reachable household contact (their phone/email, whether or not they get the messages). Do NOT also copy that person into the other fields. 'Add only X' means add X exactly once. Use more than one field for the same person ONLY when Paul explicitly asks for more than one of those things.",
      "A contact-sheet FACT (phone number, email, address) for THE CLIENT THEMSELVES goes in client_update, never a note: {phone: '+1' then ten digits, email, address}. client_update is ONLY the client's own contact info. A phone number or email for ANYONE ELSE (a husband, wife, partner, son, daughter, a household member, a dog sitter) is NOT client_update; it goes in notify_person (see below). If Paul says a client moved away, paused, or should not be chased, client_update carries status 'moved_away' (or 'inactive') and suppress_winback true, plus a client_note restating what he said.",
      "If Paul CORRECTS an existing visit record (wrong service, wrong amount, 'that should have been nails'), use visit_update with the date of that visit from recent_visits: {date: 'YYYY-MM-DD', service_type, amount_cents, actual_minutes, visit_notes}. Do NOT create a new visit for a correction.",
      "A PRICE CHANGE or breed correction on an existing dog goes in dog_update with the dog's id (or dog_name) and price_cents/breed. A price change is NEVER a note. '$50 each' means every regular dog gets its own dog_update entry.",
      "A dog's BIRTHDAY or birth date goes in dog_update too, as birthday: YYYY-MM-DD (resolve a spoken date like '8/31/18' to '2018-08-31'). Set dob_approximate true only when Paul says it is a guess or approximate. A birthday is NEVER a note.",
      "A NEW DOG Paul describes that is not in the context goes in dog_add: name, breed, price_cents if he gives a price, notes for anything else he says about the dog. Do not also put the new dog in dog_notes.",
      "If the visit he describes happened in the past ('the previous appointment', 'last time', a date), set visit.visited_at to that date as YYYY-MM-DD. The context's last_visit is the date of the most recent recorded visit; use it when he says 'the previous appointment, whenever it was'. Scores for dogs being added in this same plan use dog_name instead of dog_id.",
      "If Paul commits to do something by or at a future time ('contact her in 2 weeks', 'follow up after the holidays', 'check on the dog next month'), include reminder: {body: a self-contained sentence with who/what/why, due: YYYY-MM-DD resolved from today}. The reminder surfaces on his Today screen when due.",
      "notify_person is where a HOUSEHOLD CONTACT who is not the client lives: a spouse, partner, son or daughter, a dog sitter, anyone whose phone or email Paul wants on the record. Use it both when Paul just adds that person's number ('add a phone for her husband Bo', 'Bo's cell is 352-895-7134') AND when he says that person should receive the appointment messages. Include notify_person: the name, the phone and/or email he gives (format US phones as +1 then ten digits), relationship if he says one (husband, wife, sitter), mode 'in_addition' (the usual: they are an extra contact alongside the client) or 'instead' when they temporarily replace the client, and until as YYYY-MM-DD when he gives an end (resolve 'until July' to a date).",
      "RESOLVE who the person is from the context before saying you cannot. The open client's context lists 'aliases' (household names already on file, e.g. 'Bo Hunt') and 'notify_people' (contacts already saved). If Paul names someone who matches one of those (he says 'Bo' and the aliases or notify_people show 'Bo Hunt'), that IS the person: use that full name, and reuse the existing notify_person id when one is already there. NEVER answer that there is no such person when a household name or existing contact plausibly matches; a name Paul just added as a household name is a real person.",
      "The notify_person 'active' flag controls whether that person actually GETS the messages. Set active true ONLY when Paul clearly says they should be messaged now ('text him too', 'send her the reminders', 'turn Bo's notifications on'). When Paul is only putting a contact's number on file (the default for 'add a phone for Bo'), set active false: it stays on file and Paul can toggle it on later from the record. Set active false too when he says to stop messaging an existing contact. Say in the summary which it is, e.g. 'saving Bo Hunt's number on file, notifications off for now' or 'Bo Hunt will now get the appointment texts'. If Paul gives neither a phone nor an email for the person, it cannot be saved, so say that plainly instead of inventing one.",
      "If Paul says a dog should come off or back onto the working roster (moved away, passed away, no longer groomed, only sometimes, archive him, he's back), include it in dog_status with the dog's id and the right status: 'moved' (relocated, may return), 'deceased' (passed away), 'former' (no longer groomed), 'occasional' (sometimes), 'regular' (back on the roster). Nothing is ever deleted; this is reversible. Include a short note restating what Paul said when he gave a reason.",
      "If there is an OPEN TASK in the context (open_tasks) that is clearly ASKING FOR the very information Paul is now giving (for example an open task 'find the appliance wattages' and Paul says the wattages, or a task 'get the gate code' and Paul says the code), do NOT file it as wisdom. Instead set task_attachment: {task_id: that task's id from open_tasks, note: the information as one self-contained sentence}. Match only when the fit to a SINGLE open task is clear; if two tasks could fit, or none clearly does, leave task_attachment null and fall back to wisdom. Never invent a task_id; use only ids present in open_tasks.",
      "If Paul shares a general lesson, technique, or business insight not tied to one client's records AND not the answer to an open task, put it in wisdom as a self-contained sentence (it lands in the knowledge base). A client-specific fact is a note, not wisdom.",
      "If Paul reports MAINTENANCE or service on a generator (changed the oil, the spark plug, the air filter, and/or read the hour meter), put it in equipment_service: an array, one entry per unit, of {equipment_id (from the provided equipment list; resolve 'passenger side', 'driver side', or 'the one that runs the air conditioner' to the right unit by its side and what it powers), hours (the engine-hour number he read off the panel, or null), tasks (the service names he did, copied from that unit's listed task names, e.g. 'Oil change (10W-30)', 'Inspect spark plug', 'Clean/inspect air filter')}. Each side is its own entry even when he says 'same service on the other one'. Generator maintenance is never a client note.",
      "Always try to capture how long the visit took, because the workload numbers depend on it. If Paul gives a duration ('about an hour and a half', 'two hours', 'forty five minutes'), set visit.actual_minutes to that many minutes. If he gives arrival and/or departure clock times ('there from 1 to 3', 'got there at 1, left at 2:45', 'arrived 9 done by 11'), set visit.arrived_at and visit.departed_at as 24-hour HH:MM local times on the visit date and the system computes the minutes from them. If he gives no time at all, leave actual_minutes, arrived_at and departed_at null and say plainly in the summary that no time was recorded, so he knows to add it.",
      "If he gave a score, money, minutes, a time, or what was done, include a visit object; otherwise visit is null.",
      "Write a short plain summary of exactly what will be recorded, so Paul can confirm in one tap. No corporate jargon. No em dashes.",
      'Respond as ONE JSON object, output only the JSON: {"matched": boolean, "client_id": string|null, "client_name": string|null, "candidates": [{"id":string,"name":string}], "summary": string, "visit": null | {"visited_at": string|null, "service_type": string|null, "work_done": string|null, "visit_notes": string|null, "actual_minutes": number|null, "arrived_at": string|null, "departed_at": string|null, "amount_cents": number|null, "charged_cents": number|null, "tip_cents": number|null, "payment_method": string|null, "dog_scores": [{"dog_id": string|null, "dog_name": string, "score": number}]}, "client_note": string|null, "access_note": string|null, "alias_add": [string], "dog_notes": [{"dog_id": string, "dog_name": string, "text": string}], "dog_standing": [{"dog_id": string, "dog_name": string, "text": string}], "dog_add": [{"name": string, "breed": string|null, "price_cents": number|null, "notes": string|null}], "dog_update": [{"dog_id": string|null, "dog_name": string, "price_cents": number|null, "breed": string|null, "birthday": string|null, "dob_approximate": boolean|null}], "dog_status": [{"dog_id": string, "dog_name": string, "status": "regular"|"occasional"|"moved"|"former"|"deceased", "note": string|null}], "notify_person": null | {"id": string|null, "name": string, "phone": string|null, "email": string|null, "relationship": string|null, "mode": "in_addition"|"instead", "active": boolean|null, "until": string|null}, "client_update": null | {"phone": string|null, "email": string|null, "address": string|null, "status": string|null, "suppress_winback": boolean|null}, "onsite_update": string|null, "visit_update": null | {"date": string, "service_type": string|null, "amount_cents": number|null, "actual_minutes": number|null, "visit_notes": string|null}, "reminder": null | {"body": string, "due": string}, "equipment_service": [{"equipment_id": string, "hours": number|null, "tasks": [string]}], "task_attachment": null | {"task_id": string, "note": string}, "wisdom": string|null}',
    ].join(" ");

    const userMsg = "Context:\n" + JSON.stringify(ctx) + "\n\nPaul said:\n" + String(utterance).trim();

    const aRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-api-key": ANTHROPIC_KEY!, "anthropic-version": "2023-06-01" },
      body: JSON.stringify({
        model: MODEL, max_tokens: 2400, thinking: { type: "disabled" }, system,
        messages: [{ role: "user", content: userMsg }],
      }),
    });
    const aText = await aRes.text();
    if (!aRes.ok) throw new Error(`anthropic ${aRes.status}: ${aText}`);
    const aJson = JSON.parse(aText);
    await logUsage(aJson.usage);
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

    // Every parse on the record (riker_log), so a "Riker would not
    // cooperate" report is diagnosable from data instead of memory.
    try {
      await fetch(`${SUPABASE_URL}/rest/v1/riker_log`, {
        method: "POST",
        headers: { "Content-Type": "application/json", apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, Prefer: "return=minimal" },
        body: JSON.stringify({ utterance: String(utterance).trim(), client_id: client_id ?? null, plan }),
      });
    } catch (_) { /* logging never blocks the parse */ }

    return json({ ok: true, plan });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
