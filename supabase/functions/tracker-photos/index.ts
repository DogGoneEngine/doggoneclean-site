// supabase/functions/tracker-photos/index.ts
//
// The Dog Gone Tracker's photo feed (pizza_tracker_client_loop). A tracker
// visitor holds only the appointment's tracker_token (an SMS recipient is
// not logged into anything), so storage RLS cannot authorize them; this
// function bridges the gap server-side: token -> that appointment's visit ->
// its client_visible photos -> short-lived signed URLs. Only photos Paul
// deliberately shared (visit_photos.client_visible, the Orbit Share toggle)
// ever leave, and only for the one visit the token belongs to.
//
// operator_photo: the pilot-in-command operator's own profile photo, used for
// BOTH the header face and the big "who's coming" portrait, so the face always
// matches the name. (Earlier this scraped the latest with-dog photo, which
// could be a trainee, and put the wrong face on the card. Fixed 2026-06-13.)
//
// Each returned photo carries `by`, the first name of whoever actually took it
// (visit_photos.taken_by_admin_id, the logged-in admin), so Jake's shot reads
// "Jake and Manning" even on a visit Paul is running.

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
    .select('id, scheduled_end, subscriber_id, operator_admin_id')
    .eq('tracker_token', token)
    .maybeSingle();
  if (!appt) return json({ photos: [] });
  // Link lifetime matches tracker_status: 7 days past the scheduled end the
  // link goes quiet; the photos live on in the client's portal.
  if (appt.scheduled_end && Date.now() > new Date(appt.scheduled_end).getTime() + 7 * 86400_000) {
    return json({ photos: [] });
  }

  // The operator's own profile photo (admins.photo_path, set from HR), so
  // the header face matches the human actually rolling up. Owner is the
  // default when no operator is assigned.
  let operatorPhoto: string | null = null;
  {
    const { data: op } = await sb
      .from('admins')
      .select('photo_path, role, id')
      .or(appt.operator_admin_id ? `id.eq.${appt.operator_admin_id}` : 'role.eq.owner')
      .limit(1)
      .maybeSingle();
    if (op?.photo_path) {
      const { data: signed } = await sb.storage
        .from('visit-photos')
        .createSignedUrl(op.photo_path, SIGNED_URL_SECONDS);
      operatorPhoto = signed?.signedUrl ?? null;
    }
  }

  const { data: visits } = await sb
    .from('visits')
    .select('id')
    .eq('appointment_id', appt.id);
  const visitIds = (visits ?? []).map((v) => v.id);
  if (visitIds.length === 0) return json({ photos: [], operator_photo: operatorPhoto });

  const { data: photos } = await sb
    .from('visit_photos')
    .select('id, kind, storage_path, created_at, dog_id, answers_request, taken_by_admin_id, dogs(name)')
    .in('visit_id', visitIds)
    .eq('client_visible', true)
    .order('created_at', { ascending: true });
  if (!photos || photos.length === 0) return json({ photos: [], operator_photo: operatorPhoto });

  // First name of whoever took each photo, resolved in one lookup so a shot
  // reads as its real photographer rather than the pilot in command.
  const takerIds = [...new Set(photos.map((p) => (p as any).taken_by_admin_id).filter(Boolean))];
  const byName: Record<string, string> = {};
  if (takerIds.length > 0) {
    const { data: takers } = await sb
      .from('admins')
      .select('id, first_name')
      .in('id', takerIds);
    for (const t of takers ?? []) byName[(t as any).id] = (t as any).first_name;
  }

  const out: { id: string; kind: string; url: string; dog_name: string | null; answers_request: boolean; by: string | null }[] = [];
  for (const p of photos) {
    const { data: signed } = await sb.storage
      .from('visit-photos')
      .createSignedUrl(p.storage_path, SIGNED_URL_SECONDS);
    if (signed?.signedUrl) {
      const takerId = (p as any).taken_by_admin_id;
      out.push({ id: p.id, kind: p.kind, url: signed.signedUrl, dog_name: (p as any).dogs?.name ?? null, answers_request: !!(p as any).answers_request, by: takerId ? (byName[takerId] ?? null) : null });
    }
  }
  return json({ photos: out, operator_photo: operatorPhoto });
});
