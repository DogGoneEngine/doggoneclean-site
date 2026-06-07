// supabase/functions/ocala-service-area/index.ts
//
// Drive-time service-area gate for new Ocala bath signups. Given a prospective
// client's coordinates, returns whether they are within N minutes' DRIVE of an
// existing client (an "anchor"), so a new stop only gets taken if it fits a day
// Paul is already nearby (ocala_service_area_by_anchor). Drive time is REAL,
// from Google Distance Matrix, not straight-line distance.
//
// Privacy: anchors are real client homes. Their addresses and coordinates never
// leave the server; the response is only { within, minutes } (no anchor identity).
//
// Required secrets/env:
//   MAPS_SERVER_KEY           a Google Maps key with the Distance Matrix API and
//                             Geocoding API enabled (server key; not the browser
//                             key, which is locked to Maps JS + Places). Its own
//                             Clean Google Cloud project, never DGN's.
//   SUPABASE_URL              (provided to edge functions by default)
//   SUPABASE_SERVICE_ROLE_KEY (provided to edge functions by default)

import { createClient } from 'jsr:@supabase/supabase-js@2';

const MAPS_KEY = Deno.env.get('MAPS_SERVER_KEY');
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

async function geocode(address: string): Promise<{ lat: number; lng: number } | null> {
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${MAPS_KEY}`;
  const r = await fetch(url);
  const d = await r.json();
  const loc = d?.results?.[0]?.geometry?.location;
  return loc ? { lat: loc.lat, lng: loc.lng } : null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ ok: false, error: 'method' }, 405);

  // The gate cannot work until the drive-time key exists. Fail closed, loudly,
  // rather than guess.
  if (!MAPS_KEY) return json({ ok: false, error: 'maps_not_configured' }, 503);

  let body: { lat?: number; lng?: number; max_minutes?: number };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: 'bad_json' }, 400);
  }
  const { lat, lng } = body;
  if (typeof lat !== 'number' || typeof lng !== 'number') {
    return json({ ok: false, error: 'bad_input' }, 400);
  }
  const limit = Number(body.max_minutes) > 0 ? Number(body.max_minutes) : DEFAULT_THRESHOLD_MIN;

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);

  const { data: anchors, error } = await sb
    .from('clients')
    .select('id, location_address, location_zip, geo_lat, geo_lng')
    .eq('is_anchor', true);
  if (error) return json({ ok: false, error: 'db' }, 500);

  // Lazily geocode + cache any anchor missing coordinates.
  for (const a of anchors ?? []) {
    if (a.geo_lat == null || a.geo_lng == null) {
      const addr = a.location_address || (a.location_zip ? `Ocala FL ${a.location_zip}` : null);
      if (!addr) continue;
      const g = await geocode(addr);
      if (g) {
        a.geo_lat = g.lat;
        a.geo_lng = g.lng;
        await sb.from('clients').update({ geo_lat: g.lat, geo_lng: g.lng }).eq('id', a.id);
      }
    }
  }

  // Cheap bounding-box prefilter (~25 mi) so Distance Matrix only prices the
  // anchors that could plausibly be within range. The gate itself is drive time.
  const near = (anchors ?? []).filter(
    (a) => a.geo_lat != null && a.geo_lng != null &&
      Math.abs(a.geo_lat - lat) < 0.45 && Math.abs(a.geo_lng - lng) < 0.45,
  );
  if (near.length === 0) return json({ ok: true, within: false, minutes: null, anchor_count: 0 });

  // Distance Matrix allows up to 25 destinations per request with one origin.
  let bestSeconds = Infinity;
  for (let i = 0; i < near.length; i += 25) {
    const chunk = near.slice(i, i + 25);
    const dest = chunk.map((a) => `${a.geo_lat},${a.geo_lng}`).join('|');
    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${lat},${lng}` +
      `&destinations=${encodeURIComponent(dest)}&mode=driving&units=imperial&key=${MAPS_KEY}`;
    const r = await fetch(url);
    const d = await r.json();
    const els = d?.rows?.[0]?.elements ?? [];
    for (const e of els) {
      if (e?.status === 'OK' && e?.duration?.value != null) {
        bestSeconds = Math.min(bestSeconds, e.duration.value);
      }
    }
  }

  if (!isFinite(bestSeconds)) {
    return json({ ok: true, within: false, minutes: null, anchor_count: near.length });
  }
  const minutes = Math.round(bestSeconds / 60);
  return json({ ok: true, within: minutes <= limit, minutes, anchor_count: near.length });
});
