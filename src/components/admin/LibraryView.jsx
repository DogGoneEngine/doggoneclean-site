// src/components/admin/LibraryView.jsx
//
// The Library, one model (library_assets_are_the_master, Paul 2026-06-15):
//  - Assets is the MASTER list of everything in the library: photos/videos the
//    owner uploads, plus any visit photo someone kept (shared to Team, suggested
//    to Website, or saved). Owner only.
//  - Team gallery and Website are COPIES/shares of an Asset, not separate piles.
//    Turning a copy off (pull from website, untoggle Team) never loses the item;
//    the master stays in Assets.
//  - The ONLY permanent loss is the red x in Assets. For an upload it deletes the
//    file for good; for a kept visit photo it leaves the library but stays in the
//    client's visit, so nothing slips through the cracks.
//
// Every item carries a `source` ('upload' | 'visit') so one set of controls drives
// both origins. Upload limit on Assets: the Supabase free plan caps a file at
// 50MB; bigger videos go to Google Drive.

import { useCallback, useEffect, useState } from 'react';
import {
  addInboxPhoto, signedPhotoUrl, adminSelf, teamGallery, websiteReview,
  libraryList, librarySetTeam, librarySuggestWebsite, libraryWithdrawWebsite,
  libraryApproveWebsite, libraryUnpublishWebsite, librarySetCaption, libraryDelete,
} from './supabase.js';
import HelpToggle from './Help.jsx';

const GRID = { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: 12 };
const isVideo = (path, kind) => kind === 'video' || /\.(mp4|webm|mov|m4v|mkv)$/i.test(path || '');

// What a tile shows under the photo: the explicit caption if there is one, else
// the dog and date we already know. Used on every tab.
function autoCaption(i) {
  if (i.caption) return i.caption;
  const who = i.dog_name || i.client || '';
  const day = i.dated || i.visited_at || i.live_at;
  const when = day ? new Date(day).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : '';
  return [who, when].filter(Boolean).join(' · ');
}

// Sign preview URLs for a list of items that each carry a `path`. Keys on the set
// of item keys (a stable string), NOT the array reference, because callers pass a
// freshly built array every render; depending on the reference would re-run the
// effect and setState every render, an infinite loop that crashes the island.
function itemKey(i) { return `${i.source || 'visit'}:${i.id}`; }
function useSignedUrls(items) {
  const [urls, setUrls] = useState({});
  const list = items || [];
  const key = list.map(itemKey).join(',');
  useEffect(() => {
    let alive = true;
    (async () => {
      const entries = await Promise.all(list.map(async (i) => {
        try { return [itemKey(i), await signedPhotoUrl(i.path)]; } catch { return [itemKey(i), null]; }
      }));
      if (alive) setUrls(Object.fromEntries(entries));
    })();
    return () => { alive = false; };
  }, [key]); // eslint-disable-line react-hooks/exhaustive-deps
  return urls;
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

  // The crew gets the Team gallery only; Assets (the master) and Website (the
  // approval queue) are owner-only, enforced in the RPCs too.
  const tabs = isOwner
    ? [['assets', 'Assets'], ['team', 'Team gallery'], ['website', 'Website']]
    : [['team', 'Team gallery']];
  const activeTab = tabs.some(([k]) => k === tab) ? tab : 'team';

  return (
    <>
      <h1>Library</h1>
      <p className="ad-sub">
        {isOwner
          ? "Assets is your master list of everything. Team gallery and Website are copies you share from it; pulling a copy never loses the original. Only the red x in Assets deletes for good."
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

// ---- Assets (the master list) -----------------------------------------------
function AssetsShelf() {
  const [items, setItems] = useState([]);
  const [note, setNote] = useState('');
  const [toTeam, setToTeam] = useState(false);
  const [toWeb, setToWeb] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);
  const [editKey, setEditKey] = useState(null);
  const [editText, setEditText] = useState('');
  const urls = useSignedUrls(items);

  const load = useCallback(async () => {
    try {
      const list = await libraryList();
      setItems(Array.isArray(list) ? list : []);
    } catch (e) { setErr(e.message || 'load_failed'); }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function pick(e) {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    if (file.size > 50 * 1024 * 1024) {
      setErr('That file is over 50MB, the storage limit. Put big videos in Google Drive and Claude will pull them from there.');
      return;
    }
    setBusy(true); setErr(null);
    try {
      const id = await addInboxPhoto(file, note.trim() || null);
      if (toTeam) await librarySetTeam('upload', id, true);
      if (toWeb) await librarySuggestWebsite('upload', id);
      setNote(''); setToTeam(false); setToWeb(false);
      await load();
    } catch (x) {
      setErr(x.message === 'Failed to fetch' ? 'Upload died mid-transfer (weak signal or file too big). Try on wifi, or put it in Google Drive.' : (x.message || 'upload_failed'));
    } finally { setBusy(false); }
  }

  async function act(fn) {
    setErr(null);
    try { await fn(); await load(); }
    catch (x) { setErr(x.message || 'action_failed'); }
  }
  async function saveCaption(i) {
    await act(() => librarySetCaption(i.source, i.id, editText.trim() || null));
    setEditKey(null); setEditText('');
  }
  async function remove(i) {
    const msg = i.source === 'upload'
      ? 'Delete this for good? The file will be permanently removed and cannot be recovered.'
      : `Remove this from your library? The photo stays in ${i.client || 'the'} ${i.client ? "'s" : ''} visit history; it just leaves the library, Team gallery, and website.`;
    if (!window.confirm(msg)) return;
    await act(() => libraryDelete(i.source, i.id));
  }

  return (
    <>
      <div className="ad-panel" style={{ marginBottom: 16, position: 'relative' }}>
        <HelpToggle corner items={[
          ['Add a photo or video', 'Adds it to Assets, your master list. Tick Team or Website to share it there at the same time.'],
          ['Team', 'Puts a copy in the crew gallery. Untick it later and the original stays in Assets.'],
          ['Website', 'Suggests it for the public site; you approve it in the Website tab. Pulling it later keeps the original in Assets.'],
          ['Tap the caption', 'Tap the text under any item to write or change its caption.'],
          ['Red x', 'The only delete. An upload is gone for good; a visit photo just leaves the library and stays in the visit.'],
        ]} />
        <input className="pt-input" type="text" value={note} placeholder="Caption (optional, you can add or change it later)"
          onChange={(e) => setNote(e.target.value)}
          style={{ width: '100%', fontSize: 13, padding: '7px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', boxSizing: 'border-box', marginBottom: 8 }} />
        <div style={{ display: 'flex', gap: 14, alignItems: 'center', flexWrap: 'wrap', marginBottom: 8 }}>
          <span style={{ fontSize: 12, opacity: 0.6 }}>Also share to:</span>
          <label style={{ fontSize: 13, display: 'flex', gap: 5, alignItems: 'center', cursor: 'pointer' }}>
            <input type="checkbox" checked={toTeam} onChange={(e) => setToTeam(e.target.checked)} /> Team gallery
          </label>
          <label style={{ fontSize: 13, display: 'flex', gap: 5, alignItems: 'center', cursor: 'pointer' }}>
            <input type="checkbox" checked={toWeb} onChange={(e) => setToWeb(e.target.checked)} /> Website (you approve it)
          </label>
        </div>
        <label className="ad-btn ad-btn--sm" style={{ cursor: 'pointer' }}>
          {busy ? 'Uploading…' : 'Add a photo or video'}
          <input type="file" accept="image/*,video/*" onChange={pick} disabled={busy} style={{ display: 'none' }} />
        </label>
        <span style={{ fontSize: 12, opacity: 0.55, marginLeft: 10 }}>Up to 50MB. Bigger videos: put them in Google Drive instead.</span>
        {err && <div className="ad-error" style={{ fontSize: 12, marginTop: 6 }}>{err}</div>}
      </div>

      {items.length === 0 ? (
        <div className="ad-panel" style={{ opacity: 0.6 }}>Nothing in the library yet.</div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 12 }}>
          {items.map((i) => {
            const k = itemKey(i);
            return (
              <div key={k} className="ad-panel" style={{ padding: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
                <div style={{ aspectRatio: '4 / 3', borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f5f4f1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {urls[k] ? (
                    isVideo(i.path, i.kind)
                      ? <video src={urls[k]} controls preload="metadata" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      : <img src={urls[k]} alt={autoCaption(i) || 'library item'} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  ) : <span style={{ fontSize: 12, opacity: 0.5 }}>loading…</span>}
                </div>

                {editKey === k ? (
                  <div style={{ display: 'flex', gap: 6 }}>
                    <input className="pt-input" type="text" value={editText} autoFocus
                      onChange={(e) => setEditText(e.target.value)}
                      onKeyDown={(e) => { if (e.key === 'Enter') saveCaption(i); if (e.key === 'Escape') setEditKey(null); }}
                      style={{ flex: 1, fontSize: 12, padding: '5px 8px', borderRadius: 6, border: '1px solid var(--ad-outline, #d8d8de)' }} />
                    <button className="ad-btn ad-btn--sm" onClick={() => saveCaption(i)}>Save</button>
                  </div>
                ) : (
                  <div style={{ fontSize: 13, opacity: i.caption ? 0.9 : 0.5, cursor: 'pointer' }} title="Tap to edit the caption"
                    onClick={() => { setEditKey(k); setEditText(i.caption || ''); }}>
                    {i.caption || autoCaption(i) || 'No caption. Tap to add one.'}
                  </div>
                )}

                {/* Share controls: Team toggle + Website state. Pulling either keeps the master. */}
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <button className={'ad-btn ad-btn--sm ' + (i.team ? '' : 'ad-btn--ghost')}
                    onClick={() => act(() => librarySetTeam(i.source, i.id, !i.team))}
                    title={i.team ? 'In the Team gallery. Tap to remove the copy.' : 'Add a copy to the Team gallery.'}>
                    {i.team ? 'Team ✓' : 'Team'}
                  </button>
                  {i.web === 'none' && (
                    <button className="ad-btn ad-btn--sm ad-btn--ghost"
                      onClick={() => act(() => librarySuggestWebsite(i.source, i.id))}
                      title="Suggest for the public website. You approve it in the Website tab.">Website</button>
                  )}
                  {i.web === 'queued' && (
                    <button className="ad-btn ad-btn--sm ad-btn--ghost"
                      onClick={() => act(() => libraryWithdrawWebsite(i.source, i.id))}
                      title="Waiting in the Website tab for your approval. Tap to cancel.">Website: waiting ✕</button>
                  )}
                  {i.web === 'live' && (
                    <button className="ad-btn ad-btn--sm"
                      onClick={() => act(() => libraryUnpublishWebsite(i.source, i.id))}
                      title="Live on the public website. Tap to pull it (the master stays in Assets).">On website ✕</button>
                  )}
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 6 }}>
                  <span className="ad-mono" style={{ fontSize: 11, opacity: 0.55 }}>
                    {i.source === 'upload' ? 'Uploaded' : 'From a visit'}
                  </span>
                  <button onClick={() => remove(i)} title={i.source === 'upload' ? 'Delete this file for good' : 'Remove from the library (stays in the visit)'}
                    style={{ display: 'flex', alignItems: 'center', gap: 4, background: 'none', border: 'none', cursor: 'pointer', color: 'var(--ad-danger, #c0392b)', fontSize: 12, padding: '2px 4px' }}>
                    <span style={{ fontSize: 15, lineHeight: 1 }}>✕</span> Delete
                  </button>
                </div>
              </div>
            );
          })}
        </div>
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
  if (items.length === 0) return <div className="ad-panel" style={{ opacity: 0.6 }}>No team photos yet. Tap Team on any visit photo, or share an Asset to the team.</div>;
  return (
    <div style={GRID}>
      {items.map((i) => {
        const k = itemKey(i);
        return (
          <figure key={k} className="ad-panel" style={{ padding: 8, margin: 0 }}>
            <div style={{ aspectRatio: '1 / 1', borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f5f4f1)' }}>
              {urls[k]
                ? <a href={urls[k]} target="_blank" rel="noreferrer"><img src={urls[k]} alt={autoCaption(i)} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /></a>
                : <span style={{ fontSize: 11, opacity: 0.5 }}>…</span>}
            </div>
            <figcaption style={{ fontSize: 12, opacity: 0.7, marginTop: 6, display: 'flex', justifyContent: 'space-between', gap: 6 }}>
              <span>{autoCaption(i)}</span>
              {i.website_state === 'live' && <span title="Live on the website" style={{ color: 'var(--ad-warn, #b9770a)' }}>web</span>}
            </figcaption>
          </figure>
        );
      })}
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

  async function act(fn) {
    setBusy(true); setErr(null);
    try { await fn(); await load(); }
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
      await libraryApproveWebsite(i.source, i.id, url);
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
          ['Approve', 'This photo goes live on your public website for everyone to see.'],
          ['Reject', 'It never reaches the website and leaves this list. The original stays in Assets.'],
          ['Pull from website', 'On a live photo below: it comes off the public website right away. The original stays in Assets.'],
        ]} />
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8, paddingRight: 24 }}>
          Waiting for your approval ({queued.length})
        </div>
        {queued.length === 0 ? (
          <div style={{ fontSize: 13, opacity: 0.6 }}>Nothing waiting. Suggest a photo from a visit or from Assets; it lands here for you.</div>
        ) : (
          <div style={GRID}>
            {queued.map((i) => {
              const k = itemKey(i);
              return (
                <figure key={k} className="ad-panel" style={{ padding: 8, margin: 0 }}>
                  <div style={{ aspectRatio: '1 / 1', borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f5f4f1)' }}>
                    {qUrls[k]
                      ? <a href={qUrls[k]} target="_blank" rel="noreferrer"><img src={qUrls[k]} alt={autoCaption(i)} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /></a>
                      : <span style={{ fontSize: 11, opacity: 0.5 }}>…</span>}
                  </div>
                  <figcaption style={{ fontSize: 12, opacity: 0.7, margin: '6px 0' }}>
                    {autoCaption(i)}{i.proposed_by ? ` · by ${i.proposed_by}` : ''}
                  </figcaption>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button className="ad-btn ad-btn--sm" disabled={busy} onClick={() => approve(i)}>Approve</button>
                    <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => act(() => libraryWithdrawWebsite(i.source, i.id))}>Reject</button>
                  </div>
                </figure>
              );
            })}
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
            {live.map((i) => {
              const k = itemKey(i);
              return (
                <figure key={k} className="ad-panel" style={{ padding: 8, margin: 0 }}>
                  <div style={{ aspectRatio: '1 / 1', borderRadius: 8, overflow: 'hidden', background: 'var(--ad-surface-container, #f5f4f1)' }}>
                    {lUrls[k]
                      ? <a href={lUrls[k]} target="_blank" rel="noreferrer"><img src={lUrls[k]} alt={autoCaption(i)} loading="lazy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /></a>
                      : <span style={{ fontSize: 11, opacity: 0.5 }}>…</span>}
                  </div>
                  <figcaption style={{ fontSize: 12, opacity: 0.7, margin: '6px 0' }}>{autoCaption(i)}</figcaption>
                  <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => act(() => libraryUnpublishWebsite(i.source, i.id))}>Pull from website</button>
                </figure>
              );
            })}
          </div>
        )}
        <div style={{ fontSize: 11, opacity: 0.55, marginTop: 10 }}>
          The public gallery shows the newest {cap}. Approving more rolls the oldest off on its own.
        </div>
      </div>
    </>
  );
}
