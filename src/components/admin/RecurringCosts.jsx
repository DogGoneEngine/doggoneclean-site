// src/components/admin/RecurringCosts.jsx
//
// The recurring-costs tracker: every monthly/annual subscription and fee that
// runs the business (tech stack, domains, processors), with its amount, cadence,
// and billing day, so the total monthly burn lives here instead of in Paul's
// head. Rendered inside Finance.

import { useCallback, useEffect, useState } from 'react';
import { listRecurringCosts, upsertRecurringCost, deleteRecurringCost } from './supabase.js';

const CATS = ['infrastructure', 'ai', 'software', 'payments', 'domains', 'insurance', 'marketing', 'other'];
const CADENCES = ['monthly', 'quarterly', 'yearly', 'weekly', 'usage'];
function money(cents) { return cents == null ? '' : '$' + Math.round(cents / 100).toLocaleString('en-US'); }

export default function RecurringCosts() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [adding, setAdding] = useState(false);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await listRecurringCosts()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  return (
    <div className="ad-panel" style={{ marginTop: 4 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', flexWrap: 'wrap', gap: 8 }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Recurring costs</div>
        {data && (
          <div style={{ textAlign: 'right' }}>
            <span style={{ fontSize: 22, fontWeight: 700 }}>{money(data.monthly_fixed_cents)}/mo</span>
            <span style={{ fontSize: 12, opacity: 0.6, marginLeft: 8 }}>{money(data.annual_fixed_cents)}/yr fixed</span>
          </div>
        )}
      </div>
      {data && (data.items_missing_amount > 0 || data.usage_based_count > 0) && (
        <div style={{ fontSize: 12, opacity: 0.7, marginTop: 4 }}>
          {data.items_missing_amount > 0 && `${data.items_missing_amount} item(s) still need an amount. `}
          {data.usage_based_count > 0 && `${data.usage_based_count} usage-based (variable, not in the fixed total).`}
        </div>
      )}
      {error && <div className="ad-error" style={{ marginTop: 6 }}>{error}</div>}

      {loading || !data ? (
        <div style={{ marginTop: 8 }}>Loading…</div>
      ) : (
        <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 6 }}>
          {data.items.map((it) => <CostRow key={it.id} item={it} onChanged={load} />)}
          {adding
            ? <CostRow item={null} onChanged={() => { setAdding(false); load(); }} onCancel={() => setAdding(false)} />
            : <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ alignSelf: 'flex-start', marginTop: 4 }} onClick={() => setAdding(true)}>+ Add cost</button>}
        </div>
      )}
    </div>
  );
}

function CostRow({ item, onChanged, onCancel }) {
  const [editing, setEditing] = useState(!item);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [f, setF] = useState({
    name: item?.name ?? '',
    category: item?.category ?? 'software',
    amount: item?.amount_cents != null ? (item.amount_cents / 100).toString() : '',
    cadence: item?.cadence ?? 'monthly',
    billingDay: item?.billing_day ?? '',
    vendor: item?.vendor ?? '',
    notes: item?.notes ?? '',
    active: item?.active ?? true,
  });
  const set = (k) => (e) => setF((p) => ({ ...p, [k]: e.target.type === 'checkbox' ? e.target.checked : e.target.value }));

  async function save() {
    setBusy(true); setError(null);
    try {
      await upsertRecurringCost({
        id: item?.id ?? null, name: f.name, category: f.category,
        amountCents: f.amount === '' ? null : Math.round(parseFloat(f.amount) * 100),
        cadence: f.cadence, billingDay: f.billingDay === '' ? null : parseInt(f.billingDay, 10),
        vendor: f.vendor || null, notes: f.notes || null, active: f.active,
      });
      setEditing(false); onChanged();
    } catch (e) { setError(e.message || 'save_failed'); }
    finally { setBusy(false); }
  }
  async function remove() {
    setBusy(true);
    try { await deleteRecurringCost(item.id); onChanged(); }
    catch (e) { setError(e.message || 'delete_failed'); setBusy(false); }
  }

  if (!editing && item) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)', opacity: item.active ? 1 : 0.5 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <strong style={{ fontSize: 14 }}>{item.name}</strong>
          <span className="ad-mono" style={{ fontSize: 11, opacity: 0.55, marginLeft: 6 }}>{item.category}</span>
          {item.billing_day ? <span style={{ fontSize: 11, opacity: 0.6, marginLeft: 6 }}>· billed day {item.billing_day}</span> : null}
          {item.notes ? <div style={{ fontSize: 12, opacity: 0.6 }}>{item.notes}</div> : null}
        </div>
        <div style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
          {item.cadence === 'usage'
            ? <span className="ad-mono" style={{ fontSize: 12, opacity: 0.6 }}>usage</span>
            : item.amount_cents == null
              ? <span style={{ fontSize: 12, color: 'var(--ad-warn, #b9770a)' }}>set amount</span>
              : <span className="ad-mono">{money(item.amount_cents)}<span style={{ opacity: 0.5 }}>/{item.cadence === 'monthly' ? 'mo' : item.cadence === 'yearly' ? 'yr' : item.cadence}</span></span>}
        </div>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center', padding: '6px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)' }}>
      <input className="ad-input" placeholder="name" value={f.name} onChange={set('name')} style={{ flex: '2 1 140px' }} />
      <select className="ad-select" value={f.category} onChange={set('category')}>{CATS.map((c) => <option key={c} value={c}>{c}</option>)}</select>
      <input className="ad-input" type="number" step="0.01" min="0" placeholder="$" value={f.amount} onChange={set('amount')} style={{ width: 90 }} />
      <select className="ad-select" value={f.cadence} onChange={set('cadence')}>{CADENCES.map((c) => <option key={c} value={c}>{c}</option>)}</select>
      <input className="ad-input" type="number" min="1" max="31" placeholder="day" value={f.billingDay} onChange={set('billingDay')} style={{ width: 64 }} title="billing day of month" />
      <label style={{ fontSize: 12, display: 'flex', alignItems: 'center', gap: 3 }}><input type="checkbox" checked={f.active} onChange={set('active')} /> active</label>
      <input className="ad-input" placeholder="notes" value={f.notes} onChange={set('notes')} style={{ flex: '1 1 120px' }} />
      <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{item ? 'Save' : 'Add'}</button>
      {item && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={remove} disabled={busy}>Remove</button>}
      {!item && onCancel && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={onCancel}>Cancel</button>}
      {error && <span className="ad-error" style={{ fontSize: 12 }}>{error}</span>}
    </div>
  );
}
