// supabase/functions/ocala-service-area/index.ts
//
// Drive-time service-area gate for new Ocala bath signups. Given a prospective
// client's address (or coordinates), returns whether they are within N minutes'
// DRIVE of an existing client (an "anchor"). Drive time is REAL, from Google
// Distance Matrix, not straight-line distance. Anchor addresses are sent to
// Google server-side and never returned to the caller; the response is only
// { within, minutes }.
//
// Anchor locations are fed to Distance Matrix as addresses, which Google
// geocodes internally, so no separate Geocoding API is needed. If an anchor ever
// has cached coordinates (geo_lat/geo_lng) they are used in preference to the
// address as a faster, cheaper input.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const DEFAULT_THRESHOLD_MIN = 15;

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

// The Google key lives in a server-only table (app_secrets), readable only by
// the service role, because this environment has no tool to set a function env
// secret. Env var still wins if one is ever set.
async function getMapsKey(sb: ReturnType<typeof createClient>): Promise<string | null> {
  const env = Deno.env.get('MAPS_SERVER_KEY');
  if (env) return env;
  const { data } = await sb.from('app_secrets').select('value').eq('name', 'maps_server_key').maybeSingle();
  return (data?.value as string) ?? null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);

  let body: { address?: string; lat?: number; lng?: number; max_minutes?: number };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: 'bad_json' }, 400);
  }

  // Origin can be a typed service address or coordinates; Distance Matrix takes either.
  let origin = '';
  if (typeof body.address === 'string' && body.address.trim().length > 3) {
    origin = body.address.trim();
  } else if (typeof body.lat === 'number' && typeof body.lng === 'number') {
    origin = `${body.lat},${body.lng}`;
  } else {
    return json({ ok: false, error: 'bad_input' }, 400);
  }
  const limit = Number(body.max_minutes) > 0 ? Number(body.max_minutes) : DEFAULT_THRESHOLD_MIN;

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);

  const key = await getMapsKey(sb);
  if (!key) return json({ ok: false, error: 'maps_not_configured' }, 503);

  const { data: anchors, error } = await sb
    .from('clients')
    .select('id, location_address, geo_lat, geo_lng')
    .eq('is_anchor', true);
  if (error) return json({ ok: false, error: 'db' }, 500);

  const dests = (anchors ?? [])
    .map((a) =>
      a.geo_lat != null && a.geo_lng != null
        ? `${a.geo_lat},${a.geo_lng}`
        : (a.location_address ?? '').trim(),
    )
    .filter((d) => d.length > 3);
  if (dests.length === 0) return json({ ok: true, within: false, minutes: null, anchor_count: 0, resolved: 0 });

  // Distance Matrix allows up to 25 destinations per origin per request.
  let bestSeconds = Infinity;
  let resolved = 0;
  for (let i = 0; i < dests.length; i += 25) {
    const chunk = dests.slice(i, i + 25);
    const destParam = chunk.map(encodeURIComponent).join('|');
    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${encodeURIComponent(origin)}` +
      `&destinations=${destParam}&mode=driving&units=imperial&key=${key}`;
    const r = await fetch(url);
    const d = await r.json();
    const els = d?.rows?.[0]?.elements ?? [];
    for (const e of els) {
      if (e?.status === 'OK' && e?.duration?.value != null) {
        resolved++;
        bestSeconds = Math.min(bestSeconds, e.duration.value);
      }
    }
  }

  if (!isFinite(bestSeconds)) {
    return json({ ok: true, within: false, minutes: null, anchor_count: dests.length, resolved: 0 });
  }
  const minutes = Math.round(bestSeconds / 60);
  return json({ ok: true, within: minutes <= limit, minutes, anchor_count: dests.length, resolved });
});
