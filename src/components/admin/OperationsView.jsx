// src/components/admin/OperationsView.jsx
//
// The Operations / Field floor: the trailer and gear, each with a service
// interval. The maintenance watcher flags anything overdue into Today before it
// fails on a route. Set the last-service date and interval and it watches.

import { useCallback, useEffect, useState } from 'react';
import { listEquipment, upsertEquipment, deleteEquipment, runMaintenanceCheck, adminInfraStatus } from './supabase.js';
import GeneratorsPanel from './GeneratorsPanel.jsx';
import MaintenancePanel from './MaintenancePanel.jsx';

const CATS = ['trailer', 'tow_vehicle', 'generator', 'bath_system', 'dryer', 'clippers', 'rotary', 'water_system', 'other'];

function dueLabel(days) {
  if (days == null) return { text: 'set interval', color: 'var(--ad-warn, #b9770a)' };
  if (days < 0) return { text: `${-days}d overdue`, color: 'var(--ad-bad, #dc2626)' };
  if (days <= 7) return { text: `due in ${days}d`, color: 'var(--ad-bad, #dc2626)' };
  if (days <= 14) return { text: `due in ${days}d`, color: 'var(--ad-warn, #b9770a)' };
  return { text: `in ${days}d`, color: 'var(--ad-text-dim, #565b6c)' };
}

export default function OperationsView() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [adding, setAdding] = useState(false);
  const [checkMsg, setCheckMsg] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await listEquipment()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function runCheck() {
    setCheckMsg('Checking…');
    try { const r = await runMaintenanceCheck(); setCheckMsg(r.alerts_created > 0 ? `${r.alerts_created} alert(s) sent to Today.` : 'Nothing due. All serviced.'); }
    catch (e) { setCheckMsg(e.message || 'check_failed'); }
  }

  return (
    <>
      <h1>Operations</h1>
      <p className="ad-sub">The trailer and gear. Set each item's last service and interval, and the maintenance watcher catches what is due before it strands you on a route.</p>

      {data && (
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap', marginBottom: 14 }}>
          <Pill n={data.overdue} label="overdue" tone="bad" />
          <Pill n={data.due_soon} label="due within 14 days" tone="warn" />
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={runCheck}>Run check now</button>
          {checkMsg && <span style={{ fontSize: 13, opacity: 0.7 }}>{checkMsg}</span>}
        </div>
      )}

      <InfraPanel />

      <h2 style={{ marginBottom: 4 }}>Generators and power</h2>
      <p className="ad-sub" style={{ marginTop: 0 }}>Tracked by engine hours. Enter the watts each appliance draws to see how much capacity is free on each generator.</p>
      <GeneratorsPanel />

      <h2 style={{ marginTop: 8, marginBottom: 4 }}>Maintenance schedule</h2>
      <p className="ad-sub" style={{ marginTop: 0 }}>Generator service by hours and appliance filters by days. Hit Done when you do one and its cycle resets.</p>
      <MaintenancePanel />

      <h2 style={{ marginTop: 16, marginBottom: 4 }}>Other equipment</h2>
      {error && <div className="ad-error">{error}</div>}
      {loading || !data ? (
        <div className="ad-panel">Loading…</div>
      ) : (
        <div className="ad-panel" style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {data.items.map((it) => <Row key={it.id} item={it} onChanged={load} />)}
          {adding
            ? <Row item={null} onChanged={() => { setAdding(false); load(); }} onCancel={() => setAdding(false)} />
            : <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ alignSelf: 'flex-start', marginTop: 4 }} onClick={() => setAdding(true)}>+ Add equipment</button>}
        </div>
      )}
    </>
  );
}

function Pill({ n, label, tone }) {
  const color = tone === 'bad' ? 'var(--ad-bad, #dc2626)' : 'var(--ad-warn, #b9770a)';
  return <span style={{ fontSize: 14 }}><strong style={{ color: n > 0 ? color : 'inherit', fontSize: 18 }}>{n}</strong> <span style={{ opacity: 0.7 }}>{label}</span></span>;
}

function Row({ item, onChanged, onCancel }) {
  const [editing, setEditing] = useState(!item);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [f, setF] = useState({
    name: item?.name ?? '', category: item?.category ?? 'generator',
    lastServiceDate: item?.last_service_date ?? '', intervalDays: item?.interval_days ?? '',
    provider: item?.provider ?? '', notes: item?.notes ?? '', active: item?.active ?? true,
  });
  const set = (k) => (e) => setF((p) => ({ ...p, [k]: e.target.type === 'checkbox' ? e.target.checked : e.target.value }));

  async function save() {
    setBusy(true); setError(null);
    try {
      await upsertEquipment({ id: item?.id ?? null, name: f.name, category: f.category,
        lastServiceDate: f.lastServiceDate || null, intervalDays: f.intervalDays === '' ? null : parseInt(f.intervalDays, 10),
        provider: f.provider || null, notes: f.notes || null, active: f.active });
      setEditing(false); onChanged();
    } catch (e) { setError(e.message || 'save_failed'); }
    finally { setBusy(false); }
  }
  async function remove() {
    setBusy(true);
    try { await deleteEquipment(item.id); onChanged(); }
    catch (e) { setError(e.message || 'delete_failed'); setBusy(false); }
  }

  if (!editing && item) {
    const d = dueLabel(item.days_until);
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)', opacity: item.active ? 1 : 0.5 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <strong style={{ fontSize: 14 }}>{item.name}</strong>
          <span className="ad-mono" style={{ fontSize: 11, opacity: 0.55, marginLeft: 6 }}>{item.category}</span>
          {item.interval_days ? <span style={{ fontSize: 12, opacity: 0.6 }}> · every {item.interval_days}d</span> : null}
          {item.notes ? <div style={{ fontSize: 12, opacity: 0.6 }}>{item.notes}</div> : null}
        </div>
        <span style={{ fontSize: 13, color: d.color, whiteSpace: 'nowrap' }}>{d.text}</span>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center', padding: '6px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)' }}>
      <input className="ad-input" placeholder="name" value={f.name} onChange={set('name')} style={{ flex: '2 1 150px' }} />
      <select className="ad-select" value={f.category} onChange={set('category')}>{CATS.map((c) => <option key={c} value={c}>{c}</option>)}</select>
      <label style={{ fontSize: 11, opacity: 0.6 }}>last <input className="ad-input" type="date" value={f.lastServiceDate} onChange={set('lastServiceDate')} /></label>
      <label style={{ fontSize: 11, opacity: 0.6 }}>every <input className="ad-input" type="number" min="1" placeholder="days" value={f.intervalDays} onChange={set('intervalDays')} style={{ width: 70 }} />d</label>
      <input className="ad-input" placeholder="notes" value={f.notes} onChange={set('notes')} style={{ flex: '1 1 120px' }} />
      <label style={{ fontSize: 12, display: 'flex', alignItems: 'center', gap: 3 }}><input type="checkbox" checked={f.active} onChange={set('active')} /> active</label>
      <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{item ? 'Save' : 'Add'}</button>
      {item && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={remove} disabled={busy}>Remove</button>}
      {!item && onCancel && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={onCancel}>Cancel</button>}
      {error && <span className="ad-error" style={{ fontSize: 12 }}>{error}</span>}
    </div>
  );
}

// Live infrastructure usage against plan limits: the database and storage
// behind everything. The daily infra watcher cards Today at 70% of a limit;
// this panel is the always-current view (with the droplet noted honestly as
// not yet instrumented).
function InfraPanel() {
  const [infra, setInfra] = useState(null);
  const [err, setErr] = useState(null);
  useEffect(() => {
    adminInfraStatus().then(setInfra).catch((e) => setErr(e.message || 'infra_failed'));
  }, []);
  const mb = (b) => b == null ? null : (b / 1048576);
  const fmt = (b) => {
    const m = mb(b);
    if (m == null) return 'n/a';
    return m >= 1024 ? `${(m / 1024).toFixed(1)} GB` : `${Math.max(1, Math.round(m))} MB`;
  };
  const pct = (b, limitMb) => {
    const m = mb(b);
    return m == null || !limitMb ? null : Math.round((m / limitMb) * 100);
  };
  return (
    <div className="ad-panel" style={{ marginBottom: 16 }}>
      <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Infrastructure</div>
      {err && <div className="ad-error">{err}</div>}
      {!infra ? (!err && <div style={{ fontSize: 13, opacity: 0.6 }}>Measuring…</div>) : (
        <>
          <div style={{ display: 'flex', gap: 18, flexWrap: 'wrap', fontSize: 14 }}>
            <span><strong>{fmt(infra.db_bytes)}</strong> <span style={{ opacity: 0.6 }}>database ({pct(infra.db_bytes, infra.db_limit_mb)}% of {Math.round(infra.db_limit_mb)} MB plan)</span></span>
            <span><strong>{fmt(infra.storage_bytes)}</strong> <span style={{ opacity: 0.6 }}>photo storage, {infra.storage_objects} files ({pct(infra.storage_bytes, infra.storage_limit_mb)}% of {Math.round(infra.storage_limit_mb)} MB plan)</span></span>
          </div>
          <div style={{ fontSize: 12, opacity: 0.55, marginTop: 6 }}>
            The infra watcher checks daily and cards Today at 70% of a plan limit.
          </div>
          {(infra.inventory || []).length > 0 && (
            <div style={{ marginTop: 12 }}>
              <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 4 }}>Every limit we live under</div>
              <table className="ad-table" style={{ fontSize: 13 }}>
                <tbody>
                  {(infra.inventory || []).map((l, i) => (
                    <tr key={i} title={l.note || ''}>
                      <td style={{ whiteSpace: 'nowrap' }}><strong>{l.service}</strong></td>
                      <td>{l.item}</td>
                      <td className="ad-mono" style={{ whiteSpace: 'nowrap' }}>{l.limit_label}</td>
                      <td className="ad-mono" style={{ textAlign: 'right', whiteSpace: 'nowrap',
                        color: l.pct == null ? 'inherit' : l.pct >= 70 ? 'var(--ad-bad, #dc2626)' : 'var(--ad-good, #1f8a4b)' }}>
                        {l.used == null
                          ? <span style={{ opacity: 0.5 }}>dashboard only</span>
                          : l.unit === 'usd'
                            ? `$${l.used}${l.period ? ' this ' + l.period : ''}`
                            : `${Number(l.used).toLocaleString('en-US')}${l.unit === 'mb' ? ' MB' : ''}${l.pct != null ? ` (${l.pct}%)` : ''}`}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <div style={{ fontSize: 12, opacity: 0.55, marginTop: 4 }}>
                Long-press a row for the note. "Dashboard only" rows cannot be measured from inside the app; their limits are tracked here so none is discovered by hitting it.
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
