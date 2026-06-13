// src/components/admin/VendorsView.jsx
//
// The Vendors floor: the supplies you buy and who you buy them from. Mark a
// supply low or give it a reorder cadence, and the reorder watcher flags it in
// Today before you run out on a route. Hit Ordered to reset the clock.

import { useCallback, useEffect, useState } from 'react';
import { listSupplies, upsertSupply, supplyAction, runReorderCheck } from './supabase.js';
import HelpToggle from './Help.jsx';

const CATS = ['shampoo', 'towels', 'blades', 'tools', 'cleaning', 'consumables', 'office', 'other'];

function dueLabel(s) {
  if (s.low) return { text: 'low', color: 'var(--ad-bad, #dc2626)' };
  if (s.days_until == null) return { text: 'set cadence', color: 'var(--ad-text-faint, #8b8f9e)' };
  if (s.days_until < 0) return { text: `${-s.days_until}d overdue`, color: 'var(--ad-bad, #dc2626)' };
  if (s.days_until <= 7) return { text: `due in ${s.days_until}d`, color: 'var(--ad-warn, #b9770a)' };
  return { text: `in ${s.days_until}d`, color: 'var(--ad-text-dim, #565b6c)' };
}

export default function VendorsView() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [adding, setAdding] = useState(false);
  const [checkMsg, setCheckMsg] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await listSupplies()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function runCheck() {
    setCheckMsg('Checking…');
    try { const r = await runReorderCheck(); setCheckMsg(r.alerts_created > 0 ? `${r.alerts_created} sent to Today.` : 'Nothing to reorder.'); }
    catch (e) { setCheckMsg(e.message || 'check_failed'); }
  }

  return (
    <>
      <h1>Vendors</h1>
      <p className="ad-sub">Supplies and who you buy them from. Mark one low or give it a reorder cadence, and the watcher flags it before you run out.</p>

      {data && (
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap', marginBottom: 14 }}>
          <span style={{ fontSize: 14 }}><strong style={{ color: data.low > 0 ? 'var(--ad-bad,#dc2626)' : 'inherit', fontSize: 18 }}>{data.low}</strong> <span style={{ opacity: 0.7 }}>marked low</span></span>
          <span style={{ fontSize: 14 }}><strong style={{ fontSize: 18 }}>{data.due}</strong> <span style={{ opacity: 0.7 }}>due to reorder</span></span>
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
            ['Mark low', 'Flags the reorder on Today before you run out. Clear low once it is restocked.'],
            ['Ordered', 'Resets the reorder clock the moment you reorder, so the next reminder is timed right.'],
            ['Add supply / Edit', 'Add a supply or change its vendor, reorder link, and how often you reorder it.'],
            ['Run check now', 'Looks at everything right now and drops anything due onto your Today feed.'],
          ]} />
          {data.items.map((it) => <Row key={it.id} item={it} onChanged={load} />)}
          {adding
            ? <Row item={null} onChanged={() => { setAdding(false); load(); }} onCancel={() => setAdding(false)} />
            : <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ alignSelf: 'flex-start', marginTop: 4 }} onClick={() => setAdding(true)}>+ Add supply</button>}
        </div>
      )}
    </>
  );
}

function Row({ item, onChanged, onCancel }) {
  const [editing, setEditing] = useState(!item);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [f, setF] = useState({
    name: item?.name ?? '', category: item?.category ?? 'consumables', vendor: item?.vendor ?? '',
    reorderUrl: item?.reorder_url ?? '', intervalDays: item?.interval_days ?? '', notes: item?.notes ?? '', active: item?.active ?? true,
  });
  const set = (k) => (e) => setF((p) => ({ ...p, [k]: e.target.type === 'checkbox' ? e.target.checked : e.target.value }));

  async function act(action) {
    setBusy(true);
    try { await supplyAction(item.id, action); onChanged(); }
    catch (e) { setError(e.message || 'failed'); setBusy(false); }
  }
  async function save() {
    setBusy(true); setError(null);
    try {
      await upsertSupply({ id: item?.id ?? null, name: f.name, category: f.category, vendor: f.vendor || null,
        reorderUrl: f.reorderUrl || null, intervalDays: f.intervalDays === '' ? null : parseInt(f.intervalDays, 10), notes: f.notes || null, active: f.active });
      setEditing(false); onChanged();
    } catch (e) { setError(e.message || 'save_failed'); }
    finally { setBusy(false); }
  }

  if (!editing && item) {
    const d = dueLabel(item);
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '5px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)', opacity: item.active ? 1 : 0.5 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <strong style={{ fontSize: 14 }}>{item.name}</strong>
          <span className="ad-mono" style={{ fontSize: 11, opacity: 0.55, marginLeft: 6 }}>{item.category}</span>
          {item.vendor ? <span style={{ fontSize: 12, opacity: 0.6 }}> · {item.vendor}</span> : null}
          {item.interval_days ? <span style={{ fontSize: 12, opacity: 0.5 }}> · every {item.interval_days}d</span> : null}
        </div>
        <span style={{ fontSize: 13, color: d.color, whiteSpace: 'nowrap' }}>{d.text}</span>
        <button className="ad-btn ad-btn--sm" onClick={() => act('ordered')} disabled={busy} title="reset the reorder clock">Ordered</button>
        {item.low
          ? <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => act('not_low')} disabled={busy}>Clear low</button>
          : <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => act('low')} disabled={busy}>Mark low</button>}
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center', padding: '6px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)' }}>
      <input className="ad-input" placeholder="name" value={f.name} onChange={set('name')} style={{ flex: '2 1 140px' }} />
      <select className="ad-select" value={f.category} onChange={set('category')}>{CATS.map((c) => <option key={c} value={c}>{c}</option>)}</select>
      <input className="ad-input" placeholder="vendor" value={f.vendor} onChange={set('vendor')} style={{ width: 120 }} />
      <label style={{ fontSize: 11, opacity: 0.6 }}>every <input className="ad-input" type="number" min="1" placeholder="days" value={f.intervalDays} onChange={set('intervalDays')} style={{ width: 64 }} />d</label>
      <input className="ad-input" placeholder="reorder link" value={f.reorderUrl} onChange={set('reorderUrl')} style={{ flex: '1 1 120px' }} />
      <label style={{ fontSize: 12, display: 'flex', alignItems: 'center', gap: 3 }}><input type="checkbox" checked={f.active} onChange={set('active')} /> active</label>
      <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{item ? 'Save' : 'Add'}</button>
      {item && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => act('delete')} disabled={busy}>Remove</button>}
      {!item && onCancel && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={onCancel}>Cancel</button>}
      {error && <span className="ad-error" style={{ fontSize: 12 }}>{error}</span>}
    </div>
  );
}
