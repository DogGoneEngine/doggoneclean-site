// src/components/admin/ComplianceView.jsx
//
// The Compliance department: insurance, licenses, registrations, A2P, processor
// verifications, tax dates. Each carries a renewal date; a daily watchdog flags
// anything due or overdue into the Today feed. Fill the dates and it watches.

import { useCallback, useEffect, useState } from 'react';
import { listCompliance, upsertComplianceItem, deleteComplianceItem, runComplianceCheck } from './supabase.js';
import HelpToggle from './Help.jsx';

const CATS = ['insurance', 'license', 'registration', 'tax', 'a2p', 'processor_verification', 'permit', 'other'];
const STATUSES = ['active', 'pending', 'expired', 'na'];

function dueLabel(days) {
  if (days == null) return { text: 'no date set', color: 'var(--ad-warn, #b9770a)' };
  if (days < 0) return { text: `${-days}d overdue`, color: 'var(--ad-bad, #dc2626)' };
  if (days <= 14) return { text: `due in ${days}d`, color: 'var(--ad-bad, #dc2626)' };
  if (days <= 45) return { text: `due in ${days}d`, color: 'var(--ad-warn, #b9770a)' };
  return { text: `in ${days}d`, color: 'var(--ad-text-dim, #565b6c)' };
}

export default function ComplianceView() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [adding, setAdding] = useState(false);
  const [checkMsg, setCheckMsg] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await listCompliance()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function runCheck() {
    setCheckMsg('Checking…');
    try { const r = await runComplianceCheck(); setCheckMsg(r.alerts_created > 0 ? `${r.alerts_created} alert(s) sent to Today.` : 'Nothing due. All clear.'); }
    catch (e) { setCheckMsg(e.message || 'check_failed'); }
  }

  return (
    <>
      <h1>Compliance</h1>
      <p className="ad-sub">Insurance, licenses, registrations, and verifications. Set the renewal dates and the watchdog catches them before they lapse.</p>

      {data && (
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap', marginBottom: 14 }}>
          <Pill n={data.overdue} label="overdue" tone="bad" />
          <Pill n={data.due_soon} label="due within 45 days" tone="warn" />
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={runCheck}>Run check now</button>
          {checkMsg && <span style={{ fontSize: 13, opacity: 0.7 }}>{checkMsg}</span>}
        </div>
      )}

      {error && <div className="ad-error">{error}</div>}
      {loading || !data ? (
        <div className="ad-panel">Loading…</div>
      ) : (
        <div className="ad-panel" style={{ display: 'flex', flexDirection: 'column', gap: 6, position: 'relative' }}>
          <HelpToggle corner items={[
            ['Add item / Edit', 'Track an insurance, license, registration, or tax item. Set its renewal date and the watchdog flags it before it lapses.'],
            ['Run check now', 'Looks at every date right now and drops anything due or overdue onto Today.'],
          ]} />
          {data.items.map((it) => <Row key={it.id} item={it} onChanged={load} />)}
          {adding
            ? <Row item={null} onChanged={() => { setAdding(false); load(); }} onCancel={() => setAdding(false)} />
            : <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ alignSelf: 'flex-start', marginTop: 4 }} onClick={() => setAdding(true)}>+ Add item</button>}
        </div>
      )}
    </>
  );
}

function Pill({ n, label, tone }) {
  const color = tone === 'bad' ? 'var(--ad-bad, #dc2626)' : 'var(--ad-warn, #b9770a)';
  return (
    <span style={{ fontSize: 14 }}>
      <strong style={{ color: n > 0 ? color : 'inherit', fontSize: 18 }}>{n}</strong> <span style={{ opacity: 0.7 }}>{label}</span>
    </span>
  );
}

function Row({ item, onChanged, onCancel }) {
  const [editing, setEditing] = useState(!item);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [f, setF] = useState({
    name: item?.name ?? '', category: item?.category ?? 'insurance', status: item?.status ?? 'pending',
    renewalDate: item?.renewal_date ?? '', provider: item?.provider ?? '', reference: item?.reference ?? '',
    notes: item?.notes ?? '', active: item?.active ?? true,
  });
  const set = (k) => (e) => setF((p) => ({ ...p, [k]: e.target.type === 'checkbox' ? e.target.checked : e.target.value }));

  async function save() {
    setBusy(true); setError(null);
    try {
      await upsertComplianceItem({ id: item?.id ?? null, name: f.name, category: f.category, status: f.status,
        renewalDate: f.renewalDate || null, provider: f.provider || null, reference: f.reference || null, notes: f.notes || null, active: f.active });
      setEditing(false); onChanged();
    } catch (e) { setError(e.message || 'save_failed'); }
    finally { setBusy(false); }
  }
  async function remove() {
    setBusy(true);
    try { await deleteComplianceItem(item.id); onChanged(); }
    catch (e) { setError(e.message || 'delete_failed'); setBusy(false); }
  }

  if (!editing && item) {
    const d = dueLabel(item.days_until);
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)', opacity: item.active ? 1 : 0.5 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <strong style={{ fontSize: 14 }}>{item.name}</strong>
          <span className="ad-mono" style={{ fontSize: 11, opacity: 0.55, marginLeft: 6 }}>{item.category}</span>
          {item.provider ? <span style={{ fontSize: 12, opacity: 0.6 }}> · {item.provider}</span> : null}
          {item.notes ? <div style={{ fontSize: 12, opacity: 0.6 }}>{item.notes}</div> : null}
        </div>
        <span style={{ fontSize: 13, color: d.color, whiteSpace: 'nowrap' }}>{item.renewal_date ? d.text : 'set a date'}</span>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center', padding: '6px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)' }}>
      <input className="ad-input" placeholder="name" value={f.name} onChange={set('name')} style={{ flex: '2 1 160px' }} />
      <select className="ad-select" value={f.category} onChange={set('category')}>{CATS.map((c) => <option key={c} value={c}>{c}</option>)}</select>
      <input className="ad-input" type="date" value={f.renewalDate} onChange={set('renewalDate')} title="renewal date" />
      <select className="ad-select" value={f.status} onChange={set('status')}>{STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}</select>
      <input className="ad-input" placeholder="provider" value={f.provider} onChange={set('provider')} style={{ width: 120 }} />
      <input className="ad-input" placeholder="notes" value={f.notes} onChange={set('notes')} style={{ flex: '1 1 120px' }} />
      <label style={{ fontSize: 12, display: 'flex', alignItems: 'center', gap: 3 }}><input type="checkbox" checked={f.active} onChange={set('active')} /> active</label>
      <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{item ? 'Save' : 'Add'}</button>
      {item && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={remove} disabled={busy}>Remove</button>}
      {!item && onCancel && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={onCancel}>Cancel</button>}
      {error && <span className="ad-error" style={{ fontSize: 12 }}>{error}</span>}
    </div>
  );
}
