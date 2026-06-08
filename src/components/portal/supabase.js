// src/components/portal/supabase.js
//
// Supabase client for the Dog Gone Clean portal (Hurricane Bath v2.0).
// Targets the dgc-prod project (ref urebdrosrxejhubpbxsa). The DGN
// project is never imported here per `own_infrastructure`.
//
// The publishable key below is safe to ship to the browser; RLS is what
// gates the data. Tables that hold subscriber PII (`bath_subscribers`,
// `bath_dogs`, `bath_subscriptions`, `bath_appointments`) have policies
// scoped to `auth.uid()`, so the anon key alone reaches nothing until a
// real auth session exists. Only `public.cities` is anon-readable, by
// design (the public site needs polygon + pricing).
//
// Auth helpers mirror the DGN portal pattern: Google OAuth is the
// primary path, with phone OTP and email magic link as fallbacks.

import { createClient } from '@supabase/supabase-js';

export const SUPABASE_URL = 'https://urebdrosrxejhubpbxsa.supabase.co';
export const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_3y18WUvZCuW-fiuPywR6nw_BLQyx1h6';

// Single shared client. persistSession:true keeps the user signed in
// across reloads (the portal needs this; the booking flow's client will
// use persistSession:false to keep a fresh transaction).
let _client = null;
export function sb() {
  if (_client) return _client;
  if (typeof window === 'undefined') return null;
  _client = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });
  return _client;
}

// ── Reachability guard ────────────────────────────────────────────────
// Wrap any promise so it rejects if the backend does not answer in time.
// A paused or unreachable Supabase project makes auth/refresh and getUser
// calls hang with no response; without this the portal would spin forever
// on the "checking" or "loading" state. With it, a hang surfaces as an
// honest error the user can retry. Default ceiling is generous so a slow
// but live network never trips it.
export const BACKEND_TIMEOUT_MS = 8000;
export function withTimeout(promise, ms = BACKEND_TIMEOUT_MS, label = 'backend') {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error(`timeout: ${label} did not respond`)), ms)
    ),
  ]);
}

// ── Identity / E.164 ──────────────────────────────────────────────────
// Permissive email detector (anything containing an @).
export function looksLikeEmail(s) {
  return typeof s === 'string' && s.includes('@');
}

// Convert a US phone string into E.164 (+1XXXXXXXXXX). Returns null if
// we cannot confidently produce 10 digits.
export function toE164US(raw) {
  if (typeof raw !== 'string') return null;
  const digits = raw.replace(/\D/g, '');
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`;
  return null;
}

// ── Auth ──────────────────────────────────────────────────────────────
// Send an OTP (SMS) for a phone, or a magic link for an email.
// Returns { error, isPhone, e164 }.
export async function sendOtp(identity, redirectPath = '/portal/') {
  const client = sb();
  if (!client) return { error: new Error('No client'), isPhone: false };
  const isPhone = !looksLikeEmail(identity);
  if (isPhone) {
    const e164 = toE164US(identity);
    if (!e164) return { error: new Error('invalid phone'), isPhone: true };
    const { error } = await client.auth.signInWithOtp({ phone: e164 });
    return { error, isPhone: true, e164 };
  } else {
    const { error } = await client.auth.signInWithOtp({
      email: identity,
      options: {
        emailRedirectTo: `${window.location.origin}${redirectPath}`,
      },
    });
    return { error, isPhone: false };
  }
}

// Verify a 6-digit OTP code sent by sendOtp. Returns { error }.
export async function verifyOtp(identity, isPhone, e164, token) {
  const client = sb();
  if (!client) return { error: new Error('No client') };
  if (isPhone) {
    return client.auth.verifyOtp({ phone: e164, token, type: 'sms' });
  }
  // Email magic-link verification happens via the redirect callback;
  // this path is unused but kept for parity with DGN.
  return client.auth.verifyOtp({ email: identity, token, type: 'email' });
}

// Sign in with Google OAuth. Redirects the tab; no return value.
export async function signInWithGoogle(redirectPath = '/portal/') {
  const client = sb();
  if (!client) return;
  await client.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}${redirectPath}`,
    },
  });
}

export async function signOut() {
  const client = sb();
  if (!client) return;
  await client.auth.signOut();
}

// ── Portal data load ──────────────────────────────────────────────────
// Returns a coherent shape for the portal to render. Handles three states:
//   1. Not signed in -> { error: 'not_authenticated' }
//   2. Signed in, no subscriber row yet -> { authUser, subscriber: null }
//   3. Signed in, has subscriber row -> { authUser, subscriber, dogs,
//        subscription, appointments, city }
//
// State 2 is normal for someone who signed into the portal before going
// through the booking flow. The portal renders an empty state in that
// case ("Book your first visit to get started").
export async function getPortalData() {
  const client = sb();
  if (!client) return { error: 'no_client' };

  const { data: { user }, error: userErr } = await client.auth.getUser();
  if (userErr || !user) return { error: 'not_authenticated' };

  // Look for an existing subscriber row tied to this auth user.
  let { data: subRows, error: subErr } = await client
    .from('bath_subscribers')
    .select('*')
    .eq('auth_user_id', user.id)
    .limit(1);

  if (subErr) return { error: 'load_failed', detail: subErr.message };

  // Legacy clients live in `clients`, not bath_subscribers, so a first
  // sign-in finds no row. Attempt to claim/link their legacy account by the
  // verified sign-in identity (phone or email), then re-read.
  if (!subRows || subRows.length === 0) {
    const { data: claim } = await client.rpc('bath_claim_legacy_account');
    if (claim && claim.claimed) {
      const reSub = await client
        .from('bath_subscribers')
        .select('*')
        .eq('auth_user_id', user.id)
        .limit(1);
      subRows = reSub.data;
    }
  }

  if (!subRows || subRows.length === 0) {
    return { authUser: user, subscriber: null };
  }

  const subscriber = subRows[0];

  // Fan out for the rest of the portal data. None of these are required
  // to render the empty-state landing, but pulling them now keeps the
  // shape ready for the views that arrive in later phases.
  const [{ data: dogs }, { data: subs }, { data: appts }, { data: cities }] =
    await Promise.all([
      client.from('bath_dogs').select('*').eq('subscriber_id', subscriber.id),
      client
        .from('bath_subscriptions')
        .select('*')
        .eq('subscriber_id', subscriber.id)
        .order('started_at', { ascending: false })
        .limit(1),
      client
        .from('bath_appointments')
        .select('*')
        .eq('subscriber_id', subscriber.id)
        .order('scheduled_start', { ascending: false }),
      subscriber.city_id
        ? client.from('cities').select('*').eq('id', subscriber.city_id).limit(1)
        : Promise.resolve({ data: [] }),
    ]);

  return {
    authUser: user,
    subscriber,
    dogs: dogs || [],
    subscription: (subs && subs[0]) || null,
    appointments: appts || [],
    city: (cities && cities[0]) || null,
  };
}

// ── Booking flow (Hurricane Bath signup) ──────────────────────────────
// The /book funnel reads the public city row (anon-readable) for live
// pricing, reads open slots from the SECURITY DEFINER bath_open_slots
// (which returns only free timestamps, no PII), and submits through the
// bath_start_subscription RPC, which enforces the rule pack server-side.

// Read the launch city by slug (anon-readable). Returns { city } or
// { error }. Pricing columns may be null on a city without v2.0 yet.
export async function getBookingCity(slug = 'the-villages') {
  const client = sb();
  if (!client) return { error: 'no_client' };
  const { data, error } = await client
    .from('cities')
    .select('*')
    .eq('slug', slug)
    .eq('hb_active', true)
    .limit(1);
  if (error) return { error: error.message };
  if (!data || data.length === 0) return { error: 'city_not_open' };
  return { city: data[0] };
}

// Fetch open slots for a city over the booking horizon. Returns an array
// of { slot_start, slot_end } (ISO strings), already filtered to free,
// future times by the database function. Empty until the operator has
// posted availability windows (honest empty state in the picker).
export async function getOpenSlots(cityId, days = 28) {
  const from = new Date();
  const to = new Date(from.getTime() + days * 24 * 60 * 60 * 1000);
  return getOpenSlotsBetween(cityId, from, to);
}

// Same, for an explicit [from, to] window (the "specific month" picker).
export async function getOpenSlotsBetween(cityId, from, to) {
  const client = sb();
  if (!client) return { error: 'no_client', slots: [] };
  const { data, error } = await client.rpc('bath_open_slots', {
    p_city_id: cityId,
    p_from: new Date(from).toISOString(),
    p_to: new Date(to).toISOString(),
  });
  if (error) return { error: error.message, slots: [] };
  return { slots: data || [] };
}

// Submit the signup. Books anonymously (no auth session): identity is the
// phone number; the RPC creates the subscriber, dogs, subscription, and
// first appointment. The card (stripe_payment_method_id) is null on the
// pre-launch path and becomes required once Stripe is wired. Returns the
// RPC result object or { error }.
export async function startSubscription(payload) {
  const client = sb();
  if (!client) return { error: 'no_client' };
  const { data, error } = await client.rpc('bath_start_subscription', {
    p_city_slug: payload.citySlug,
    p_first_name: payload.firstName,
    p_last_name: payload.lastName,
    p_email: payload.email,
    p_phone_e164: payload.phoneE164,
    p_address_line_1: payload.addressLine1,
    p_address_city: payload.addressCity,
    p_address_state: payload.addressState,
    p_address_zip: payload.addressZip,
    p_service_lat: payload.serviceLat ?? null,
    p_service_lng: payload.serviceLng ?? null,
    p_gate_code: payload.gateCode ?? null,
    p_sms_opt_in: payload.smsOptIn ?? true,
    p_dogs: payload.dogs,
    p_cadence: payload.cadence,
    p_slot_start: payload.slotStart,
    p_stripe_payment_method_id: payload.stripePaymentMethodId ?? null,
  });
  if (error) return { error: error.message };
  return { result: data };
}

// Returning-client recognition (Step 1): given an E164 phone, ask the server if
// we already know this person, so the funnel can greet them by name. The RPC
// returns only { found, first_name } (minimal PII). Returns { found:false } on
// any error so a hiccup never blocks typing.
export async function lookupSubscriberByPhone(phoneE164) {
  const client = sb();
  if (!client || !phoneE164) return { found: false };
  const { data, error } = await client.rpc('bath_lookup_subscriber', { p_phone_e164: phoneE164 });
  if (error || !data) return { found: false };
  return { found: !!data.found, firstName: data.first_name || '' };
}

// ── Subscription lifecycle (portal self-service) ──────────────────────
// Each calls a SECURITY DEFINER RPC that resolves the caller's own
// subscription through auth.uid() and enforces the state change in the
// database. The RPC also takes any future visit off the calendar on pause
// and cancel. Returns { ok, status } or { ok:false, error }.
async function callSubscriptionRpc(fnName) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { data, error } = await client.rpc(fnName);
  if (error) return { ok: false, error: error.message };
  return data || { ok: false, error: 'no_result' };
}

export function pauseSubscription() {
  return callSubscriptionRpc('bath_pause_subscription');
}

export function resumeSubscription() {
  return callSubscriptionRpc('bath_resume_subscription');
}

export function cancelSubscription() {
  return callSubscriptionRpc('bath_cancel_subscription');
}

// Switch recurring cadence ('4wk' <-> '2wk'). Same price either way.
// Returns { ok, cadence } or { ok:false, error }.
export async function changeCadence(cadence) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { data, error } = await client.rpc('bath_change_cadence', { p_cadence: cadence });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false, error: 'no_result' };
}

// ── Profile (portal self-service) ─────────────────────────────────────
// Updates contact details and preferences only. Service address is not
// here: it needs the in-area verification flow and gets its own RPC.
export async function updateProfile(fields) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { data, error } = await client.rpc('bath_update_profile', {
    p_first_name: fields.firstName,
    p_last_name: fields.lastName ?? null,
    p_phone_e164: fields.phoneE164 ?? null,
    p_email: fields.email ?? null,
    p_gate_code: fields.gateCode ?? null,
    p_sms_opt_in: fields.smsOptIn,
    p_email_opt_in: fields.emailOptIn,
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false, error: 'no_result' };
}

// Change the service address. Coordinates must fall inside the
// subscriber's city polygon; the server re-verifies and sets
// address_verified. Returns { ok } or { ok:false, error:'out_of_area' | ... }.
export async function updateServiceAddress(fields) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { data, error } = await client.rpc('bath_update_service_address', {
    p_address_line_1: fields.line1,
    p_address_city: fields.city,
    p_address_state: fields.state || 'FL',
    p_address_zip: fields.zip,
    p_service_lat: fields.lat,
    p_service_lng: fields.lng,
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false, error: 'no_result' };
}

// ── Reminder preferences (portal self-service) ────────────────────────
// Read/save which reminders the client wants and on which channel. Both
// resolve the caller's own subscriber server-side through auth.uid().
// Returns { ok, prefs } or { ok:false, error }.
export async function getNotificationPrefs() {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { data, error } = await client.rpc('bath_get_notification_prefs');
  if (error) return { ok: false, error: error.message };
  return data || { ok: false, error: 'no_result' };
}

export async function setNotificationPrefs(prefs) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { data, error } = await client.rpc('bath_set_notification_prefs', { p_prefs: prefs });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false, error: 'no_result' };
}

// ── Pack management (portal self-service) ─────────────────────────────
// Ownership is enforced by the bath_dogs self RLS policies; the 3-active
// household cap is enforced by the bath_dogs_cap trigger. These use the
// supabase-js query builder (not raw fetch), which is the supported path.
export async function addDog({ subscriberId, name, breed, coatTier, behaviorNotes }) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { data, error } = await client
    .from('bath_dogs')
    .insert({
      subscriber_id: subscriberId,
      name,
      breed: breed || null,
      coat_tier: coatTier,
      behavior_notes: behaviorNotes || null,
      active: true,
    })
    .select('id')
    .single();
  if (error) return { ok: false, error: error.message };
  return { ok: true, id: data.id };
}

export async function updateDog(dogId, { name, breed, behaviorNotes }) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { error } = await client
    .from('bath_dogs')
    .update({
      name,
      breed: breed || null,
      behavior_notes: behaviorNotes || null,
      updated_at: new Date().toISOString(),
    })
    .eq('id', dogId);
  if (error) return { ok: false, error: error.message };
  return { ok: true };
}

// Soft delete: a removed dog goes inactive, so its history is preserved.
export async function removeDog(dogId) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { error } = await client
    .from('bath_dogs')
    .update({ active: false, updated_at: new Date().toISOString() })
    .eq('id', dogId);
  if (error) return { ok: false, error: error.message };
  return { ok: true };
}

// ── Per-visit actions (portal self-service) ───────────────────────────
// Skip one upcoming visit. Returns { ok, status } or { ok:false, error }.
export async function skipAppointment(appointmentId) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { data, error } = await client.rpc('bath_skip_appointment', {
    p_appointment_id: appointmentId,
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false, error: 'no_result' };
}

// Move one upcoming visit to a free slot. newStart is an ISO timestamp that
// must match a slot returned by getOpenSlots; the server revalidates it.
export async function rescheduleAppointment(appointmentId, newStart) {
  const client = sb();
  if (!client) return { ok: false, error: 'no_client' };
  const { data, error } = await client.rpc('bath_reschedule_appointment', {
    p_appointment_id: appointmentId,
    p_new_start: newStart,
  });
  if (error) return { ok: false, error: error.message };
  return data || { ok: false, error: 'no_result' };
}
