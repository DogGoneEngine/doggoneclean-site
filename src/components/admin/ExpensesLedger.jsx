// src/components/admin/ExpensesLedger.jsx
//
// The business account's money-out, from the imported statements. Total spend,
// the category and monthly breakdown, and the recent transactions. Everything
// imported counts as a business expense by default; untick the rare non-business
// outlier, and add by hand a business charge that hit a personal card.

import { useCallback, useEffect, useState } from 'react';
import { expenseSummary, addExpense, setExpenseBusiness, setExpenseCategory, exportExpenses } from './supabase.js';

function toCsv(rows) {
  const cols = ['txn_date', 'description', 'amount', 'category', 'is_business', 'source', 'notes'];
  const esc = (v) => { const s = v == null ? '' : String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
  return [cols.join(','), ...rows.map((r) => cols.map((c) => esc(r[c])).join(','))].join('\n');
}
function downloadCsv(name, text) {
  const blob = new Blob([text], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = name; a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

const CATS = ['supplies', 'fuel', 'equipment', 'software', 'infrastructure', 'ai', 'payments', 'domains', 'insurance', 'marketing', 'meals', 'wages', 'other'];
function money(cents) { return cents == null ? '$0' : '$' + Math.round(cents / 100).toLocaleString('en-US'); }
function fmt(d) { try { return new Date(d + 'T12:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' }); } catch { return d; } }

export default function ExpensesLedger({ refreshSignal = 0 }) {
  const [data, setData] = useState(null);
  const [windowDays, setWindowDays] = useState(90);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [adding, setAdding] = useState(false);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await expenseSummary(windowDays)); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, [windowDays]);
  useEffect(() => { load(); }, [load, refreshSignal]);

  async function toggleBusiness(id, val) { try { await setExpenseBusiness(id, val); load(); } catch (e) { setError(e.message); } }
  async function changeCat(id, cat) { try { await setExpenseCategory(id, cat); load(); } catch (e) { setError(e.message); } }

  const maxCat = data ? Math.max(1, ...(data.by_category || []).map((c) => c.cents)) : 1;

  return (
    <div className="ad-panel" style={{ marginTop: 4 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', flexWrap: 'wrap', gap: 8 }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Expense ledger</div>
        <div style={{ display: 'flex', gap: 6 }}>
          {[30, 90, 365].map((d) => (
            <button key={d} className={'ad-btn ad-btn--sm ' + (windowDays === d ? '' : 'ad-btn--ghost')} onClick={() => setWindowDays(d)}>{d === 365 ? '1y' : `${d}d`}</button>
          ))}
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={async () => {
            try { const rows = await exportExpenses(); if (!rows.length) { setError('No expenses to export yet.'); return; } downloadCsv(`dgc-expenses-${new Date().toISOString().slice(0,10)}.csv`, toCsv(rows)); }
            catch (e) { setError(e.message || 'export_failed'); }
          }} title="Export all expenses as CSV for your accountant">Export CSV</button>
        </div>
      </div>
      {error && <div className="ad-error" style={{ marginTop: 6 }}>{error}</div>}
      {loading || !data ? (
        <div style={{ marginTop: 8 }}>Loading…</div>
      ) : (
        <>
          <div style={{ marginTop: 8 }}>
            <span style={{ fontSize: 26, fontWeight: 700 }}>{money(data.total_business_cents)}</span>
            <span style={{ fontSize: 13, opacity: 0.6, marginLeft: 8 }}>spent · {data.business_count} expenses{data.excluded_count ? ` · ${data.excluded_count} excluded` : ''}</span>
          </div>

          {(data.by_category || []).length > 0 && (
            <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 6 }}>
              {data.by_category.map((c) => (
                <div key={c.category}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 2 }}>
                    <span>{c.category} <span style={{ opacity: 0.5 }}>· {c.n}</span></span>
                    <span className="ad-mono">{money(c.cents)}</span>
                  </div>
                  <div style={{ height: 6, background: 'var(--ad-surface-container, #f0f0f3)', borderRadius: 4 }}>
                    <div style={{ height: 6, width: `${(c.cents / maxCat) * 100}%`, background: 'var(--ad-primary, #2563d8)', borderRadius: 4 }} />
                  </div>
                </div>
              ))}
            </div>
          )}

          {(data.by_month || []).length > 0 && (
            <table className="ad-table" style={{ marginTop: 12 }}>
              <tbody>
                {data.by_month.map((m) => (
                  <tr key={m.month}><td>{m.month}</td><td style={{ textAlign: 'right' }} className="ad-mono">{money(m.cents)}</td></tr>
                ))}
              </tbody>
            </table>
          )}

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 16, marginBottom: 4 }}>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Recent transactions</div>
            {!adding && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setAdding(true)}>+ Add (personal-card expense)</button>}
          </div>
          {adding && <AddExpense onDone={() => { setAdding(false); load(); }} onCancel={() => setAdding(false)} />}

          <div style={{ display: 'flex', flexDirection: 'column', gap: 2, maxHeight: '50vh', overflow: 'auto' }}>
            {(data.recent || []).map((r) => (
              <div key={r.id} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, padding: '3px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)', opacity: r.is_business ? 1 : 0.45 }}>
                <label title="business expense?"><input type="checkbox" checked={r.is_business} onChange={(e) => toggleBusiness(r.id, e.target.checked)} /></label>
                <span style={{ width: 64, opacity: 0.6, fontSize: 12 }}>{fmt(r.txn_date)}</span>
                <span style={{ flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.description}{r.source === 'manual' ? <span style={{ opacity: 0.5, fontSize: 11 }}> · manual</span> : null}</span>
                <select className="ad-select" value={r.category} onChange={(e) => changeCat(r.id, e.target.value)} style={{ fontSize: 11, padding: '2px 4px' }}>
                  {CATS.map((c) => <option key={c} value={c}>{c}</option>)}
                </select>
                <span className="ad-mono" style={{ width: 70, textAlign: 'right' }}>{money(r.amount_cents)}</span>
              </div>
            ))}
            {(data.recent || []).length === 0 && <div style={{ opacity: 0.6, marginTop: 6 }}>No expenses yet. Import a statement to fill this in.</div>}
          </div>
        </>
      )}
    </div>
  );
}

function AddExpense({ onDone, onCancel }) {
  const today = new Date().toISOString().slice(0, 10);
  const [f, setF] = useState({ txnDate: today, description: '', amount: '', category: 'supplies', card: 'personal' });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const set = (k) => (e) => setF((p) => ({ ...p, [k]: e.target.value }));
  async function save() {
    setBusy(true); setError(null);
    try {
      await addExpense({ txnDate: f.txnDate, description: f.description, amountCents: Math.round(parseFloat(f.amount || '0') * 100), category: f.category, card: f.card });
      onDone();
    } catch (e) { setError(e.message || 'save_failed'); setBusy(false); }
  }
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center', marginBottom: 8 }}>
      <input className="ad-input" type="date" value={f.txnDate} onChange={set('txnDate')} />
      <input className="ad-input" placeholder="description" value={f.description} onChange={set('description')} style={{ flex: '1 1 140px' }} />
      <input className="ad-input" type="number" step="0.01" min="0" placeholder="$" value={f.amount} onChange={set('amount')} style={{ width: 90 }} />
      <select className="ad-select" value={f.category} onChange={set('category')}>{CATS.map((c) => <option key={c} value={c}>{c}</option>)}</select>
      <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>Add</button>
      <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={onCancel}>Cancel</button>
      {error && <span className="ad-error" style={{ fontSize: 12 }}>{error}</span>}
    </div>
  );
}
