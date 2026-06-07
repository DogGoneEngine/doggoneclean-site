// supabase/functions/ocala-service-area/index.ts
//
// Service-area gate for new Ocala bath signups. A prospective service address
// qualifies only if it passes BOTH checks (ocala_service_area_by_anchor):
//   1. INSIDE the frozen containment perimeter Paul drew (service_perimeters),
//      the hard cap that stops edge clients from breadcrumbing the area outward;
//   2. within N minutes' real DRIVE of an existing client (an "anchor"), from
//      Google Distance Matrix, which keeps every stop efficient.
//
// The address is geocoded server-side; anchor coordinates and the drive math
// never leave the server. The response is only { within, in_area, minutes }.

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

async function geocode(address: string, key: string): Promise<{ lat: number; lng: number } | null> {
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${key}`;
  const r = await fetch(url);
  const d = await r.json();
  const loc = d?.results?.[0]?.geometry?.location;
  return loc ? { lat: loc.lat, lng: loc.lng } : null;
}

// Ray-casting point-in-polygon. ring is GeoJSON [[lng,lat], ...].
function pointInRing(lng: number, lat: number, ring: number[][]): boolean {
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const xi = ring[i][0], yi = ring[i][1];
    const xj = ring[j][0], yj = ring[j][1];
    const intersect = (yi > lat) !== (yj > lat) &&
      lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);

  let body: { address?: string; lat?: number; lng?: number; max_minutes?: number; area?: string };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: 'bad_json' }, 400);
  }
  const limit = Number(body.max_minutes) > 0 ? Number(body.max_minutes) : DEFAULT_THRESHOLD_MIN;
  const area = (typeof body.area === 'string' && body.area.trim()) ? body.area.trim() : 'ocala';

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);

  const key = await getMapsKey(sb);
  if (!key) return json({ ok: false, error: 'maps_not_configured' }, 503);

  // Resolve the prospect to coordinates (geocode a typed address; Geocoding is enabled).
  let lat: number, lng: number;
  if (typeof body.lat === 'number' && typeof body.lng === 'number') {
    lat = body.lat; lng = body.lng;
  } else if (typeof body.address === 'string' && body.address.trim().length > 3) {
    const g = await geocode(body.address.trim(), key);
    if (!g) return json({ ok: true, within: false, in_area: false, minutes: null, reason: 'address_not_found' });
    lat = g.lat; lng = g.lng;
  } else {
    return json({ ok: false, error: 'bad_input' }, 400);
  }

  // Check 1: inside the frozen perimeter. No perimeter row = no fence (drive-time only).
  const { data: perim } = await sb.from('service_perimeters').select('polygon').eq('slug', area).maybeSingle();
  const ring = (perim?.polygon as number[][][] | undefined)?.[0];
  if (Array.isArray(ring) && ring.length > 2 && !pointInRing(lng, lat, ring)) {
    return json({ ok: true, within: false, in_area: false, minutes: null });
  }

  // Check 2: within the drive-time threshold of an anchor.
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
  if (dests.length === 0) return json({ ok: true, within: false, in_area: true, minutes: null, anchor_count: 0, resolved: 0 });

  const origin = `${lat},${lng}`;
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
    return json({ ok: true, within: false, in_area: true, minutes: null, anchor_count: dests.length, resolved: 0 });
  }
  const minutes = Math.round(bestSeconds / 60);
  return json({ ok: true, within: minutes <= limit, in_area: true, minutes, anchor_count: dests.length, resolved });
});
