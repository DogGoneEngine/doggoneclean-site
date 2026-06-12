// src/components/admin/FamilyView.jsx
//
// The Family floor (family_window_into_the_business): Kristin's window. She
// is a stakeholder, not day-to-day, so this is all signal: how the business
// is really doing (the value gauge and its two health levers), what this
// month looks like, and where Paul is right now. No cards to act on, no
// settings, nothing that needs tending. The aim is a page worth glancing at
// over coffee, not another inbox.

import { useCallback, useEffect, useState } from 'react';
import { businessValue, financeSummary, todayAppointments } from './supabase.js';

const k = (c) => '$' + Math.round((c || 0) / 100).toLocaleString('en-US');
const STATUS_WORD = {
  confirmed: 'scheduled', tentative: 'penciled', requested: 'requested',
  on_the_way: 'on the way', on_site: 'in the driveway', in_service: 'in the bath',
  returning: 'coming back to the door', completed: 'done',
};

export default function FamilyView() {
  const [value, setValue] = useState(null);
  const [month, setMonth] = useState(null);
  const [stops, setStops] = useState([]);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [v, m, t] = await Promise.all([
        businessValue(), financeSummary(30), todayAppointments().catch(() => []),
      ]);
      setValue(v); setMonth(m); setStops(t || []);
    } catch (e) { setError(e.message || 'load_failed'); }
  }, []);
  useEffect(() => { load(); }, [load]);

  return (
    <>
      <h1>The family window</h1>
      <p className="ad-sub">How Dog Gone Clean is really doing, at a glance. This page asks nothing of you; it is just the truth, fresh every time you open it.</p>

      {error && <div className="ad-error">{error}</div>}

      {value && (
        <div className="ad-panel" style={{ marginBottom: 16, borderLeft: '4px solid var(--ad-primary, #2563d8)' }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>What the business is worth</div>
          <div style={{ fontSize: 32, fontWeight: 800, margin: '4px 0 2px' }}>
            {k(value.value_low_cents)} <span style={{ opacity: 0.45, fontWeight: 400 }}>to</span> {k(value.value_high_cents)}
          </div>
          <div style={{ display: 'flex', gap: 18, flexWrap: 'wrap', fontSize: 13, marginTop: 4 }}>
            <span><strong>{value.recurring_share_pct}%</strong> <span style={{ opacity: 0.6 }}>of revenue is clients who come back on a rhythm</span></span>
            {value.growth_pct != null && <span><strong>{value.growth_pct >= 0 ? '+' : ''}{value.growth_pct}%</strong> <span style={{ opacity: 0.6 }}>vs last year</span></span>}
          </div>
        </div>
      )}

      {month && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 12, marginBottom: 16 }}>
          <div className="ad-panel" style={{ padding: '14px 16px' }}>
            <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>Last 30 days</div>
            <div style={{ fontSize: 26, fontWeight: 700, marginTop: 4 }}>{k(month.revenue_cents)}</div>
            <div style={{ fontSize: 12, marginTop: 2, opacity: 0.65 }}>{month.visits} visits, {month.clients} households</div>
          </div>
          <div className="ad-panel" style={{ padding: '14px 16px' }}>
            <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>The rate that matters</div>
            <div style={{ fontSize: 26, fontWeight: 700, marginTop: 4 }}>{month.revenue_per_hour != null ? `$${month.revenue_per_hour}/hr` : 'building'}</div>
            <div style={{ fontSize: 12, marginTop: 2, opacity: 0.65 }}>earned per on-site hour</div>
          </div>
        </div>
      )}

      <div className="ad-panel">
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8 }}>Where Paul is today</div>
        {stops.length === 0 ? (
          <div style={{ fontSize: 14, opacity: 0.7 }}>No stops today. He is yours.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {stops.map((a) => (
              <div key={a.id} style={{ display: 'flex', gap: 10, fontSize: 14, alignItems: 'baseline' }}>
                <span className="ad-mono" style={{ width: 64, opacity: 0.7, flexShrink: 0 }}>
                  {new Date(a.scheduled_start).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
                </span>
                <span style={{ flex: 1 }}>
                  <strong>{a.client || 'A stop'}</strong>
                  {a.dog_count ? <span style={{ opacity: 0.6 }}> · {a.dog_count} dog{a.dog_count === 1 ? '' : 's'}</span> : null}
                </span>
                <span style={{ fontSize: 12, opacity: 0.7 }}>{STATUS_WORD[a.status] || a.status}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
}
