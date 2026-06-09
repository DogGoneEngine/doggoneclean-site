// src/components/admin/VisitPhotos.jsx
//
// Photos on a visit: before, after, you-with-the-dog, plus extras. Pick straight
// from the phone (the Android picker reaches Google Photos), upload to the private
// visit-photos bucket, view through short-lived signed URLs. accept="image/*" with
// no capture, so the gallery is offered, not just the camera. See visit_photos_capture.

import { useState, useEffect, useCallback } from 'react';
import { uploadVisitPhoto, signedPhotoUrl, deleteVisitPhoto } from './supabase.js';

const KIND_LABEL = { before: 'Before', after: 'After', with_dog: 'With dog', extra: 'Extra' };
const SLOTS = [['before', 'Before'], ['after', 'After'], ['with_dog', 'With dog']];

export default function VisitPhotos({ visitId, clientId, photos = [], onChanged }) {
  const [urls, setUrls] = useState({});
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

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

  const onPick = useCallback(async (kind, files) => {
    if (!files || !files.length) return;
    setBusy(true); setError(null);
    try {
      for (const f of Array.from(files)) await uploadVisitPhoto(visitId, clientId, kind, f);
      onChanged?.();
    } catch (e) { setError(e.message || 'upload_failed'); }
    finally { setBusy(false); }
  }, [visitId, clientId, onChanged]);

  async function remove(p) {
    setBusy(true); setError(null);
    try { await deleteVisitPhoto(p.id, p.path); onChanged?.(); }
    catch (e) { setError(e.message || 'delete_failed'); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ marginTop: 6 }}>
      {photos.length > 0 && (
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 6 }}>
          {photos.map((p) => (
            <div key={p.id} style={{ position: 'relative' }}>
              <a href={urls[p.id] || undefined} target="_blank" rel="noreferrer" title={KIND_LABEL[p.kind]}>
                <div style={{ width: 64, height: 64, borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f1f1f4)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {urls[p.id]
                    ? <img src={urls[p.id]} alt={KIND_LABEL[p.kind]} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    : <span style={{ fontSize: 10, opacity: 0.5 }}>…</span>}
                </div>
              </a>
              <span style={{ position: 'absolute', bottom: 0, left: 0, right: 0, fontSize: 9, textAlign: 'center', background: 'rgba(0,0,0,0.55)', color: '#fff', borderRadius: '0 0 8px 8px' }}>{KIND_LABEL[p.kind]}</span>
              <button onClick={() => remove(p)} disabled={busy} title="remove" style={{ position: 'absolute', top: -6, right: -6, width: 18, height: 18, borderRadius: '50%', border: 'none', background: '#dc2626', color: '#fff', fontSize: 11, cursor: 'pointer', lineHeight: 1 }}>×</button>
            </div>
          ))}
        </div>
      )}
      {open ? (
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
          {SLOTS.map(([kind, label]) => (
            <label key={kind} className="ad-btn ad-btn--ghost ad-btn--sm" style={{ cursor: 'pointer' }}>
              + {label}
              <input type="file" accept="image/*" style={{ display: 'none' }} disabled={busy} onChange={(e) => onPick(kind, e.target.files)} />
            </label>
          ))}
          <label className="ad-btn ad-btn--ghost ad-btn--sm" style={{ cursor: 'pointer' }}>
            + Extras
            <input type="file" accept="image/*" multiple style={{ display: 'none' }} disabled={busy} onChange={(e) => onPick('extra', e.target.files)} />
          </label>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(false)} disabled={busy}>Done</button>
          {busy && <span style={{ fontSize: 12, opacity: 0.6 }}>Uploading…</span>}
        </div>
      ) : (
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(true)}>+ Photos</button>
      )}
      {error && <div className="ad-error" style={{ marginTop: 6 }}>{error}</div>}
    </div>
  );
}
