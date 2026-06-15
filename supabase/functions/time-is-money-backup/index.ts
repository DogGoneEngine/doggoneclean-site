// time-is-money-backup
// Read/finish endpoint for the weekly Time is Money backup, called by the Google
// Apps Script producer (the calendar-sync pattern). Custom auth via x-cfo-secret
// (matches app_secrets.cfo_cron_secret); no JWT. Never write Drive here, that is the
// Apps Script's job under Paul's Google identity (Google blocks service-account keys
// on new projects). See time_is_money_weekly_backup in CLEAN_ORACLE.md.
//
//   GET  -> text/csv of the ENTIRE visit history (the full ledger)
//   POST {file_name,file_url,rows,folder_url} -> logs the run + files the Today card

import { createClient } from "jsr:@supabase/supabase-js@2";

const COLS = ["Date","Day","Client","Dogs","Service","Inbound","Arrival","Departure","Minutes","Charged","Paid","Tip","Method","Notes","Source"];
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
