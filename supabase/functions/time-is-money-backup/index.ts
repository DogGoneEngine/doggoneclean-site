// time-is-money-backup
// Read/finish/load endpoint for the weekly Time is Money backup. Called by the Google
// Apps Script producer (which reads the master sheet directly under Paul's identity).
// Custom auth via x-cfo-secret (matches app_secrets.cfo_cron_secret); no JWT.
//
//   GET                          -> text/csv of the complete ledger (frozen history + live visits)
//   POST {action:'load_history'} -> one-time seed of the frozen history table from the master
//   POST {file_name,...}         -> logs the run + files the Today card

import { createClient } from "jsr:@supabase/supabase-js@2";

const COLS = ["Date","Client","Inbound","Arrival","Departure","Charged","Paid","Method","Appointment Duration","Cycle Time","On Site Rate","Cycle Rate","Operator","Helper","Rig"];
const cell = (v: unknown) => '"' + String(v ?? "").replace(/"/g, '""') + '"';

Deno.serve(async (req: Request) => {
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Custom auth: the shared cron secret, checked against app_secrets.
  const { data: secrow } = await sb.from("app_secrets").select("value").eq("name", "cfo_cron_secret").single();
  const given = req.headers.get("x-cfo-secret");
  if (!given || !secrow || given !== secrow.value) {
    return new Response("forbidden", { status: 403 });
  }

  if (req.method === "POST") {
    const b = await req.json().catch(() => ({}));

    if (b.action === "load_history") {
      const { data, error } = await sb.rpc("_load_time_is_money_history", { p_rows: b.rows });
      if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
      return new Response(JSON.stringify({ loaded: data }), { headers: { "Content-Type": "application/json" } });
    }

    const { data, error } = await sb.rpc("time_is_money_snapshot_finish", {
      p_file_name: b.file_name, p_file_url: b.file_url,
      p_rows: b.rows, p_folder_url: b.folder_url ?? null,
    });
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
    return new Response(JSON.stringify({ run_id: data }), { headers: { "Content-Type": "application/json" } });
  }

  // GET: the whole ledger as CSV.
  const { data, error } = await sb.rpc("_time_is_money_ledger");
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  const rows = (data ?? []) as Record<string, unknown>[];
  const lines = [COLS.map(cell).join(",")];
  for (const r of rows) lines.push(COLS.map((c) => cell(r[c])).join(","));
  return new Response(lines.join("\n"), { headers: { "Content-Type": "text/csv; charset=utf-8" } });
});
