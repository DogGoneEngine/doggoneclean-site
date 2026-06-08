// supabase/functions/send-notification/index.ts
//
// Clean's confirmations + reminders dispatcher (the Acuity replacement),
// mirrored from DGN's send-notification and retargeted to Clean's tables and
// the legacy full-grooming reality: email only, in-person payment (no card /
// charge language), and the templates in legacy/notifications/email_templates.md.
//
// Given { kind, appointment_id } it loads the appointment context
// (bath_appointments -> bath_subscribers -> bath_subscriptions -> bath_dogs),
// renders the matching template, and sends via Resend, writing a notification_log
// row keyed by dedup_key so nothing ever double-sends. Fail-closed: with no
// Resend key it logs 'skipped: resend_not_configured' and sends nothing, so it
// stays dormant until cutover (no double reminders against Acuity).
//
// Secrets live in app_secrets (this environment cannot set function env vars):
//   notifications_secret  caller auth (the cron pastes it as x-notifications-secret)
//   resend_api_key        Resend send key (Paul's Dog Gone Clean Resend account)
//   resend_from           optional From; defaults to service@doggoneclean.us
//
// Kinds: booking_confirmation, reminder_3d, reminder_26h, reminder_day,
//        cancellation, reschedule.

import { Resend } from 'npm:resend@4';
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const TZ = 'America/New_York';
const PORTAL = 'https://doggoneclean.us/portal';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-notifications-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function secret(sb: SupabaseClient, name: string): Promise<string | null> {
  const env = Deno.env.get(name.toUpperCase());
  if (env) return env;
  const { data } = await sb.from('app_secrets').select('value').eq('name', name).maybeSingle();
  return (data?.value as string) ?? null;
}

// ── formatting ────────────────────────────────────────────────────────
function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', timeZone: TZ });
}
function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true, timeZone: TZ });
}
function joinNames(names: string[]): string {
  const n = names.filter(Boolean);
  if (n.length === 0) return 'your dog';
  if (n.length === 1) return n[0];
  if (n.length === 2) return `${n[0]} and ${n[1]}`;
  return n.slice(0, -1).join(', ') + ', and ' + n[n.length - 1];
}

interface Ctx { appt: any; sub: any; dogNames: string; }

async function loadCtx(sb: SupabaseClient, appointmentId: string): Promise<Ctx | null> {
  const { data: appt } = await sb.from('bath_appointments')
    .select('id, subscriber_id, subscription_id, scheduled_start, scheduled_end, dog_count, amount_cents, status, service_type')
    .eq('id', appointmentId).maybeSingle();
  if (!appt) return null;
  const { data: sub } = await sb.from('bath_subscribers')
    .select('id, first_name, last_name, email, phone_e164, address_line_1, address_city, address_state, address_zip')
    .eq('id', appt.subscriber_id).maybeSingle();
  if (!sub) return null;
  const { data: dogs } = await sb.from('bath_dogs').select('name').eq('subscriber_id', sub.id).eq('active', true);
  return { appt, sub, dogNames: joinNames((dogs ?? []).map((d) => d.name)) };
}

// ── templates ─────────────────────────────────────────────────────────
const SIG = 'Paul Nickerson\nDog Gone Clean\nMobile Dog Grooming\nOcala, Florida';
const PAY = 'Payment is easy. We take cash, Visa, Mastercard, American Express, Discover, Apple Pay, Google Pay, and Samsung Pay.';
const CANCEL = 'Appointments canceled or rescheduled within 24 hours are billed in full; once inside 24 hours that time is reserved just for you.';
const HEADSUP = "We'll send a heads-up with your exact arrival time before we roll your way. You will know we are coming.";
const TRAILER = "Inside the trailer, it's cool, dry, and comfortable no matter what Florida is doing outside. Thunder at home is one thing. Once dogs are in with us, the weather fades into the background.";

function block(ctx: Ctx) {
  return `${fmtTime(ctx.appt.scheduled_start)} to ${fmtTime(ctx.appt.scheduled_end)}`;
}

function render(kind: string, ctx: Ctx): { subject: string; text: string } {
  const first = ctx.sub.first_name || 'there';
  const day = fmtDate(ctx.appt.scheduled_start);
  const addr = ctx.sub.address_line_1 || '';
  const svc = ctx.appt.service_type === 'nails' ? 'nail' : ctx.appt.service_type === 'bath' ? 'bath' : 'grooming';
  let subject = '', body = '';
  switch (kind) {
    case 'booking_confirmation':
      subject = `You're booked for ${day}`;
      body = `Hi ${first},\n\nYou're booked for ${day}.\n\nYour appointment block runs ${block(ctx)}. The block is when the work gets done, not a wait-around arrival window. We usually get started within an hour of the opening and finish before it ends, and we'll text your exact arrival time before we roll your way.\n\n${TRAILER}\n\n${PAY}\n\nOnce an appointment is within 24 hours, that time is reserved just for you. Appointments canceled or rescheduled within 24 hours are billed in full.\n\nThank you,\n\n${SIG}`;
      break;
    case 'reminder_3d':
      subject = `Heads up, your appointment is ${day}`;
      body = `Hi ${first}!\n\nDog Gone Clean is on deck for ${day}. Your block runs ${block(ctx)}. The block is when the work gets done, not a wait-around arrival window. We usually get started within an hour of the opening and finish before it ends.\n\n${TRAILER}\n\n${HEADSUP}\n\nWe take cash, Visa, Mastercard, American Express, Discover, Apple Pay, Google Pay, and Samsung Pay.\n\nSee you then,\n\n${SIG}`;
      break;
    case 'reminder_26h':
      subject = `Tomorrow is the day`;
      body = `${first},\n\nTomorrow is the day! Your block runs ${block(ctx)}. The block is when the work gets done, not a wait-around arrival window. We usually get started within an hour of the opening and finish before it ends.\n\n${CANCEL}\n\nWe'll send you a reminder tomorrow, a few hours before the appointment, and as we get closer, we'll do our best to keep you updated on our ETA.\n\n${PAY}\n\nThank you,\n\n${SIG}`;
      break;
    case 'reminder_day':
      subject = `Today is the day`;
      body = `Hi ${first},\n\nToday, the calm part of your dog's day runs ${block(ctx)}. The block is when we complete the work, not a wait-around arrival window. We usually arrive within an hour of the opening and finish before it ends.\n\n${TRAILER} ${HEADSUP}\n\nSee you soon!\n\n${SIG}`;
      break;
    case 'cancellation':
      subject = `Your appointment is canceled`;
      body = `Hi ${first},\n\nYour appointment for ${day} is canceled, and that time is back open.\n\nNo hard feelings and no hassle. Whenever you're ready for the next one, we're a click away, and the trailer will be cool, dry, and waiting.\n\nThank you,\n\n${SIG}`;
      break;
    case 'reschedule':
      subject = `Your appointment is moved`;
      body = `Hi ${first},\n\nYou're moved. Dog Gone Clean is now on deck for ${day}. Your block runs ${block(ctx)}. The block is when the work gets done, not a wait-around arrival window. We usually get started within an hour of the opening and finish before it ends.\n\n${HEADSUP}\n\n${PAY}\n\nSee you then,\n\n${SIG}`;
      break;
    default:
      throw new Error('unknown_kind:' + kind);
  }
  // svc and addr are available for future per-service / address lines; addr kept out of the body per the templates.
  void svc; void addr;
  return { subject, text: body };
}

function html(text: string): string {
  const paras = text.split('\n\n').map((p) => `<p style="margin:0 0 12px;white-space:pre-line;">${p}</p>`).join('');
  return `<!doctype html><html><body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#1f2937;max-width:560px;margin:0 auto;padding:24px;line-height:1.6;">${paras}</body></html>`;
}

// ── dispatch ──────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method' }, 405);

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);

  const want = await secret(sb, 'notifications_secret');
  if (!want || req.headers.get('x-notifications-secret') !== want) return json({ error: 'unauthorized' }, 401);

  let body: { kind?: string; appointment_id?: string };
  try { body = await req.json(); } catch { return json({ error: 'bad_json' }, 400); }
  if (!body.kind || !body.appointment_id) return json({ error: 'kind_and_appointment_id_required' }, 400);

  const ctx = await loadCtx(sb, body.appointment_id);
  if (!ctx) return json({ error: 'appointment_not_found' }, 404);

  const channel = 'email';
  const dedup = `${body.kind}:${ctx.appt.id}:${channel}`;

  const { data: already } = await sb.from('notification_log')
    .select('id').eq('dedup_key', dedup).eq('status', 'sent').maybeSingle();
  if (already) return json({ kind: body.kind, status: 'already_sent' });

  async function log(status: string, opts: Record<string, unknown> = {}) {
    await sb.from('notification_log').insert({
      subscriber_id: ctx!.sub.id, appointment_id: ctx!.appt.id, kind: body.kind, channel,
      status, dedup_key: dedup, recipient: ctx!.sub.email ?? null, ...opts,
    });
  }

  const recipient = ctx.sub.email;
  if (!recipient) { await log('skipped', { skip_reason: 'no_recipient_on_file' }); return json({ kind: body.kind, status: 'skipped', reason: 'no_recipient_on_file' }); }

  let rendered;
  try { rendered = render(body.kind, ctx); }
  catch (e) { await log('failed', { error: String(e) }); return json({ kind: body.kind, status: 'failed', error: 'render_failed' }); }

  const apiKey = await secret(sb, 'resend_api_key');
  if (!apiKey) { await log('skipped', { skip_reason: 'resend_not_configured', subject: rendered.subject }); return json({ kind: body.kind, status: 'skipped', reason: 'resend_not_configured', subject: rendered.subject }); }

  const from = (await secret(sb, 'resend_from')) || 'Dog Gone Clean <service@doggoneclean.us>';
  try {
    const r = await new Resend(apiKey).emails.send({ from, to: recipient, subject: rendered.subject, text: rendered.text, html: html(rendered.text) });
    if ((r as any).error) { await log('failed', { subject: rendered.subject, error: JSON.stringify((r as any).error) }); return json({ kind: body.kind, status: 'failed' }); }
    await log('sent', { subject: rendered.subject, provider_id: (r as any).data?.id ?? null });
    return json({ kind: body.kind, status: 'sent' });
  } catch (e) {
    await log('failed', { subject: rendered.subject, error: String(e) });
    return json({ kind: body.kind, status: 'failed' });
  }
});
