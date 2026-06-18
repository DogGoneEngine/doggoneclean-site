// src/components/admin/VisitPhotos.jsx
//
// Photos on a visit: before, after, you-with-the-dog, plus extras. Pick straight
// from the phone (the Android picker reaches Google Photos), upload to the private
// visit-photos bucket, view through short-lived signed URLs. accept="image/*" with
// no capture, so the gallery is offered, not just the camera. See visit_photos_capture.
//
// Layout (rethought 2026-06-18, photos_clean_grid_and_editor): a clean grid of
// larger thumbnails, each showing only small dots for where it is shared. Tap a
// photo to open a roomy editor with finger-sized controls (destinations, which
// dog, flags, remove), so nothing has to be pinch-zoomed to tap. The old version
// crammed four 9px chips plus a flag and a remove button under a 64px thumbnail.

import { useState, useEffect, useCallback } from 'react';
import { uploadVisitPhoto, signedPhotoUrl, deleteVisitPhoto, setPhotoVisibility, setPhotoAnswersRequest, setPhotoTeam, suggestPhotoWebsite, withdrawPhotoWebsite, setWorthALook, flagForOwner, setPhotoDog, adminSelf } from './supabase.js';

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

const DEST_COLOR = { client: '#2563d8', team: '#1f8a4b', web: '#b9770a', answer: '#7c3aed' };

// Shared styling for the add-photo area: a small section label and an equal-sized
// tile (a file-input dressed as a card), so the upload choices are a clean grid
// instead of a jumble of mismatched buttons.
const ADD_LABEL = { fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.3, opacity: 0.55, marginBottom: 6 };
const ADD_TILE = {
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  padding: '16px 8px', borderRadius: 12, cursor: 'pointer', textAlign: 'center',
  border: '1px solid var(--ad-outline, #d8d8de)', background: 'var(--ad-surface-container, #f5f6f8)',
  fontSize: 14, fontWeight: 600, color: 'var(--ad-text, #1c1d22)',
};

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
  // The photo whose editor is open. One at a time keeps the grid clean.
  const [selectedId, setSelectedId] = useState(null);
  const selected = photos.find((p) => p.id === selectedId) || null;
  useEffect(() => { if (selectedId && !photos.some((p) => p.id === selectedId)) setSelectedId(null); }, [photos, selectedId]);

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

  // Set which dog a photo shows (explicit, from the editor). null = the whole pack.
  async function setDogTo(p, id) {
    setBusy(true); setError(null);
    try { await setPhotoDog(p.id, id); onChanged?.(); }
    catch (e) { setError(e.message || 'tag_failed'); }
    finally { setBusy(false); }
  }
  function photoLabel(p) {
    const kind = KIND_LABEL[p.kind] || 'Photo';
    return p.dog_name ? `${kind} · ${p.dog_name}` : kind;
  }

  async function remove(p) {
    setBusy(true); setError(null);
    try { await deleteVisitPhoto(p.id, p.path); onChanged?.(); }
    catch (e) { setError(e.message || 'delete_failed'); }
    finally { setBusy(false); }
  }

  // Sharing is per photo and deliberate: a shared photo shows in the
  // client's portal (later the Dog Gone Tracker too). Optimistic toggles.
  const [shared, setShared] = useState({});
  const [answer, setAnswer] = useState({});
  const [team, setTeam] = useState({});
  const [web, setWeb] = useState({});
  useEffect(() => {
    setShared(Object.fromEntries(photos.map((p) => [p.id, !!p.client_visible])));
    setAnswer(Object.fromEntries(photos.map((p) => [p.id, !!p.answers_request])));
    setTeam(Object.fromEntries(photos.map((p) => [p.id, !!p.team_visible])));
    setWeb(Object.fromEntries(photos.map((p) => [p.id, p.website_state || 'none'])));
  }, [photos]);
  async function toggleShare(p) {
    const next = !shared[p.id];
    setShared((s) => ({ ...s, [p.id]: next }));
    setError(null);
    try { await setPhotoVisibility(p.id, next); }
    catch (e) { setShared((s) => ({ ...s, [p.id]: !next })); setError(e.message || 'share_failed'); }
  }
  async function toggleTeam(p) {
    const next = !team[p.id];
    setTeam((s) => ({ ...s, [p.id]: next }));
    setError(null);
    try { await setPhotoTeam(p.id, next); }
    catch (e) { setTeam((s) => ({ ...s, [p.id]: !next })); setError(e.message || 'team_failed'); }
  }
  // Website from a photo is suggest-only for everyone; the owner approves a
  // queued photo in the Library's Website tab. A fat finger can at worst queue.
  async function webAction(p) {
    const cur = web[p.id] || 'none';
    if (cur === 'live') return; // pulling a live photo is owner-only, in review
    const next = cur === 'queued' ? 'none' : 'queued';
    setWeb((s) => ({ ...s, [p.id]: next }));
    setError(null);
    try { next === 'queued' ? await suggestPhotoWebsite(p.id) : await withdrawPhotoWebsite(p.id); }
    catch (e) { setWeb((s) => ({ ...s, [p.id]: cur })); setError(e.message || 'website_failed'); }
  }
  // Tag a photo as the proof of what the client asked for. The server also
  // shares it (the client must see the proof on their tracker), so reflect that.
  async function toggleAnswer(p) {
    const next = !answer[p.id];
    setAnswer((s) => ({ ...s, [p.id]: next }));
    if (next) setShared((s) => ({ ...s, [p.id]: true }));
    setError(null);
    try { await setPhotoAnswersRequest(p.id, next); }
    catch (e) { setAnswer((s) => ({ ...s, [p.id]: !next })); setError(e.message || 'tag_failed'); }
  }

  function liveDests(p) {
    const out = [];
    if (shared[p.id]) out.push('client');
    if (team[p.id]) out.push('team');
    if (web[p.id] && web[p.id] !== 'none') out.push('web');
    if (answer[p.id]) out.push('answer');
    return out;
  }

  return (
    <div style={{ marginTop: 6 }}>
      {photos.length > 0 && (
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 12 }}>
          {photos.map((p) => {
            const dests = liveDests(p);
            const flagged = p.worth_a_look || p.field_flag;
            const isSel = selectedId === p.id;
            return (
              <button key={p.id} type="button" onClick={() => setSelectedId(isSel ? null : p.id)}
                style={{ width: 116, padding: 0, border: 'none', background: 'transparent', cursor: 'pointer', textAlign: 'left' }}>
                <div style={{ position: 'relative', width: 116, height: 116, borderRadius: 12, overflow: 'hidden',
                  background: 'var(--ad-surface-container, #f1f1f4)',
                  outline: isSel ? '3px solid var(--ad-primary, #2563d8)' : '1px solid var(--ad-outline, #e6e6ec)', outlineOffset: isSel ? 1 : 0 }}>
                  {urls[p.id]
                    ? <img src={urls[p.id]} alt={KIND_LABEL[p.kind]} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    : <span style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, opacity: 0.5 }}>…</span>}
                  <span style={{ position: 'absolute', bottom: 0, left: 0, right: 0, fontSize: 11, padding: '3px 7px',
                    background: 'linear-gradient(transparent, rgba(0,0,0,0.62))', color: '#fff', fontWeight: 600 }}>{photoLabel(p)}</span>
                  {dests.length > 0 && (
                    <span style={{ position: 'absolute', top: 6, left: 6, display: 'flex', gap: 4 }}>
                      {dests.map((k) => <span key={k} title={k} style={{ width: 9, height: 9, borderRadius: '50%', background: DEST_COLOR[k], boxShadow: '0 0 0 1.5px rgba(255,255,255,0.85)' }} />)}
                    </span>
                  )}
                  {flagged && <span style={{ position: 'absolute', top: 6, right: 6, fontSize: 12 }} title="flagged">🚩</span>}
                </div>
              </button>
            );
          })}
        </div>
      )}

      {selected && (
        <PhotoEditor
          photo={selected}
          url={urls[selected.id]}
          label={photoLabel(selected)}
          dogs={dogs}
          busy={busy}
          dest={{ client: !!shared[selected.id], team: !!team[selected.id], web: web[selected.id] || 'none', answer: !!answer[selected.id] }}
          onClient={() => toggleShare(selected)}
          onTeam={() => toggleTeam(selected)}
          onWeb={() => webAction(selected)}
          onAnswer={() => toggleAnswer(selected)}
          onSetDog={(id) => setDogTo(selected, id)}
          onRemove={async () => { await remove(selected); setSelectedId(null); }}
          onChanged={onChanged}
          onClose={() => setSelectedId(null)}
        />
      )}

      {open ? (
        <div style={{ marginTop: photos.length ? 4 : 0, display: 'flex', flexDirection: 'column', gap: 14 }}>
          {/* Whose photos these are. Deliberately styled apart from the bold blue
              "Dogs on this appointment" chips above (lighter, its own label, only
              here while adding) so the two dog rows never read as the same control. */}
          {multiDog && (
            <div>
              <div style={ADD_LABEL}>These photos are of</div>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                {[{ id: null, name: 'Whole pack' }, ...dogs].map((d) => {
                  const on = tagDog === d.id;
                  return (
                    <button key={d.id || 'all'} onClick={() => setTagDog(d.id)} disabled={busy}
                      style={{ fontSize: 13, fontWeight: 600, padding: '6px 12px', borderRadius: 999, cursor: 'pointer',
                        border: '1px solid', borderColor: on ? '#475569' : 'var(--ad-outline, #d5d5dd)',
                        background: on ? '#475569' : 'transparent', color: on ? '#fff' : 'var(--ad-text-dim, #565b6c)' }}>
                      {d.name}
                    </button>
                  );
                })}
              </div>
            </div>
          )}
          {/* The shot to add: four equal tiles, no more mismatched button widths. */}
          <div>
            <div style={ADD_LABEL}>Add a photo</div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>
              {SLOTS.map(([kind, label]) => (
                <label key={kind} style={ADD_TILE}>
                  <input type="file" accept="image/*" style={{ display: 'none' }} onChange={(e) => { onPick(kind, e.target.files); e.target.value = ''; }} />
                  {label}
                </label>
              ))}
              <label style={ADD_TILE}>
                <input type="file" accept="image/*" multiple style={{ display: 'none' }} onChange={(e) => { onPick('extra', e.target.files); e.target.value = ''; }} />
                Extras
              </label>
            </div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 12, opacity: 0.6 }}>{pending > 0 ? `Uploading ${pending}…` : ''}</span>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(false)}>Done</button>
          </div>
        </div>
      ) : (
        <button className="ad-btn" onClick={() => setOpen(true)}>+ Add photos</button>
      )}
      {error && <div className="ad-error" style={{ marginTop: 6 }}>{error}</div>}
    </div>
  );
}

// The roomy per-photo editor: a bigger preview and finger-sized controls. Opens
// below the grid when a photo is tapped. Everything the old cramped chips did,
// with real touch targets and a one-line "what this does" on each destination.
function PhotoEditor({ photo, url, label, dogs = [], busy, dest, onClient, onTeam, onWeb, onAnswer, onSetDog, onRemove, onChanged, onClose }) {
  const webOn = dest.web !== 'none';
  const webLabel = dest.web === 'live' ? 'On the website' : dest.web === 'queued' ? 'Queued for the website' : 'Website';
  const webDesc = dest.web === 'live' ? 'Live on the public site (pull it in the Library)'
    : dest.web === 'queued' ? 'Suggested. Waiting for the owner to approve. Tap to withdraw.'
    : 'Suggest it for the public website. The owner approves before it shows.';
  const multiDog = (dogs || []).length > 0;
  return (
    <div className="ad-panel" style={{ marginBottom: 12, padding: 14 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
        <strong style={{ fontSize: 14 }}>{label}</strong>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={onClose}>Close</button>
      </div>
      <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap' }}>
        <a href={url || undefined} target="_blank" rel="noreferrer"
          style={{ display: 'block', width: 150, height: 150, borderRadius: 12, overflow: 'hidden', background: 'var(--ad-surface-container, #f1f1f4)', flexShrink: 0 }}>
          {url ? <img src={url} alt={label} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : null}
        </a>
        <div style={{ flex: 1, minWidth: 230, display: 'flex', flexDirection: 'column', gap: 8 }}>
          <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.3, opacity: 0.55 }}>Where this photo goes</div>
          <DestRow on={dest.client} color={DEST_COLOR.client} label="Client" desc="They see it in their portal and on the tracker" onClick={onClient} disabled={busy} />
          <DestRow on={dest.team} color={DEST_COLOR.team} label="Team" desc="Only your crew sees it, in the private gallery" onClick={onTeam} disabled={busy} />
          <DestRow on={webOn} color={DEST_COLOR.web} label={webLabel} desc={webDesc} onClick={onWeb} disabled={busy || dest.web === 'live'} />
          <DestRow on={dest.answer} color={DEST_COLOR.answer} label="Answer to their request" desc="Proof of what they asked for, beside their request on the tracker" onClick={onAnswer} disabled={busy} />
        </div>
      </div>

      {multiDog && (
        <div style={{ marginTop: 12 }}>
          <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.3, opacity: 0.55, marginBottom: 5 }}>Which dog</div>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {[{ id: null, name: 'The pack' }, ...dogs].map((d) => {
              const on = (photo.dog_id || null) === (d.id || null);
              return (
                <button key={d.id || 'pack'} onClick={() => onSetDog(d.id)} disabled={busy}
                  style={{ fontSize: 13, fontWeight: 600, padding: '6px 12px', borderRadius: 999, cursor: 'pointer',
                    border: '1px solid', borderColor: on ? 'var(--ad-accent, #2563d8)' : 'var(--ad-outline, #d5d5dd)',
                    background: on ? 'var(--ad-accent, #2563d8)' : 'transparent', color: on ? '#fff' : 'var(--ad-text, #1c1d22)' }}>
                  {d.name}
                </button>
              );
            })}
          </div>
        </div>
      )}

      <PhotoFlag photo={photo} onChanged={onChanged} />

      <div style={{ marginTop: 12, borderTop: '1px solid var(--ad-outline, #ececf1)', paddingTop: 10 }}>
        <button onClick={onRemove} disabled={busy}
          style={{ fontSize: 13, fontWeight: 600, padding: '7px 12px', borderRadius: 8, cursor: 'pointer',
            border: '1px solid var(--ad-bad, #dc2626)', background: 'transparent', color: 'var(--ad-bad, #dc2626)' }}>
          Remove photo
        </button>
      </div>
    </div>
  );
}

// A big destination toggle row: a check box, a bold label, and a one-line
// explanation. Filled in its color when on. Finger-sized, full width.
function DestRow({ on, color, label, desc, onClick, disabled }) {
  return (
    <button type="button" onClick={onClick} disabled={disabled}
      style={{ display: 'flex', alignItems: 'center', gap: 11, width: '100%', textAlign: 'left', padding: '9px 11px', borderRadius: 10, cursor: disabled ? 'default' : 'pointer',
        border: '1px solid', borderColor: on ? color : 'var(--ad-outline, #d8d8de)', background: on ? `${color}14` : 'transparent', opacity: disabled && !on ? 0.6 : 1 }}>
      <span style={{ width: 22, height: 22, borderRadius: 6, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14, color: '#fff',
        background: on ? color : 'transparent', border: on ? 'none' : '2px solid var(--ad-outline, #cfcfd6)' }}>{on ? '✓' : ''}</span>
      <span style={{ flex: 1, minWidth: 0 }}>
        <span style={{ display: 'block', fontSize: 14, fontWeight: 600, color: on ? color : 'var(--ad-text, #1c1d22)' }}>{label}</span>
        <span style={{ display: 'block', fontSize: 12, lineHeight: 1.35, opacity: 0.72 }}>{desc}</span>
      </span>
    </button>
  );
}

// Per-photo "look at this" flags: Worth a look (to the client) and For the owner
// (private), each with a short note. Lives inside the editor now, with real buttons.
function PhotoFlag({ photo, onChanged }) {
  const [open, setOpen] = useState(false);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);
  const wal = !!photo.worth_a_look;
  const fld = !!photo.field_flag;

  async function run(fn) {
    setBusy(true); setErr(null);
    try { await fn(); setOpen(false); setNote(''); onChanged?.(); }
    catch (e) { setErr(e.message || 'flag_failed'); setBusy(false); }
  }

  return (
    <div style={{ marginTop: 12 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.3, opacity: 0.55, marginBottom: 5 }}>Flag this photo</div>
      {(wal || fld) && (
        <div style={{ fontSize: 12, marginBottom: 6 }}>
          {wal && <span style={{ color: 'var(--ad-accent, #2563d8)' }}>Worth a look, the client gets a heads-up. </span>}
          {fld && <span style={{ color: 'var(--ad-warn, #b9770a)' }}>Sent to the owner.</span>}
        </div>
      )}
      {!open ? (
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" type="button" onClick={() => setOpen(true)}>Flag this photo…</button>
          {wal && <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => run(() => setWorthALook(photo.id, false))}>Remove worth-a-look</button>}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxWidth: 420 }}>
          <textarea value={note} onChange={(e) => setNote(e.target.value)} rows={2} placeholder="What you noticed (optional)"
            style={{ width: '100%', fontSize: 13, padding: '7px 9px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', boxSizing: 'border-box', resize: 'vertical', fontFamily: 'inherit' }} />
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button className="ad-btn ad-btn--sm" disabled={busy} onClick={() => run(() => setWorthALook(photo.id, true, note.trim() || null))}>Worth a look (client)</button>
            <button className="ad-btn ad-btn--sm ad-btn--ghost" disabled={busy} onClick={() => run(() => flagForOwner(photo.id, note.trim() || null))}>For the owner</button>
            <button type="button" onClick={() => { setOpen(false); setErr(null); }} className="ad-btn ad-btn--ghost ad-btn--sm">Cancel</button>
          </div>
          {err && <div className="ad-error" style={{ fontSize: 12 }}>{err}</div>}
        </div>
      )}
    </div>
  );
}
