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
export async function sendOtp(identity) {
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
        emailRedirectTo: `${window.location.origin}/portal/`,
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
export async function signInWithGoogle() {
  const client = sb();
  if (!client) return;
  await client.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}/portal/`,
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
  const { data: subRows, error: subErr } = await client
    .from('bath_subscribers')
    .select('*')
    .eq('auth_user_id', user.id)
    .limit(1);

  if (subErr) return { error: 'load_failed', detail: subErr.message };

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
