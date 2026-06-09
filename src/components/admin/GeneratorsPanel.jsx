// src/components/admin/GeneratorsPanel.jsx
//
// Generators and power. Each generator is tracked by engine hours (read off the
// panel), carries its Predator 5000 service tasks (hours-based), and shows the
// live electrical load of the appliances on it against its 3900W capacity, so
// Paul knows the headroom before plugging in anything new.

import { useCallback, useEffect, useState } from 'react';
import { powerSummary, updateEquipmentHours, setPower } from './supabase.js';

export default function GeneratorsPanel() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await powerSummary()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  if (error) return <div className="ad-error">{error}</div>;
  if (loading || !data) return <div className="ad-panel">Loading generators…</div>;

  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 14, marginBottom: 18 }}>
      {(data.generators || []).map((g) => <Generator key={g.id} g={g} onChanged={load} />)}
    </div>
  );
}

function Generator({ g, onChanged }) {
  const [hours, setHours] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const load = g.load_watts ?? 0;
  const rated = g.rated_watts ?? 0;
  const pct = rated > 0 ? Math.min(100, Math.round((load / rated) * 100)) : 0;
  const headroom = rated - load;
  const barColor = pct >= 90 ? 'var(--ad-bad, #dc2626)' : pct >= 70 ? 'var(--ad-warn, #b9770a)' : 'var(--ad-good, #1f8a4b)';

  async function saveHours() {
    if (hours === '') return;
    setBusy(true); setError(null);
    try { await updateEquipmentHours(g.id, parseFloat(hours)); setHours(''); onChanged(); }
    catch (e) { setError(e.message || 'save_failed'); } finally { setBusy(false); }
  }

  return (
    <div className="ad-panel">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <strong style={{ fontSize: 16 }}>{g.name}</strong>
        <span style={{ fontSize: 12, opacity: 0.6 }}>{g.side ? `${g.side} side` : 'side: confirm'}</span>
      </div>

      {/* Engine hours */}
      <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
        <span style={{ fontSize: 13 }}>Engine hours: <strong>{g.current_hours != null ? Math.round(g.current_hours) : '—'}</strong></span>
        <input className="ad-input" type="number" min="0" step="1" placeholder="from panel" value={hours} onChange={(e) => setHours(e.target.value)} style={{ width: 110 }} />
        <button className="ad-btn ad-btn--sm" onClick={saveHours} disabled={busy || hours === ''}>Update</button>
        {g.hours_updated_at && <span style={{ fontSize: 11, opacity: 0.5 }}>updated {new Date(g.hours_updated_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</span>}
      </div>
      {error && <div className="ad-error" style={{ fontSize: 12, marginTop: 4 }}>{error}</div>}

      {/* Power load */}
      <div style={{ marginTop: 12 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 3 }}>
          <span>Load {load}W of {rated}W</span>
          <span style={{ color: headroom < 0 ? 'var(--ad-bad,#dc2626)' : 'inherit' }}>{headroom}W free</span>
        </div>
        <div style={{ height: 8, background: 'var(--ad-surface-container, #f0f0f3)', borderRadius: 5 }}>
          <div style={{ height: 8, width: `${pct}%`, background: barColor, borderRadius: 5 }} />
        </div>
      </div>

      {/* Appliances with editable draw */}
      <div style={{ marginTop: 12 }}>
        <Cap>On this generator</Cap>
        {(g.appliances || []).map((a) => <ApplianceRow key={a.id} a={a} onChanged={onChanged} />)}
      </div>

      {/* Maintenance tasks (hours-based) */}
      <div style={{ marginTop: 12 }}>
        <Cap>Service (hours-based)</Cap>
        {(g.tasks || []).map((t) => {
          const rem = t.hours_remaining;
          const due = rem != null && rem <= 0;
          const soon = rem != null && rem > 0 && rem <= 10;
          return (
            <div key={t.id} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, padding: '2px 0' }}>
              <span>{t.task} <span style={{ opacity: 0.5 }}>every {t.interval_hours}h</span></span>
              <span style={{ color: due ? 'var(--ad-bad,#dc2626)' : soon ? 'var(--ad-warn,#b9770a)' : 'var(--ad-text-dim,#565b6c)' }}>
                {g.current_hours == null ? 'enter hours' : due ? 'due now' : `${Math.round(rem)}h left`}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function ApplianceRow({ a, onChanged }) {
  const [w, setW] = useState(a.watts ?? '');
  const [busy, setBusy] = useState(false);
  async function save() {
    if (w === '' || parseInt(w, 10) === a.watts) return;
    setBusy(true);
    try { await setPower(a.id, { watts: parseInt(w, 10) }); onChanged(); } finally { setBusy(false); }
  }
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 13, padding: '2px 0' }}>
      <span style={{ flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{a.name}</span>
      <input className="ad-input" type="number" min="0" placeholder="W" value={w} onChange={(e) => setW(e.target.value)} onBlur={save} disabled={busy}
        style={{ width: 70, fontSize: 12, padding: '2px 4px', textAlign: 'right' }} title="watts drawn" />
    </div>
  );
}
function Cap({ children }) { return <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55, marginBottom: 3 }}>{children}</div>; }
