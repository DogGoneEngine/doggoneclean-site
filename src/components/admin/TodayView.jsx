// src/components/admin/TodayView.jsx
//
// Today: the crystal ball. The standing feed of briefings from the AI
// department heads (the CFO is live first) sits here, newest first. Each
// briefing leads with a recommendation and its evidence; you read it, dismiss
// it, or approve its recommended action. The AI proposes; your click decides.

import { useCallback, useEffect, useState } from 'react';
import { listBriefings, setBriefingStatus, listAgents } from './supabase.js';

const SEV = {
  alert:  { color: '#dc2626', label: 'Alert' },
  signal: { color: '#2563d8', label: 'Signal' },
  info:   { color: '#1f8a4b', label: 'Info' },
};

function money(c) { return c == null ? null : '$' + (c / 100).toFixed(2).replace(/\.00$/, ''); }

export default function TodayView() {
  const [briefings, setBriefings] = useState([]);
  const [agents, setAgents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const [b, a] = await Promise.all([listBriefings(), listAgents()]);
      setBriefings(b.filter((x) => x.status === 'new' || x.status === 'read'));
      setAgents(a);
    } catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function act(id, status) {
    try { await setBriefingStatus(id, status); load(); }
    catch (e) { setError(e.message || 'action_failed'); }
  }

  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
  const activeHeads = agents.filter((a) => a.is_active).map((a) => a.label);

  return (
    <>
      <h1>Today</h1>
      <p className="ad-sub">{today}. Your department heads work around the clock and leave their findings here.</p>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Department heads</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
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
      </div>

      {error && <div className="ad-error">{error}</div>}

      {loading ? (
        <div className="ad-panel">Loading the feed…</div>
      ) : briefings.length === 0 ? (
        <div className="ad-panel" style={{ opacity: 0.7 }}>
          No open briefings. {activeHeads.length ? `${activeHeads.join(', ')} ${activeHeads.length === 1 ? 'is' : 'are'} watching.` : 'Bring a department head online to start the feed.'}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {briefings.map((b) => {
            const sev = SEV[b.severity] || SEV.info;
            const ev = b.evidence || {};
            return (
              <div key={b.id} className="ad-panel" style={{ borderLeft: `4px solid ${sev.color}` }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
                  <strong style={{ fontSize: 16 }}>{b.title}</strong>
                  <span className="ad-mono" style={{ fontSize: 11, color: sev.color }}>{sev.label} · {b.agent_key.toUpperCase()}</span>
                </div>
                {b.body && <p style={{ margin: '8px 0', fontSize: 14, lineHeight: 1.5 }}>{b.body}</p>}
                {Object.keys(ev).length > 0 && (
                  <div className="ad-mono" style={{ fontSize: 11, opacity: 0.65, display: 'flex', flexWrap: 'wrap', gap: 10 }}>
                    {ev.visits != null && <span>visits {ev.visits}</span>}
                    {ev.clients != null && <span>clients {ev.clients}</span>}
                    {ev.priced_visits != null && <span>priced {ev.priced_visits}</span>}
                    {ev.revenue_cents != null && <span>collected {money(ev.revenue_cents)}</span>}
                    {ev.revenue_per_hour != null && <span>rev/hr ${ev.revenue_per_hour}</span>}
                    {ev.no_shows != null && ev.no_shows > 0 && <span>no-shows {ev.no_shows}</span>}
                    {ev.ar_count != null && ev.ar_count > 0 && <span>A/R {ev.ar_count} ({money(ev.ar_cents)})</span>}
                  </div>
                )}
                <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
                  {b.recommended_action && (
                    <button className="ad-btn ad-btn--sm" onClick={() => act(b.id, 'approved')}>Approve</button>
                  )}
                  <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => act(b.id, 'dismissed')}>Dismiss</button>
                  {b.status === 'new' && (
                    <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => act(b.id, 'read')}>Mark read</button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </>
  );
}
