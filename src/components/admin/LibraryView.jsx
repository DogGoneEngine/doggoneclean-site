// src/components/admin/LibraryView.jsx
//
// The Library, now three shelves (photo_destinations):
//  - Assets: the hand-uploaded asset bucket (photo_inbox_for_claude, grown up).
//    Every photo/video Paul hands the business, with a note and a status.
//  - Team gallery: visit photos toggled Team, kept for internal enjoyment, for
//    everyone who logs in. Not customer-facing.
//  - Website: owner-only. The approval queue for the public gallery plus what
//    is live. Employees can suggest a photo; only the owner approves it live.
//
// Upload limit on Assets: the Supabase free plan caps a single file at 50MB.
// Phone videos often exceed that; those go to Google Drive instead.

import { useCallback, useEffect, useState } from 'react';
import {
  addInboxPhoto, listInbox, updateInboxNote, setInboxStatus, signedPhotoUrl, adminSelf,
  teamGallery, websiteReview, approvePhotoWebsite, unpublishPhotoWebsite, withdrawPhotoWebsite,
} from './supabase.js';
import HelpToggle from './Help.jsx';

const STATUS_LABEL = { new: 'New', shelf: 'On the shelf', used: 'Used', dropped: 'Dropped' };
const GRID = { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 };

// Sign preview URLs for a list of items that each carry a `path`. The effect
// keys on the set of ids (a stable string), NOT the array reference, because
// callers pass a freshly built array (items || []) every render; depending on
// the reference would re-run the effect and setState every render, an infinite
// loop that crashes the island.
function useSignedUrls(items) {
  const [urls, setUrls] = useState({});
  const list = items || [];
  const key = list.map((i) => i.id).join(',');
  useEffect(() => {
    let alive = true;
    (async () => {
      const entries = await Promise.all(list.map(async (i) => {
        try { return [i.id, await signedPhotoUrl(i.path)]; } catch { return [i.id, null]; }
      }));
      if (alive) setUrls(Object.fromEntries(entries));
    })();
    return () => { alive = false; };
  }, [key]); // eslint-disable-line react-hooks/exhaustive-deps
  return urls;
}

function caption(i) {
  const who = i.dog_name || i.client || '';
  const when = i.visited_at ? new Date(i.visited_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : '';
  return [who, when].filter(Boolean).join(' · ');
}

export default function LibraryView() {
  const [tab, setTab] = useState('assets');
  const [me, setMe] = useState(null);
  useEffect(() => { adminSelf().then(setMe).catch(() => {}); }, []);
  const isOwner = me?.role === 'owner';

  // Wait for the role before rendering tabs, so a non-default tab never flashes
  // for the owner on the first paint.
  if (!me) {
    return (
      <>
        <h1>Library</h1>
        <p className="ad-sub">Loading…</p>
      </>
    );
  }

  // The crew gets the Team gallery only; Assets (the owner's upload shelf) and
  // Website (the approval queue) are owner-only, enforced in the RPCs too.
  const tabs = isOwner
    ? [['assets', 'Assets'], ['team', 'Team gallery'], ['website', 'Website']]
    : [['team', 'Team gallery']];
  const activeTab = tabs.some(([k]) => k === tab) ? tab : 'team';

  return (
    <>
      <h1>Library</h1>
      <p className="ad-sub">
        {isOwner
          ? "Photos and videos with a life beyond their visit. Assets is your upload shelf; the Team gallery is the crew's internal keep; Website is the public gallery you approve."
          : "The crew's gallery: great shots from the road, kept so they aren't lost."}
      </p>

      {tabs.length > 1 && (
        <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap' }}>
          {tabs.map(([key, label]) => (
            <button key={key} onClick={() => setTab(key)}
              className={'ad-btn ad-btn--sm ' + (activeTab === key ? '' : 'ad-btn--ghost')}>
              {label}
            </button>
          ))}
        </div>
      )}

      {activeTab === 'assets' && isOwner && <AssetsShelf />}
      {activeTab === 'team' && <TeamGallery />}
      {activeTab === 'website' && isOwner && <WebsiteReview />}
    </>
  );
}

// ---- Assets (the original library) ------------------------------------------
function AssetsShelf() {
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
        <>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8, fontSize: 12, opacity: 0.7 }}>
          <span>Each item shows its status. Not sure about the buttons?</span>
          <HelpToggle items={[
            ['Shelf', 'You keep it. It stays in your library for later.'],
            ['Drop', 'You are done with it. It leaves the library.'],
            ['Tap the note', 'Tap the text under any item to add or change what it says.'],
          ]} />
        </div>
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
        </>
      )}
    </>
  );
}

// ---- Team gallery (internal, all roles) -------------------------------------
function TeamGallery() {
  const [items, setItems] = useState(null);
  const [err, setErr] = useState(null);
  useEffect(() => { teamGallery().then((d) => setItems(d || [])).catch((e) => setErr(e.message || 'load_failed')); }, []);
  const urls = useSignedUrls(items || []);
  if (err) return <div className="ad-error">{err}</div>;
  if (!items) return <div className="ad-panel" style={{ opacity: 0.6 }}>Loading the gallery…</div>;
  if (items.length === 0) return <div className="ad-panel" style={{ opacity: 0.6 }}>No team photos yet. Tap Team on any visit photo to keep it here.</div>;
  return (
    <div style={GRID}>
      {items.map((i) => (
        <figure key={i.id} className="ad-panel" style={{ padding: 8, margin: 0 }}>
          <div style={{ aspectRatio: '1 / 1', borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f5f4f1)' }}>
            {urls[i.id]
              ? <a href={urls[i.id]} target="_blank" rel="noreferrer"><img src={urls[i.id]} alt={caption(i)} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /></a>
              : <span style={{ fontSize: 11, opacity: 0.5 }}>…</span>}
          </div>
          <figcaption style={{ fontSize: 12, opacity: 0.7, marginTop: 6, display: 'flex', justifyContent: 'space-between', gap: 6 }}>
            <span>{caption(i)}</span>
            {i.website_state === 'live' && <span title="Live on the website" style={{ color: 'var(--ad-warn, #b9770a)' }}>web</span>}
          </figcaption>
        </figure>
      ))}
    </div>
  );
}

// ---- Website review (owner only) --------------------------------------------
function WebsiteReview() {
  const [data, setData] = useState(null);
  const [err, setErr] = useState(null);
  const [busy, setBusy] = useState(false);
  const load = useCallback(() => websiteReview().then(setData).catch((e) => setErr(e.message || 'load_failed')), []);
  useEffect(() => { load(); }, [load]);
  const queued = data?.queued || [];
  const live = data?.live || [];
  const cap = data?.cap || 24;
  const qUrls = useSignedUrls(queued);
  const lUrls = useSignedUrls(live);

  async function act(fn, id) {
    setBusy(true); setErr(null);
    try { await fn(id); await load(); }
    catch (e) { setErr(e.message || 'action_failed'); }
    finally { setBusy(false); }
  }
  // Approving signs a long-lived URL here in the browser (the owner can sign; a
  // public visitor cannot) and stores it, so the public gallery can show it
  // without an edge function. A year out; re-approve refreshes.
  async function approve(i) {
    setBusy(true); setErr(null);
    try {
      const url = await signedPhotoUrl(i.path, 31536000);
      await approvePhotoWebsite(i.id, url);
      await load();
    } catch (e) { setErr(e.message || 'approve_failed'); }
    finally { setBusy(false); }
  }

  if (err) return <div className="ad-error">{err}</div>;
  if (!data) return <div className="ad-panel" style={{ opacity: 0.6 }}>Loading the queue…</div>;

  return (
    <>
      <div className="ad-panel" style={{ marginBottom: 16, position: 'relative' }}>
        <HelpToggle corner items={[
          ['Approve', 'This dog goes live on your public website for everyone to see.'],
          ['Reject', 'It never reaches the website and leaves this list.'],
          ['Pull from website', 'On a live photo below: it comes off the public website right away.'],
        ]} />
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8, paddingRight: 24 }}>
          Waiting for your approval ({queued.length})
        </div>
        {queued.length === 0 ? (
          <div style={{ fontSize: 13, opacity: 0.6 }}>Nothing waiting. Anyone can suggest a photo from a visit; it lands here for you.</div>
        ) : (
          <div style={GRID}>
            {queued.map((i) => (
              <figure key={i.id} className="ad-panel" style={{ padding: 8, margin: 0 }}>
                <div style={{ aspectRatio: '1 / 1', borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f5f4f1)' }}>
                  {qUrls[i.id]
                    ? <a href={qUrls[i.id]} target="_blank" rel="noreferrer"><img src={qUrls[i.id]} alt={caption(i)} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /></a>
                    : <span style={{ fontSize: 11, opacity: 0.5 }}>…</span>}
                </div>
                <figcaption style={{ fontSize: 12, opacity: 0.7, margin: '6px 0' }}>
                  {caption(i)}{i.proposed_by ? ` · by ${i.proposed_by}` : ''}
                </figcaption>
                <div style={{ display: 'flex', gap: 6 }}>
                  <button className="ad-btn ad-btn--sm" disabled={busy} onClick={() => approve(i)}>Approve</button>
                  <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => act(withdrawPhotoWebsite, i.id)}>Reject</button>
                </div>
              </figure>
            ))}
          </div>
        )}
      </div>

      <div className="ad-panel">
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8 }}>
          Live on the website ({live.length} of {cap})
        </div>
        {live.length === 0 ? (
          <div style={{ fontSize: 13, opacity: 0.6 }}>Nothing live yet. Approve a photo above and it goes on the public gallery.</div>
        ) : (
          <div style={GRID}>
            {live.map((i) => (
              <figure key={i.id} className="ad-panel" style={{ padding: 8, margin: 0 }}>
                <div style={{ aspectRatio: '1 / 1', borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f5f4f1)' }}>
                  {lUrls[i.id]
                    ? <a href={lUrls[i.id]} target="_blank" rel="noreferrer"><img src={lUrls[i.id]} alt={caption(i)} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /></a>
                    : <span style={{ fontSize: 11, opacity: 0.5 }}>…</span>}
                </div>
                <figcaption style={{ fontSize: 12, opacity: 0.7, margin: '6px 0' }}>{caption(i)}</figcaption>
                <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => act(unpublishPhotoWebsite, i.id)}>Pull from website</button>
              </figure>
            ))}
          </div>
        )}
        <div style={{ fontSize: 11, opacity: 0.55, marginTop: 10 }}>
          The public gallery shows the newest {cap}. Approving more rolls the oldest off on its own.
        </div>
      </div>
    </>
  );
}
