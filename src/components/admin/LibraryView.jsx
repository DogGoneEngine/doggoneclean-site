// src/components/admin/LibraryView.jsx
//
// The Library: the asset library (photo_inbox_for_claude, grown up). Every
// photo and video Paul hands the business lives here, like the old
// Squarespace asset bucket: a great shot goes on the shelf even with no use
// for it yet, instead of getting lost in the Google Photos stream. Each item
// carries an editable note (what it is, what should happen with it) and a
// status: new (just arrived, Claude triages it next session), shelf (kept
// for later), used, dropped. Claude reads this floor's data from the bucket
// by path each session.
//
// Upload limit: the Supabase free plan caps a single file at 50MB. Phone
// videos often exceed that; those go to Google Drive instead, where Claude
// can read them with the Drive tools.

import { useCallback, useEffect, useState } from 'react';
import { addInboxPhoto, listInbox, updateInboxNote, setInboxStatus, signedPhotoUrl } from './supabase.js';

const STATUS_LABEL = { new: 'New', shelf: 'On the shelf', used: 'Used', dropped: 'Dropped' };

export default function LibraryView() {
  const [items, setItems] = useState([]);
  const [urls, setUrls] = useState({});
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);
  const [editId, setEditId] = useState(null);
  const [editText, setEditText] = useState('');

  const load = useCallback(async () => {
    try {
      const list = await listInbox();
      setItems(Array.isArray(list) ? list : []);
    } catch (e) { setErr(e.message || 'load_failed'); }
  }, []);
  useEffect(() => { load(); }, [load]);

  // Signed preview URLs, fetched lazily per item; videos get the same signed
  // URL and render in a <video> tag.
  useEffect(() => {
    let alive = true;
    (async () => {
      for (const i of items) {
        if (urls[i.id]) continue;
        try {
          const u = await signedPhotoUrl(i.storage_path);
          if (!alive) return;
          setUrls((prev) => ({ ...prev, [i.id]: u }));
        } catch { /* leave the tile without a preview */ }
      }
    })();
    return () => { alive = false; };
  }, [items]); // eslint-disable-line react-hooks/exhaustive-deps

  async function pick(e) {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    if (file.size > 50 * 1024 * 1024) {
      setErr('That file is over 50MB, the storage limit. Put big videos in Google Drive and Claude will pull them from there.');
      return;
    }
    setBusy(true); setErr(null);
    try { await addInboxPhoto(file, note.trim() || null); setNote(''); load(); }
    catch (x) { setErr(x.message === 'Failed to fetch' ? 'Upload died mid-transfer (weak signal or file too big). Try on wifi, or put it in Google Drive.' : (x.message || 'upload_failed')); }
    finally { setBusy(false); }
  }

  async function saveNote(id) {
    try { await updateInboxNote(id, editText.trim() || null); setEditId(null); setEditText(''); load(); }
    catch (x) { setErr(x.message || 'note_save_failed'); }
  }

  async function setStatus(id, status) {
    try { await setInboxStatus(id, status); load(); }
    catch (x) { setErr(x.message || 'status_failed'); }
  }

  const isVideo = (path) => /\.(mp4|webm|mov|m4v|mkv)$/i.test(path);

  return (
    <>
      <h1>Library</h1>
      <p className="ad-sub">
        Every photo and video you hand the business. Drop a great shot here even with no use for it yet; nothing gets lost in the photo stream. Claude reads this library each session and acts on the notes.
      </p>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <input className="pt-input" type="text" value={note} placeholder="What is this and what should happen with it? (You can also add the note after.)"
          onChange={(e) => setNote(e.target.value)}
          style={{ width: '100%', fontSize: 13, padding: '7px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', boxSizing: 'border-box', marginBottom: 8 }} />
        <label className="ad-btn ad-btn--sm" style={{ cursor: 'pointer' }}>
          {busy ? 'Uploading…' : 'Add a photo or video'}
          <input type="file" accept="image/*,video/*" onChange={pick} disabled={busy} style={{ display: 'none' }} />
        </label>
        <span style={{ fontSize: 12, opacity: 0.55, marginLeft: 10 }}>Up to 50MB. Bigger videos: drop them in Google Drive instead.</span>
        {err && <div className="ad-error" style={{ fontSize: 12, marginTop: 6 }}>{err}</div>}
      </div>

      {items.length === 0 ? (
        <div className="ad-panel" style={{ opacity: 0.6 }}>Nothing in the library yet.</div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12 }}>
          {items.map((i) => (
            <div key={i.id} className="ad-panel" style={{ padding: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div style={{ aspectRatio: '4 / 3', borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f5f4f1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {urls[i.id] ? (
                  isVideo(i.storage_path)
                    ? <video src={urls[i.id]} controls preload="metadata" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    : <img src={urls[i.id]} alt={i.note || 'library item'} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                ) : <span style={{ fontSize: 12, opacity: 0.5 }}>loading…</span>}
              </div>
              {editId === i.id ? (
                <div style={{ display: 'flex', gap: 6 }}>
                  <input className="pt-input" type="text" value={editText} autoFocus
                    onChange={(e) => setEditText(e.target.value)}
                    onKeyDown={(e) => { if (e.key === 'Enter') saveNote(i.id); if (e.key === 'Escape') setEditId(null); }}
                    style={{ flex: 1, fontSize: 12, padding: '5px 8px', borderRadius: 6, border: '1px solid var(--ad-outline, #d8d8de)' }} />
                  <button className="ad-btn ad-btn--sm" onClick={() => saveNote(i.id)}>Save</button>
                </div>
              ) : (
                <div style={{ fontSize: 13, opacity: i.note ? 0.9 : 0.5, cursor: 'pointer' }} title="Tap to edit the note"
                  onClick={() => { setEditId(i.id); setEditText(i.note || ''); }}>
                  {i.note || 'No note yet. Tap to add one.'}
                </div>
              )}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
                <span className="ad-mono" style={{ fontSize: 11, opacity: 0.6 }}>
                  {new Date(i.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} · {STATUS_LABEL[i.status] || i.status}
                </span>
                <span style={{ display: 'flex', gap: 4 }}>
                  {i.status !== 'shelf' && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setStatus(i.id, 'shelf')}>Shelf</button>}
                  {i.status !== 'dropped' && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setStatus(i.id, 'dropped')}>Drop</button>}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  );
}
