// src/components/admin/VisitPhotos.jsx
//
// Photos on a visit: before, after, you-with-the-dog, plus extras. Pick straight
// from the phone (the Android picker reaches Google Photos), upload to the private
// visit-photos bucket, view through short-lived signed URLs. accept="image/*" with
// no capture, so the gallery is offered, not just the camera. See visit_photos_capture.

import { useState, useEffect, useCallback } from 'react';
import { uploadVisitPhoto, signedPhotoUrl, deleteVisitPhoto, setPhotoVisibility, setPhotoDog, adminSelf } from './supabase.js';

// "With dog" reads wrong; the photo is the dog WITH the person running the
// appointment, so the label carries the operator's name (today: Paul; when
// routes have operators this reads from the route's operator).
let _operatorName = null;
function useOperatorName() {
  const [name, setName] = useState(_operatorName);
  useEffect(() => {
    if (_operatorName) return;
    adminSelf().then((a) => { _operatorName = a?.first_name || 'me'; setName(_operatorName); }).catch(() => {});
  }, []);
  return name || 'me';
}
const kindLabels = (op) => ({ before: 'Before', after: 'After', with_dog: `With ${op}`, extra: 'Extra' });

export default function VisitPhotos({ visitId, clientId, photos = [], dogs = [], onChanged }) {
  const [urls, setUrls] = useState({});
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState(0);
  const [error, setError] = useState(null);
  const operator = useOperatorName();
  const KIND_LABEL = kindLabels(operator);
  const SLOTS = [['before', 'Before'], ['after', 'After'], ['with_dog', `With ${operator}`]];
  // Which dog the next uploads are of. Only surfaces for multi-dog
  // households; null means untagged (a whole-pack or scene shot is real).
  const [tagDog, setTagDog] = useState(null);
  const multiDog = (dogs || []).length > 1;

  useEffect(() => {
    let alive = true;
    (async () => {
      const entries = await Promise.all(photos.map(async (p) => {
        try { return [p.id, await signedPhotoUrl(p.path)]; } catch { return [p.id, null]; }
      }));
      if (alive) setUrls(Object.fromEntries(entries));
    })();
    return () => { alive = false; };
  }, [photos]);

  // Fire-and-track: a pick starts uploading in the background and the next
  // pick is available immediately (Paul should never sit watching a spinner
  // between the after shot and the with-him shot). Each finished upload
  // refreshes the sheet; failures surface without blocking the rest.
  const onPick = useCallback((kind, files) => {
    if (!files || !files.length) return;
    setError(null);
    const dog = tagDog;
    for (const f of Array.from(files)) {
      setPending((n) => n + 1);
      uploadVisitPhoto(visitId, clientId, kind, f, dog)
        .then(() => onChanged?.())
        .catch((e) => setError(e.message || 'upload_failed'))
        .finally(() => setPending((n) => n - 1));
    }
  }, [visitId, clientId, tagDog, onChanged]);

  // Tap the label to cycle which dog a photo shows: none -> dog 1 -> dog 2
  // -> ... -> none. Cheap retro-tagging that fits a 64px thumbnail.
  async function cycleDog(p) {
    if (!multiDog && (dogs || []).length === 0) return;
    const ids = (dogs || []).map((d) => d.id);
    const at = p.dog_id ? ids.indexOf(p.dog_id) : -1;
    const next = at + 1 >= ids.length ? null : ids[at + 1];
    setBusy(true); setError(null);
    try { await setPhotoDog(p.id, next); onChanged?.(); }
    catch (e) { setError(e.message || 'tag_failed'); }
    finally { setBusy(false); }
  }
  function photoLabel(p) {
    const kind = KIND_LABEL[p.kind] || 'Photo';
    return p.dog_name ? `${kind} \u00b7 ${p.dog_name}` : kind;
  }

  async function remove(p) {
    setBusy(true); setError(null);
    try { await deleteVisitPhoto(p.id, p.path); onChanged?.(); }
    catch (e) { setError(e.message || 'delete_failed'); }
    finally { setBusy(false); }
  }

  // Sharing is per photo and deliberate: a shared photo shows in the
  // client's portal (later the Dog Gone Tracker too). Optimistic toggle.
  const [shared, setShared] = useState({});
  useEffect(() => {
    setShared(Object.fromEntries(photos.map((p) => [p.id, !!p.client_visible])));
  }, [photos]);
  async function toggleShare(p) {
    const next = !shared[p.id];
    setShared((s) => ({ ...s, [p.id]: next }));
    setError(null);
    try { await setPhotoVisibility(p.id, next); }
    catch (e) { setShared((s) => ({ ...s, [p.id]: !next })); setError(e.message || 'share_failed'); }
  }

  return (
    <div style={{ marginTop: 6 }}>
      {photos.length > 0 && (
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 6 }}>
          {photos.map((p) => (
            <div key={p.id} style={{ width: 64 }}>
              <div style={{ position: 'relative' }}>
                <a href={urls[p.id] || undefined} target="_blank" rel="noreferrer" title={KIND_LABEL[p.kind]}>
                  <div style={{ width: 64, height: 64, borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f1f1f4)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    {urls[p.id]
                      ? <img src={urls[p.id]} alt={KIND_LABEL[p.kind]} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      : <span style={{ fontSize: 10, opacity: 0.5 }}>…</span>}
                  </div>
                </a>
                <span
                  onClick={(dogs || []).length > 0 ? () => cycleDog(p) : undefined}
                  title={(dogs || []).length > 0 ? 'tap to tag which dog this is' : undefined}
                  style={{ position: 'absolute', bottom: 0, left: 0, right: 0, fontSize: 9, textAlign: 'center', background: 'rgba(0,0,0,0.55)', color: '#fff', borderRadius: '0 0 8px 8px', cursor: (dogs || []).length > 0 ? 'pointer' : 'default' }}
                >{photoLabel(p)}</span>
                <button onClick={() => remove(p)} disabled={busy} title="remove" style={{ position: 'absolute', top: -6, right: -6, width: 18, height: 18, borderRadius: '50%', border: 'none', background: '#dc2626', color: '#fff', fontSize: 11, cursor: 'pointer', lineHeight: 1 }}>×</button>
              </div>
              <button
                onClick={() => toggleShare(p)}
                title={shared[p.id] ? 'Shared: the client sees this in their portal' : 'Not shared: only you see this'}
                style={{ marginTop: 3, width: '100%', fontSize: 9, fontWeight: 700, padding: '2px 0', borderRadius: 6, cursor: 'pointer', border: '1px solid', borderColor: shared[p.id] ? 'var(--ad-accent, #2563d8)' : 'var(--ad-outline, #d5d5dd)', background: shared[p.id] ? 'var(--ad-accent, #2563d8)' : 'transparent', color: shared[p.id] ? '#fff' : 'var(--ad-text-dim, #565b6c)' }}
              >
                {shared[p.id] ? 'Shared' : 'Share'}
              </button>
            </div>
          ))}
        </div>
      )}
      {open ? (
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
          {multiDog && (
            <span style={{ display: 'inline-flex', gap: 4, alignItems: 'center', flexWrap: 'wrap' }}>
              <span style={{ fontSize: 11, opacity: 0.55 }}>Of:</span>
              {[{ id: null, name: 'Pack' }, ...dogs].map((d) => (
                <button
                  key={d.id || 'all'}
                  onClick={() => setTagDog(d.id)}
                  disabled={busy}
                  style={{ fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 999, cursor: 'pointer',
                    border: '1px solid', borderColor: tagDog === d.id ? 'var(--ad-accent, #2563d8)' : 'var(--ad-outline, #d5d5dd)',
                    background: tagDog === d.id ? 'var(--ad-accent, #2563d8)' : 'transparent',
                    color: tagDog === d.id ? '#fff' : 'var(--ad-text-dim, #565b6c)' }}
                >
                  {d.name}
                </button>
              ))}
            </span>
          )}
          {SLOTS.map(([kind, label]) => (
            <label key={kind} className="ad-btn ad-btn--ghost ad-btn--sm" style={{ cursor: 'pointer' }}>
              + {label}
              <input type="file" accept="image/*" style={{ display: 'none' }} onChange={(e) => { onPick(kind, e.target.files); e.target.value = ''; }} />
            </label>
          ))}
          <label className="ad-btn ad-btn--ghost ad-btn--sm" style={{ cursor: 'pointer' }}>
            + Extras
            <input type="file" accept="image/*" multiple style={{ display: 'none' }} onChange={(e) => { onPick('extra', e.target.files); e.target.value = ''; }} />
          </label>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(false)}>Done</button>
          {pending > 0 && <span style={{ fontSize: 12, opacity: 0.6 }}>Uploading {pending}…</span>}
        </div>
      ) : (
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(true)}>+ Photos</button>
      )}
      {error && <div className="ad-error" style={{ marginTop: 6 }}>{error}</div>}
    </div>
  );
}
