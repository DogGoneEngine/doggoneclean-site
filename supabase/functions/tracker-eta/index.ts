// supabase/functions/tracker-eta/index.ts
//
// Live ETA + truck position for the Dog Gone Tracker (pizza_tracker_client_loop).
// A tracker visitor holds only the appointment's tracker_token, so this
// function is the token-scoped bridge: token -> that appointment's latest
// operator fix (tracker_locations, written from the Today sheet while
// rolling) -> Google-computed drive ETA to that client's own address.
//
// Cost control: the ETA is cached on the tracker_locations row and only
// recomputed when the cache is older than 75 seconds or the truck has moved
// about 250 meters, so clients can poll every 20 seconds for a smooth map
// without re-billing Distance Matrix each time.
//
// Privacy: position is served ONLY while the visit is en route (on_the_way,
// not yet arrived), only to the holder of that visit's token, and the
// destination returned is the client's own address. admin_arrived deletes
// the location row, so the broadcast provably ends at the driveway.
//
// verify_jwt is OFF on the house pattern (same as riker and tracker-photos:
// the publishable key is not a JWT, so the gateway would 401 browser calls);
// the unguessable tracker_token is the credential.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ETA_CACHE_SECONDS = 75;
const MOVE_RECOMPUTE_DEG = 0.0025; // ~250 m of latitude
const STALE_FIX_SECONDS = 300;     // a 5-minute-old fix is history, not live

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

async function getMapsKey(sb: ReturnType<typeof createClient>): Promise<string | null> {
  const env = Deno.env.get('MAPS_SERVER_KEY');
  if (env) return env;
  const { data } = await sb.from('app_secrets').select('value').eq('name', 'maps_server_key').maybeSingle();
  return (data?.value as string) ?? null;
}

async function geocode(address: string, key: string): Promise<{ lat: number; lng: number } | null> {
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${key}`;
  const r = await fetch(url);
  const d = await r.json();
  const loc = d?.results?.[0]?.geometry?.location;
  return loc ? { lat: loc.lat, lng: loc.lng } : null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);

  let token = '';
  try {
    const body = await req.json();
    token = String(body?.token ?? '');
  } catch {
    return json({ ok: false, error: 'bad_json' }, 400);
  }
  if (!token || token.length < 16) return json({ ok: true, live: false });

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);

  const { data: appt } = await sb
    .from('bath_appointments')
    .select('id, status, subscriber_id, scheduled_end')
    .eq('tracker_token', token)
    .maybeSingle();
  if (!appt) return json({ ok: true, live: false });
  if (appt.scheduled_end && Date.now() > new Date(appt.scheduled_end).getTime() + 7 * 86400_000) {
    return json({ ok: true, live: false, reason: 'expired' });
  }
  if (appt.status !== 'on_the_way') return json({ ok: true, live: false, reason: 'not_en_route' });

  const { data: fix } = await sb
    .from('tracker_locations')
    .select('*')
    .eq('appointment_id', appt.id)
    .maybeSingle();
  if (!fix) return json({ ok: true, live: false, reason: 'no_fix' });

  const fixAge = Math.round((Date.now() - new Date(fix.recorded_at).getTime()) / 1000);
  if (fixAge > STALE_FIX_SECONDS) {
    return json({ ok: true, live: false, reason: 'stale_fix', fix_age_seconds: fixAge });
  }

  // Destination: the client's own address. Subscriber coordinates first
  // (funnel bookings), then the legacy client record, then a one-time
  // geocode persisted back so it never costs twice.
  const { data: sub } = await sb
    .from('bath_subscribers')
    .select('service_lat, service_lng, client_id')
    .eq('id', appt.subscriber_id)
    .maybeSingle();

  let dest: { lat: number; lng: number } | null =
    sub?.service_lat != null && sub?.service_lng != null
      ? { lat: Number(sub.service_lat), lng: Number(sub.service_lng) }
      : null;

  if (!dest && sub?.client_id) {
    const { data: cl } = await sb
      .from('clients')
      .select('id, geo_lat, geo_lng, location_address, location_plus')
      .eq('id', sub.client_id)
      .maybeSingle();
    // Plus code first: it is the precise pin Paul kept per client, while a
    // few address fields are placeholders that geocode to a city centroid.
    const geoQuery = cl?.location_plus
      ? (cl.location_plus.includes(',') ? cl.location_plus : `${cl.location_plus} Ocala, FL`)
      : cl?.location_address;
    if (cl?.geo_lat != null && cl?.geo_lng != null) {
      dest = { lat: Number(cl.geo_lat), lng: Number(cl.geo_lng) };
    } else if (geoQuery) {
      const key = await getMapsKey(sb);
      if (key) {
        const g = await geocode(geoQuery, key);
        if (g) {
          dest = g;
          await sb.from('clients').update({ geo_lat: g.lat, geo_lng: g.lng }).eq('id', cl.id);
        }
      }
    }
  }
  if (!dest) {
    return json({
      ok: true, live: true, eta_minutes: null, fix_age_seconds: fixAge,
      operator: { lat: Number(fix.lat), lng: Number(fix.lng) }, dest: null,
    });
  }

  // ETA, cached on the row.
  let etaSeconds: number | null = fix.eta_seconds;
  const cacheAge = fix.eta_computed_at
    ? (Date.now() - new Date(fix.eta_computed_at).getTime()) / 1000
    : Infinity;
  const moved = fix.eta_lat == null || fix.eta_lng == null ||
    Math.abs(Number(fix.lat) - Number(fix.eta_lat)) > MOVE_RECOMPUTE_DEG ||
    Math.abs(Number(fix.lng) - Number(fix.eta_lng)) > MOVE_RECOMPUTE_DEG;

  if (etaSeconds == null || cacheAge > ETA_CACHE_SECONDS || moved) {
    const key = await getMapsKey(sb);
    if (key) {
      const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${fix.lat},${fix.lng}` +
        `&destinations=${dest.lat},${dest.lng}&mode=driving&departure_time=now&key=${key}`;
      try {
        const r = await fetch(url);
        const d = await r.json();
        const el = d?.rows?.[0]?.elements?.[0];
        const dur = el?.duration_in_traffic?.value ?? el?.duration?.value;
        if (el?.status === 'OK' && dur != null) {
          etaSeconds = dur;
          await sb.from('tracker_locations').update({
            eta_seconds: etaSeconds,
            eta_computed_at: new Date().toISOString(),
            eta_lat: fix.lat,
            eta_lng: fix.lng,
          }).eq('appointment_id', appt.id);
        }
      } catch { /* keep the cached value; the map still moves */ }
    }
  }

  return json({
    ok: true,
    live: true,
    eta_minutes: etaSeconds != null ? Math.max(1, Math.round(etaSeconds / 60)) : null,
    fix_age_seconds: fixAge,
    operator: { lat: Number(fix.lat), lng: Number(fix.lng) },
    dest,
  });
});
