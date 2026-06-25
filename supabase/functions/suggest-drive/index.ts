import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// Suggest-drive: admin_suggest_slots plus real drive times. For every suggested
// slot it answers the question Paul routes on: how long is the drive from the
// stop before it and to the stop after it. Two honesty rules from the field
// (2026-06-11): a neighbor only counts when the slot is actually ADJACENT to it
// (within 100 minutes of idle); a stop hours earlier in the day is not "15 min
// away" in any useful sense, so it shows nothing. And within each day the slots
// are ordered tightest-fit first (least added drive), with the best one flagged,
// which is the first slice of String of Pearls thinking in the booking panel.
// Pairs of client homes never move, so computed drive seconds are cached forever
// in drive_cache; Distance Matrix is only paid for a pair's first time. Missing
// coordinates are geocoded from the client's plus code (preferred) or address
// and persisted back. Auth: calls admin_suggest_slots with the caller's own JWT,
// which raises for non-admins (same pattern as riker).

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ADJ_MS = 100 * 60000; // a neighbor more idle-distant than this is irrelevant

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...CORS } });

async function svc(path: string, init: RequestInit = {}) {
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json", apikey: SERVICE_ROLE,
      Authorization: `Bearer ${SERVICE_ROLE}`, ...(init.headers ?? {}),
    },
  });
  if (!res.ok) throw new Error(`${path} ${res.status}: ${await res.text()}`);
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

type Pt = { lat: number; lng: number };
type Stop = { client_id: string; name: string | null; pt: Pt | null;
              plus: string | null; address: string | null; start: number; end: number };

function coordsOf(sub: any): Pt | null {
  if (sub?.service_lat != null && sub?.service_lng != null) return { lat: Number(sub.service_lat), lng: Number(sub.service_lng) };
  const c = sub?.client;
  if (c?.geo_lat != null && c?.geo_lng != null) return { lat: Number(c.geo_lat), lng: Number(c.geo_lng) };
  return null;
}

let _mapsKey: string | null | undefined;
async function mapsKey(): Promise<string | null> {
  if (_mapsKey !== undefined) return _mapsKey;
  const rows = await svc(`/rest/v1/app_secrets?name=eq.maps_server_key&select=value`, { method: "GET" });
  _mapsKey = rows?.[0]?.value ?? null;
  return _mapsKey;
}

// Geocode a client's home, plus code first (it is the precise pin Paul kept;
// some address fields are placeholders), persist so it never costs twice.
async function geocodeClient(clientId: string, plus: string | null, address: string | null): Promise<Pt | null> {
  const key = await mapsKey();
  if (!key) return null;
  const q = plus ? (plus.includes(",") ? plus : `${plus} Ocala, FL`) : address;
  if (!q) return null;
  try {
    const r = await (await fetch(`https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(q)}&key=${key}`)).json();
    const loc = r?.results?.[0]?.geometry?.location;
    if (loc?.lat == null) return null;
    const pt = { lat: loc.lat, lng: loc.lng };
    await svc(`/rest/v1/clients?id=eq.${clientId}`, {
      method: "PATCH", headers: { Prefer: "return=minimal" },
      body: JSON.stringify({ geo_lat: pt.lat, geo_lng: pt.lng }),
    }).catch(() => {});
    return pt;
  } catch (_) { return null; }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const auth = req.headers.get("Authorization") || "";
    if (!auth) return json({ ok: false, error: "unauthorized" }, 401);
    const { client_id, dog_ids } = await req.json();
    if (!client_id) return json({ ok: false, error: "no client" }, 400);

    // 1. Suggestions, authorized as the caller (raises for non-admins). The dogs
    // going (dog_ids) size the block, so the suggested open times shrink when a
    // dog is left off (a subset; null means the whole roster).
    const sugRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_suggest_slots`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON, Authorization: auth },
      body: JSON.stringify({ p_client_id: client_id, p_dog_ids: dog_ids ?? null }),
    });
    if (!sugRes.ok) return json({ ok: false, error: "not authorized" }, 403);
    const sug = await sugRes.json();
    const days: any[] = Array.isArray(sug?.days) ? sug.days : [];
    if (days.length === 0) return json({ ok: true, suggestions: sug });

    // 2. Target client's home (geocode from plus code or address if missing).
    const subs = await svc(`/rest/v1/bath_subscribers?client_id=eq.${client_id}&select=service_lat,service_lng,client:clients(geo_lat,geo_lng,location_plus,location_address)&limit=1`, { method: "GET" });
    let target: Pt | null = coordsOf(subs?.[0]);
    if (!target) {
      target = await geocodeClient(client_id, subs?.[0]?.client?.location_plus ?? null, subs?.[0]?.client?.location_address ?? null);
    }
    if (!target) return json({ ok: true, suggestions: sug, drive: false, reason: "no coordinates for this client yet" });

    // 3. Every booked stop across the suggested dates, with coordinates.
    const dates = days.map((d) => d.date).sort();
    const fromIso = `${dates[0]}T00:00:00-05:00`;
    const toIso = `${dates[dates.length - 1]}T23:59:59-04:00`;
    const appts = await svc(
      `/rest/v1/bath_appointments?select=scheduled_start,scheduled_end,duration_minutes,` +
      `subscriber:bath_subscribers(client_id,service_lat,service_lng,client:clients(name,geo_lat,geo_lng,location_plus,location_address))` +
      `&scheduled_start=gte.${encodeURIComponent(fromIso)}&scheduled_start=lte.${encodeURIComponent(toIso)}` +
      `&status=not.in.(cancelled,no_show,skipped)&order=scheduled_start`, { method: "GET" });
    const stops: Stop[] = (appts ?? [])
      .filter((a: any) => a?.subscriber?.client_id && a.subscriber.client_id !== client_id)
      .map((a: any) => ({
        client_id: a.subscriber.client_id,
        name: a.subscriber.client?.name ?? null,
        pt: coordsOf(a.subscriber),
        plus: a.subscriber.client?.location_plus ?? null,
        address: a.subscriber.client?.location_address ?? null,
        start: Date.parse(a.scheduled_start),
        end: a.scheduled_end ? Date.parse(a.scheduled_end) : Date.parse(a.scheduled_start) + (a.duration_minutes ?? 60) * 60000,
      }));

    const durMs = (sug?.duration_minutes ?? 60) * 60000;

    // 4. Adjacent neighbors per slot (a far-away neighbor is no neighbor).
    const slotNeeds = new Map<string, { prev: Stop | null; next: Stop | null }>();
    for (const day of days) {
      for (const s of day.slots ?? []) {
        const start = typeof s === "string" ? s : s.start;
        const t = Date.parse(start);
        const dayStops = stops.filter((x) => new Date(x.start).toDateString() === new Date(t).toDateString());
        let prev: Stop | null = null, next: Stop | null = null;
        for (const x of dayStops) {
          if (x.end <= t && t - x.end <= ADJ_MS && (!prev || x.end > prev.end)) prev = x;
          if (x.start >= t + durMs && x.start - (t + durMs) <= ADJ_MS && (!next || x.start < next.start)) next = x;
        }
        slotNeeds.set(`${start}`, { prev, next });
      }
    }

    // 5. Fill in any neighbor still missing coordinates (plus code geocode).
    const needCoords = new Map<string, Stop>();
    for (const { prev, next } of slotNeeds.values()) {
      if (prev && !prev.pt) needCoords.set(prev.client_id, prev);
      if (next && !next.pt) needCoords.set(next.client_id, next);
    }
    for (const stop of needCoords.values()) {
      const pt = await geocodeClient(stop.client_id, stop.plus, stop.address);
      if (pt) for (const x of stops) if (x.client_id === stop.client_id) x.pt = pt;
    }

    // 6. Resolve drive seconds: cache first, Distance Matrix for the misses.
    const pairKeys = new Set<string>();
    for (const { prev, next } of slotNeeds.values()) {
      if (prev?.pt) pairKeys.add(`${prev.client_id}|${client_id}`);
      if (next?.pt) pairKeys.add(`${client_id}|${next.client_id}`);
    }
    const seconds = new Map<string, number>();
    if (pairKeys.size > 0) {
      const origins = [...new Set([...pairKeys].map((k) => k.split("|")[0]))];
      const cached = await svc(
        `/rest/v1/drive_cache?select=origin_client,dest_client,seconds&origin_client=in.(${origins.join(",")})`, { method: "GET" });
      for (const row of cached ?? []) seconds.set(`${row.origin_client}|${row.dest_client}`, row.seconds);

      const missing = [...pairKeys].filter((k) => !seconds.has(k));
      if (missing.length > 0) {
        const key = await mapsKey();
        if (key) {
          const ptOf = (cid: string): Pt | null => {
            if (cid === client_id) return target;
            const s = stops.find((x) => x.client_id === cid && x.pt);
            return s?.pt ?? null;
          };
          const inserts: any[] = [];
          for (const k of missing) {
            const [o, d] = k.split("|");
            const op = ptOf(o), dp = ptOf(d);
            if (!op || !dp) continue;
            const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${op.lat},${op.lng}&destinations=${dp.lat},${dp.lng}&key=${key}`;
            try {
              const r = await (await fetch(url)).json();
              const el = r?.rows?.[0]?.elements?.[0];
              if (el?.status === "OK" && el?.duration?.value != null) {
                seconds.set(k, el.duration.value);
                inserts.push({ origin_client: o, dest_client: d, seconds: el.duration.value });
              }
            } catch (_) { /* one bad pair never sinks the rest */ }
          }
          if (inserts.length > 0) {
            await svc(`/rest/v1/drive_cache`, {
              method: "POST",
              headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
              body: JSON.stringify(inserts),
            }).catch(() => {});
          }
        }
      }
    }

    // 7. Re-emit each day with annotated slots, tightest fit first. Each
    // neighbor carries both the drive between homes (constant) and the wait the
    // slot creates (varies by slot time): idle after arriving from the previous
    // stop, and slack before you would have to leave for the next one.
    const outDays = days.map((day) => {
      const annotated = (day.slots ?? []).map((s: any) => {
        const start = typeof s === "string" ? s : s.start;
        const t = Date.parse(start);
        const n = slotNeeds.get(`${start}`);
        const prevSec = n?.prev ? seconds.get(`${n.prev.client_id}|${client_id}`) : undefined;
        const nextSec = n?.next ? seconds.get(`${client_id}|${n.next.client_id}`) : undefined;
        const fit = (prevSec != null ? prevSec : 0) + (nextSec != null ? nextSec : 0);
        // Wait after the previous stop: slot start minus (their end + the drive).
        const prevWait = (n?.prev && prevSec != null)
          ? Math.max(0, Math.round((t - (n.prev.end + prevSec * 1000)) / 60000)) : null;
        // Slack before the next stop: their start minus (this slot's end + the drive).
        const nextWait = (n?.next && nextSec != null)
          ? Math.max(0, Math.round((n.next.start - (t + durMs + nextSec * 1000)) / 60000)) : null;
        return {
          start,
          prev_stop: n?.prev ? { client: n.prev.name, drive_minutes: prevSec != null ? Math.round(prevSec / 60) : null, wait_minutes: prevWait } : null,
          next_stop: n?.next ? { client: n.next.name, drive_minutes: nextSec != null ? Math.round(nextSec / 60) : null, wait_minutes: nextWait } : null,
          _fit: (prevSec != null || nextSec != null) ? fit : Infinity,
        };
      });
      annotated.sort((a: any, b: any) => a._fit !== b._fit ? a._fit - b._fit : Date.parse(a.start) - Date.parse(b.start));
      if (annotated.length > 0 && annotated[0]._fit !== Infinity) annotated[0].tightest = true;
      for (const a of annotated) delete a._fit;
      return { ...day, slots: annotated };
    });

    return json({ ok: true, suggestions: { ...sug, days: outDays }, drive: true });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
