// supabase/functions/tracker-photos/index.ts
//
// The Dog Gone Tracker's photo feed (pizza_tracker_client_loop). A tracker
// visitor holds only the appointment's tracker_token (an SMS recipient is
// not logged into anything), so storage RLS cannot authorize them; this
// function bridges the gap server-side: token -> that appointment's visit ->
// its client_visible photos -> short-lived signed URLs. Only photos Paul
// deliberately shared (visit_photos.client_visible, the Orbit Share toggle)
// ever leave, and only for the one visit the token belongs to.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SIGNED_URL_SECONDS = 3600;

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  let token = '';
  try {
    const body = await req.json();
    token = String(body?.token ?? '');
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  if (!token || token.length < 16) return json({ photos: [] });

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);

  const { data: appt } = await sb
    .from('bath_appointments')
    .select('id, scheduled_end')
    .eq('tracker_token', token)
    .maybeSingle();
  if (!appt) return json({ photos: [] });
  // Link lifetime matches tracker_status: 7 days past the scheduled end the
  // link goes quiet; the photos live on in the client's portal.
  if (appt.scheduled_end && Date.now() > new Date(appt.scheduled_end).getTime() + 7 * 86400_000) {
    return json({ photos: [] });
  }

  const { data: visits } = await sb
    .from('visits')
    .select('id')
    .eq('appointment_id', appt.id);
  const visitIds = (visits ?? []).map((v) => v.id);
  if (visitIds.length === 0) return json({ photos: [] });

  const { data: photos } = await sb
    .from('visit_photos')
    .select('id, kind, storage_path, created_at, dog_id, dogs(name)')
    .in('visit_id', visitIds)
    .eq('client_visible', true)
    .order('created_at', { ascending: true });
  if (!photos || photos.length === 0) return json({ photos: [] });

  const out: { id: string; kind: string; url: string; dog_name: string | null }[] = [];
  for (const p of photos) {
    const { data: signed } = await sb.storage
      .from('visit-photos')
      .createSignedUrl(p.storage_path, SIGNED_URL_SECONDS);
    if (signed?.signedUrl) {
      out.push({ id: p.id, kind: p.kind, url: signed.signedUrl, dog_name: (p as any).dogs?.name ?? null });
    }
  }
  return json({ photos: out });
});
