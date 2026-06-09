// src/components/admin/PricingView.jsx
//
// The Pricing floor: the locked city price grid in one place. Read-only by
// design; prices are a settled decision (no_unilateral_deviation), so changing
// them stays a deliberate act, not a casual edit on a dashboard.

import { useCallback, useEffect, useState } from 'react';
import { pricingGrid } from './supabase.js';

function money(cents) { return cents == null ? '—' : '$' + (cents / 100).toLocaleString('en-US'); }

export default function PricingView() {
  const [cities, setCities] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setCities(await pricingGrid()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  if (error) return <><h1>Pricing</h1><div className="ad-error">{error}</div></>;
  if (loading || !cities) return <><h1>Pricing</h1><div className="ad-panel">Loading…</div></>;

  return (
    <>
      <h1>Pricing</h1>
      <p className="ad-sub">The locked price grid by city. Prices are a settled decision, so this is a read-only view; changes are made deliberately, not from a dashboard.</p>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        {cities.map((c) => (
          <div key={c.name} className="ad-panel" style={{ opacity: c.active ? 1 : 0.6 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
              <strong style={{ fontSize: 16 }}>{c.name}, {c.state}</strong>
              <span style={{ fontSize: 12, color: c.active ? 'var(--ad-good, #1f8a4b)' : 'var(--ad-text-faint, #8b8f9e)' }}>{c.active ? 'live' : 'not live'}</span>
            </div>
            <table className="ad-table">
              <thead>
                <tr><th></th><th style={{ textAlign: 'right' }}>Recurring</th><th style={{ textAlign: 'right' }}>Single</th><th style={{ textAlign: 'right' }}>Founders</th><th style={{ textAlign: 'right' }}>Minutes</th></tr>
              </thead>
              <tbody>
                <tr>
                  <td>Smooth coat</td>
                  <td style={{ textAlign: 'right' }} className="ad-mono">{money(c.smoothcoat_recurring_cents)}</td>
                  <td style={{ textAlign: 'right' }} className="ad-mono">{money(c.smoothcoat_single_cents)}</td>
                  <td style={{ textAlign: 'right' }} className="ad-mono">{money(c.founders_smoothcoat_cents)}</td>
                  <td style={{ textAlign: 'right', opacity: 0.7 }} className="ad-mono">{c.smoothcoat_minutes ?? '—'}</td>
                </tr>
                <tr>
                  <td>Double coat</td>
                  <td style={{ textAlign: 'right' }} className="ad-mono">{money(c.doublecoat_recurring_cents)}</td>
                  <td style={{ textAlign: 'right' }} className="ad-mono">{money(c.doublecoat_single_cents)}</td>
                  <td style={{ textAlign: 'right' }} className="ad-mono">{money(c.founders_doublecoat_cents)}</td>
                  <td style={{ textAlign: 'right', opacity: 0.7 }} className="ad-mono">{c.doublecoat_minutes ?? '—'}</td>
                </tr>
              </tbody>
            </table>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, marginTop: 8, fontSize: 12, opacity: 0.75 }}>
              <span>Each additional dog: <strong>{money(c.addon_decrement_cents)} off</strong></span>
              <span>Founders cap: <strong>{c.founders_cap ?? '—'}</strong></span>
              <span>Slot: <strong>{c.slot_minutes ?? '—'}m</strong></span>
              <span>Buffer: <strong>{c.buffer_minutes ?? '—'}m</strong></span>
              <span>Min stop: <strong>{c.min_stop_minutes ?? '—'}m</strong></span>
              <span>Horizon: <strong>{c.booking_horizon_days ?? '—'}d</strong></span>
              <span>{c.timezone}</span>
            </div>
          </div>
        ))}
        {cities.length === 0 && <div className="ad-panel">No cities configured yet.</div>}
      </div>
    </>
  );
}
