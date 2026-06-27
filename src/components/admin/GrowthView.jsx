// src/components/admin/GrowthView.jsx
//
// The Growth floor. The win-back picture: who has lapsed past their own rhythm
// and is winnable, whether the calendar has room to take them, and a one-tap
// re-check. The win-back agent posts the most-overdue few into Today; this floor
// shows the whole list and the calendar context behind it.

import { useCallback, useEffect, useState } from 'react';
import { growthSummary, runWinbackCheck } from './supabase.js';

export default function GrowthView() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [checkMsg, setCheckMsg] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await growthSummary()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function runCheck() {
    setCheckMsg('Checking…');
    try { const r = await runWinbackCheck(); setCheckMsg(r.alerts_created > 0 ? `${r.alerts_created} sent to Today.` : 'Nothing new to surface.'); load(); }
    catch (e) { setCheckMsg(e.message || 'check_failed'); }
  }

  if (error) return <><h1>Growth</h1><div className="ad-error">{error}</div></>;
  if (loading || !data) return <><h1>Growth</h1><div className="ad-panel">Loading…</div></>;

  const cand = data.candidates || [];
  const wait = data.waitlist || [];
  return (
    <>
      <h1>Growth</h1>
      <p className="ad-sub">Win-backs, timed to each client's own rhythm and the calendar. Re-engagement goes out as an opt-in coat-care email, never a text.</p>

      <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap', marginBottom: 14 }}>
        <div className="ad-panel" style={{ padding: '10px 14px' }}>
          <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>Calendar, next 14 days</div>
          <div style={{ fontSize: 20, fontWeight: 700, marginTop: 2 }}>
            {data.upcoming_14d} / {data.capacity_14d}{' '}
            <span style={{ fontSize: 13, fontWeight: 400, color: data.has_room ? 'var(--ad-good, #1f8a4b)' : 'var(--ad-bad, #dc2626)' }}>
              {data.has_room ? 'room to win back' : 'full, hold win-backs'}
            </span>
          </div>
        </div>
        <div className="ad-panel" style={{ padding: '10px 14px' }}>
          <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>Winnable now</div>
          <div style={{ fontSize: 20, fontWeight: 700, marginTop: 2 }}>{cand.length}</div>
        </div>
        <div className="ad-panel" style={{ padding: '10px 14px' }}>
          <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>Waitlist signups</div>
          <div style={{ fontSize: 20, fontWeight: 700, marginTop: 2 }}>{wait.length}</div>
        </div>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={runCheck}>Run check now</button>
        {checkMsg && <span style={{ fontSize: 13, opacity: 0.7 }}>{checkMsg}</span>}
      </div>

      <div className="ad-panel" style={{ marginBottom: 14 }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Waitlist</div>
        {wait.length === 0 ? (
          <div style={{ opacity: 0.7 }}>No one has joined a city waitlist yet. New signups land here and ping you on Today the moment they come in.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            {wait.map((w, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, padding: '4px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)' }}>
                <span style={{ width: 110, fontWeight: 600 }}>{w.city}</span>
                <span className="ad-mono" style={{ flex: 1, minWidth: 0, fontSize: 12, opacity: w.email ? 0.85 : 0.45, color: w.email ? 'inherit' : 'var(--ad-warn, #b9770a)' }}>
                  {w.email || 'no email'}
                  {(w.zip_code || w.dog_count) && (
                    <span style={{ opacity: 0.55, marginLeft: 6 }}>
                      {w.zip_code || ''}{w.zip_code && w.dog_count ? ' · ' : ''}{w.dog_count ? `${w.dog_count} dog${w.dog_count === 1 ? '' : 's'}` : ''}
                    </span>
                  )}
                </span>
                <span style={{ fontSize: 12, opacity: 0.55, whiteSpace: 'nowrap' }}>{w.joined}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="ad-panel">
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Win-back candidates</div>
        {cand.length === 0 ? (
          <div style={{ opacity: 0.7 }}>No one is due for a win-back inside the window right now.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            {cand.map((c, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, padding: '4px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)' }}>
                <span style={{ width: 56, textAlign: 'right', opacity: 0.6 }}>{c.days_since}d</span>
                <span style={{ flex: 1, minWidth: 0 }}>
                  <strong>{c.name}</strong>
                  <span className="ad-mono" style={{ fontSize: 11, opacity: 0.5, marginLeft: 6 }}>{c.kind}{c.cadence_days ? ` · ${c.cadence_days}d` : ''}</span>
                </span>
                <span className="ad-mono" style={{ fontSize: 12, opacity: c.email ? 0.7 : 0.45, color: c.email ? 'inherit' : 'var(--ad-warn, #b9770a)' }}>
                  {c.email || 'no email on file'}
                </span>
              </div>
            ))}
          </div>
        )}
        <div style={{ fontSize: 12, opacity: 0.55, marginTop: 8 }}>
          The agent posts the most-overdue few into Today as they come due. The opt-in coat-care email send is the next piece to wire.
        </div>
      </div>
    </>
  );
}
