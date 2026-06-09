// src/components/admin/HRView.jsx
//
// The HR floor. For a solo operator the honest content is the workload: how hard
// Paul is working, from real visit hours, held against the prime directive (earn
// more, grind less). It scales to a team roster when he hires.

import { useCallback, useEffect, useState } from 'react';
import { hrSummary, listAgents } from './supabase.js';

function money(c) { return c == null ? '$0' : '$' + Math.round(c / 100).toLocaleString('en-US'); }

export default function HRView() {
  const [data, setData] = useState(null);
  const [agents, setAgents] = useState([]);
  const [windowDays, setWindowDays] = useState(30);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const [d, a] = await Promise.all([hrSummary(windowDays), listAgents()]);
      setData(d); setAgents(a);
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
          <div className="ad-panel" style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>The team</div>
            <div style={{ marginTop: 6, fontSize: 15 }}><strong>Paul</strong> <span style={{ opacity: 0.6 }}>· owner-operator (sole)</span></div>
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
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 12 }}>
            <Stat label="Hours worked" value={data.hours != null ? `${data.hours}h` : 'n/a'} sub={`over ${data.work_days} work days`} big />
            <Stat label="Per work day" value={data.avg_hours_per_workday != null ? `${data.avg_hours_per_workday}h` : 'n/a'} sub={`${data.avg_visits_per_workday ?? 0} visits/day`} />
            <Stat label="Visits" value={String(data.visits)} sub={`in ${data.window_days} days`} />
            <Stat label="Earned" value={money(data.revenue)} sub="collected this window" />
          </div>

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
