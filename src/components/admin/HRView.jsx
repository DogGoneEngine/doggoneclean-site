// src/components/admin/HRView.jsx
//
// The HR floor. For a solo operator the honest content is the workload: how hard
// Paul is working, from real visit hours, held against the prime directive (earn
// more, grind less). It scales to a team roster when he hires.

import { useCallback, useEffect, useRef, useState } from 'react';
import { hrSummary, listAgents, listTeam, adminAgentCosts, setAdminPhoto, setAdminPhotoFromPath, setAdminBio, signedPhotoUrl, profilePhotoChoices } from './supabase.js';
import HelpToggle from './Help.jsx';

function money(c) { return c == null ? '$0' : '$' + Math.round(c / 100).toLocaleString('en-US'); }
function usd(n) { return '$' + Number(n || 0).toFixed(2); }

export default function HRView() {
  const [data, setData] = useState(null);
  const [agents, setAgents] = useState([]);
  const [team, setTeam] = useState([]);
  const [costs, setCosts] = useState(null);
  const [windowDays, setWindowDays] = useState(30);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const [d, a, t, c] = await Promise.all([
        hrSummary(windowDays), listAgents(),
        listTeam().catch(() => []), adminAgentCosts().catch(() => null),
      ]);
      setData(d); setAgents(a); setTeam(Array.isArray(t) ? t : []); setCosts(c);
    }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, [windowDays]);
  useEffect(() => { load(); }, [load]);

  return (
    <>
      <h1>HR</h1>
      <p className="ad-sub">One operator today: you. This floor watches the workload, because the directive is to earn more while grinding less. It grows into a team roster when you hire.</p>

      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        {[30, 90, 365].map((d) => (
          <button key={d} className={'ad-btn ad-btn--sm ' + (windowDays === d ? '' : 'ad-btn--ghost')} onClick={() => setWindowDays(d)}>{d === 365 ? '1 year' : `${d} days`}</button>
        ))}
      </div>

      {error && <div className="ad-error">{error}</div>}
      {loading || !data ? (
        <div className="ad-panel">Adding up the hours…</div>
      ) : (
        <>
          <div className="ad-panel" style={{ marginBottom: 16, position: 'relative' }}>
            <HelpToggle corner items={[
              ['Tap the circle', "Sets a teammate's profile photo, the face clients see on the tracker. Upload from your phone, or pick one from the Library."],
              ['edit (bio)', 'Changes the short bio shown next to that person on the client tracker.'],
              ['30 / 90 / 1 year', 'Changes how far back the workload numbers below reach.'],
            ]} />
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>The team</div>
            {(team.length ? team : [{ id: 'paul', first_name: 'Paul', title: 'Owner and Hurricane Bath Operator', signed_in: true }]).map((m) => (
              <TeamMember key={m.id} m={m} onChanged={load} />
            ))}
          </div>

          <div className="ad-panel" style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>AI department heads</div>
            <div style={{ fontSize: 12, opacity: 0.6, marginBottom: 8 }}>Your around-the-clock staff. They watch their floors and leave findings on Today; they recommend, they never act on their own.</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {agents.length === 0 && <span style={{ fontSize: 13, opacity: 0.6 }}>No agents registered yet.</span>}
              {agents.map((a) => (
                <span key={a.agent_key} className="ad-mono" style={{
                  fontSize: 12, padding: '3px 9px', borderRadius: 8,
                  background: a.is_active ? 'var(--ad-primary-container, #e6edfc)' : 'var(--ad-surface-container, #f5f4f1)',
                  opacity: a.is_active ? 1 : 0.55,
                }} title={a.description || ''}>
                  {a.label}{a.is_active ? '' : ' · dormant'}
                </span>
              ))}
            </div>
            <div style={{ marginTop: 12, borderTop: '1px solid var(--ad-outline, #e3e1dc)', paddingTop: 10 }}>
              <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>What they cost</div>
              {!costs ? (
                <div style={{ fontSize: 13, opacity: 0.6 }}>No cost data yet.</div>
              ) : (
                <>
                  <div style={{ display: 'flex', gap: 18, flexWrap: 'wrap', fontSize: 14 }}>
                    <span><strong>{usd(costs.cost_30d)}</strong> <span style={{ opacity: 0.6 }}>last 30 days</span></span>
                    <span><strong>{usd(costs.projected_month)}</strong> <span style={{ opacity: 0.6 }}>projected next month</span></span>
                    <span><strong>{usd(costs.cost_all_time)}</strong> <span style={{ opacity: 0.6 }}>all time logged</span></span>
                  </div>
                  {(costs.agents || []).length > 0 && (
                    <div style={{ marginTop: 8 }}>
                      {(costs.agents || []).map((a) => (
                        <div key={a.agent_key} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, padding: '2px 0' }}>
                          <span className="ad-mono">{a.agent_key}</span>
                          <span style={{ opacity: 0.75 }}>{a.runs_30d} runs · {usd(a.cost_30d)} <span style={{ opacity: 0.6 }}>/ 30d</span></span>
                        </div>
                      ))}
                    </div>
                  )}
                  <div style={{ fontSize: 12, opacity: 0.55, marginTop: 6 }}>
                    Token usage logging started 2026-06-11, so all-time means since then. Agents that run as plain database jobs (the availability watcher, the charge cron, the calendar sync) cost effectively nothing and are not listed.
                  </div>
                </>
              )}
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 12 }}>
            <Stat label="Door-to-door / day" value={data.avg_door_to_door_per_workday != null ? `${data.avg_door_to_door_per_workday}h` : 'n/a'}
              sub={data.door_to_door_days ? `first stop to last, over ${data.door_to_door_days} clocked days` : 'needs clocked arrive/depart times'} big />
            <Stat label="Hands-on / day" value={data.avg_hands_on_per_workday != null ? `${data.avg_hands_on_per_workday}h` : 'n/a'}
              sub={`dog grooming time · ${data.avg_visits_per_workday ?? 0} visits/day`} big />
            <Stat label="Hours worked" value={data.hours != null ? `${data.hours}h` : 'n/a'} sub={`hands-on, over ${data.work_days} work days`} />
            <Stat label="Visits" value={String(data.visits)} sub={`in ${data.window_days} days`} />
            <Stat label="Earned" value={money(data.revenue)} sub="collected this window" />
          </div>

          {data.untimed_visits > 0 && (
            <div className="ad-panel" style={{ marginTop: 12, fontSize: 13, opacity: 0.8 }}>
              {data.untimed_visits} {data.untimed_visits === 1 ? 'visit' : 'visits'} in this window {data.untimed_visits === 1 ? 'has' : 'have'} no time recorded yet, so {data.untimed_visits === 1 ? 'it is' : 'they are'} left out of the hour averages above. Logging arrive and depart times (or saying how long a job took when you capture it by voice) fills the gap, and these numbers climb toward the real day.
            </div>
          )}

          {data.busiest_day && (
            <div className="ad-panel" style={{ marginTop: 16 }}>
              <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Hardest day</div>
              <div style={{ marginTop: 4, fontSize: 14 }}>{data.busiest_day.date}: <strong>{data.busiest_day.hours}h</strong> across {data.busiest_day.visits} visits</div>
            </div>
          )}

          <div className="ad-panel" style={{ marginTop: 16, opacity: 0.85 }}>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 4 }}>When to hire</div>
            <p style={{ fontSize: 13, margin: 0, lineHeight: 1.5 }}>
              The signal to bring on help is when the hours-per-day stay high and the calendar stays full week after week, with win-backs waiting on room. Those numbers live for real once the bath book fills with real bookings; until then this is a baseline. When the day comes, this floor becomes the team roster, schedules, and commission split.
            </p>
          </div>
        </>
      )}
    </>
  );
}

function Stat({ label, value, sub, big }) {
  return (
    <div className="ad-panel" style={{ padding: '14px 16px' }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>{label}</div>
      <div style={{ fontSize: big ? 30 : 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
      {sub && <div style={{ fontSize: 12, marginTop: 2, opacity: 0.65 }}>{sub}</div>}
    </div>
  );
}


// One human on the roster, with the profile photo and bio the tracker shows
// to clients (admins.photo_path / bio). Upload a face, edit the words, done;
// the tracker follows with zero code changes.
function TeamMember({ m, onChanged }) {
  const [thumb, setThumb] = useState(null);
  const [busy, setBusy] = useState(false);
  const [editingBio, setEditingBio] = useState(false);
  const [bio, setBio] = useState(m.bio || '');
  const [err, setErr] = useState(null);
  // Tapping the circle opens a small chooser (phone upload vs the Library)
  // rather than jumping straight to the phone picker, so the Library is
  // discoverable at the tap. libItems null = not loaded yet.
  const [pickerOpen, setPickerOpen] = useState(false);
  const [libOpen, setLibOpen] = useState(false);
  const [libItems, setLibItems] = useState(null);
  const [libUrls, setLibUrls] = useState({});
  const fileRef = useRef(null);

  useEffect(() => {
    let alive = true;
    if (m.photo_path) signedPhotoUrl(m.photo_path).then((u) => { if (alive) setThumb(u); }).catch(() => {});
    return () => { alive = false; };
  }, [m.photo_path]);

  async function pick(e) {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    setBusy(true); setErr(null);
    try { await setAdminPhoto(m.id, file); onChanged(); }
    catch (x) { setErr(x.message || 'upload_failed'); }
    finally { setBusy(false); }
  }
  async function openLibrary() {
    setPickerOpen(false);
    setLibOpen(true);
    if (libItems) return;
    setErr(null);
    try {
      const items = await profilePhotoChoices();
      setLibItems(items);
      // Sign every thumbnail once, up front, so there is no per-render signing
      // loop (the exact pattern that crashed the Library tab once).
      const entries = await Promise.all(items.map(async (it) => [it.id, await signedPhotoUrl(it.path).catch(() => null)]));
      setLibUrls(Object.fromEntries(entries));
    } catch (x) { setErr(x.message || 'load_failed'); setLibItems([]); }
  }
  async function chooseFromLibrary(path) {
    setBusy(true); setErr(null);
    try { await setAdminPhotoFromPath(m.id, path); setLibOpen(false); onChanged(); }
    catch (x) { setErr(x.message || 'save_failed'); }
    finally { setBusy(false); }
  }
  async function saveBio() {
    setBusy(true); setErr(null);
    try { await setAdminBio(m.id, bio); setEditingBio(false); onChanged(); }
    catch (x) { setErr(x.message || 'save_failed'); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', marginTop: 10 }}>
      <div style={{ flexShrink: 0, position: 'relative' }}>
        <button type="button" onClick={() => setPickerOpen((o) => !o)} disabled={busy}
          aria-label="Set profile photo" title="Set the profile photo clients see on the tracker"
          style={{ padding: 0, border: 0, background: 'transparent', cursor: 'pointer', borderRadius: '50%' }}>
          {thumb
            ? <img src={thumb} alt={m.first_name} style={{ width: 48, height: 48, borderRadius: '50%', objectFit: 'cover', border: '2px solid var(--ad-primary, #2563d8)', display: 'block' }} />
            : <span style={{ width: 48, height: 48, borderRadius: '50%', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', background: 'var(--ad-surface-container, #eef)', fontSize: 18, fontWeight: 700 }}>{(m.first_name || '?')[0]}</span>}
        </button>
        <input ref={fileRef} type="file" accept="image/*" onChange={(e) => { setPickerOpen(false); pick(e); }} disabled={busy} style={{ display: 'none' }} />
        {pickerOpen && (
          <div style={{ position: 'absolute', top: 54, left: 0, zIndex: 30, background: '#fff', border: '1px solid var(--ad-outline, #d8d8de)', borderRadius: 10, boxShadow: 'var(--ad-elev-1, 0 6px 20px rgba(0,0,0,0.12))', padding: 6, width: 190 }}>
            <button type="button" onClick={() => { setPickerOpen(false); fileRef.current && fileRef.current.click(); }}
              style={{ display: 'block', width: '100%', textAlign: 'left', padding: '9px 10px', border: 0, background: 'transparent', borderRadius: 7, fontSize: 13, cursor: 'pointer' }}>
              Upload from your phone
            </button>
            <button type="button" onClick={openLibrary}
              style={{ display: 'block', width: '100%', textAlign: 'left', padding: '9px 10px', border: 0, background: 'transparent', borderRadius: 7, fontSize: 13, cursor: 'pointer' }}>
              Choose from the Library
            </button>
          </div>
        )}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15 }}>
          <strong>{m.first_name}{m.last_name ? ` ${m.last_name}` : ''}</strong>{' '}
          <span style={{ opacity: 0.6 }}>· {m.title}{m.signed_in ? '' : ' · has not signed in yet'}</span>
        </div>
        {editingBio ? (
          <div style={{ marginTop: 4 }}>
            <textarea rows={2} value={bio} onChange={(e) => setBio(e.target.value)}
              style={{ width: '100%', fontSize: 13, padding: '6px 8px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', boxSizing: 'border-box', fontFamily: 'inherit' }} />
            <div style={{ display: 'flex', gap: 6, marginTop: 4 }}>
              <button className="ad-btn ad-btn--sm" onClick={saveBio} disabled={busy}>Save</button>
              <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setEditingBio(false); setBio(m.bio || ''); }}>Cancel</button>
            </div>
          </div>
        ) : (
          <div style={{ fontSize: 12, opacity: 0.7, marginTop: 2 }}>
            {m.bio || 'No bio yet.'}{' '}
            <button type="button" onClick={() => setEditingBio(true)}
              style={{ background: 'transparent', border: 0, padding: 0, fontSize: 12, color: 'var(--ad-text-dim,#565b6c)', textDecoration: 'underline', cursor: 'pointer' }}>edit</button>
          </div>
        )}
        {m.role !== 'viewer' && (
          <div style={{ fontSize: 11, opacity: 0.5, marginTop: 4 }}>
            Tap the circle to set the profile photo clients see on the tracker: upload from your phone, or choose one from the Library.
          </div>
        )}
        {libOpen && (
          <div style={{ marginTop: 8 }}>
            {libItems === null ? (
              <div style={{ fontSize: 12, opacity: 0.6 }}>Loading the Library…</div>
            ) : libItems.length === 0 ? (
              <div style={{ fontSize: 12, opacity: 0.6 }}>No shared photos yet. Photos shared to a client or the team show up here to pick from.</div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(64px, 1fr))', gap: 6, maxHeight: 240, overflowY: 'auto', padding: 2 }}>
                {libItems.map((it) => (
                  <button key={it.id} type="button" onClick={() => chooseFromLibrary(it.path)} disabled={busy}
                    title={[it.dog_name, it.client].filter(Boolean).join(' · ') || 'Library photo'}
                    style={{ padding: 0, border: '1px solid var(--ad-outline, #d8d8de)', borderRadius: 8, overflow: 'hidden', cursor: 'pointer', background: 'var(--ad-surface-container, #eef)', aspectRatio: '1' }}>
                    {libUrls[it.id]
                      ? <img src={libUrls[it.id]} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
                      : <span style={{ display: 'block', width: '100%', height: '100%' }} />}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
        {err && <div className="ad-error" style={{ fontSize: 12 }}>{err}</div>}
      </div>
    </div>
  );
}
