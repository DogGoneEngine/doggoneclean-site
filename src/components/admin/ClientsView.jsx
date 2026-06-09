// src/components/admin/ClientsView.jsx
//
// The Clients department: the contact-sheet database. The list is the book; the
// detail pane is one contact sheet, laid out the way Paul keeps it: the
// semi-permanent header (frequency, availability, location, per-dog specs) on
// top, the growing visit history below. "Log a visit" appends to the ledger.

import { useCallback, useEffect, useMemo, useState } from 'react';
import { listClients, getClient, logVisit, setClientNofly, listNofly, listArchivedClients, unarchiveClient, listAliases, addAlias, removeAlias } from './supabase.js';

const SERVICE_LABELS = {
  full_groom: 'Full groom',
  bath: 'Bath',
  nails: 'Nails',
  nails_only_legacy: 'Nails (legacy)',
  mixed_groom_and_nails: 'Groom + nails',
  nails_only: 'Nails only',
};

function money(cents) {
  if (cents === null || cents === undefined) return '';
  return '$' + (cents / 100).toFixed(2).replace(/\.00$/, '');
}

function fmtDate(ts) {
  if (!ts) return '';
  try {
    return new Date(ts).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
  } catch { return ts; }
}

// On a phone the master/detail layout stacked the contact sheet far below the
// list, so a tap looked like nothing happened. Below this width we switch to a
// single pane: the list, or the selected sheet with a back button.
function useIsNarrow(maxWidth = 760) {
  const [narrow, setNarrow] = useState(false);
  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return undefined;
    const mq = window.matchMedia(`(max-width: ${maxWidth}px)`);
    const on = () => setNarrow(mq.matches);
    on();
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, [maxWidth]);
  return narrow;
}

export default function ClientsView() {
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [query, setQuery] = useState('');
  const [selectedId, setSelectedId] = useState(null);
  const narrow = useIsNarrow();

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      setClients(await listClients());
    } catch (e) {
      setError(e.message || 'load_failed');
    } finally {
      setLoading(false);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return clients;
    return clients.filter((c) =>
      (c.name || '').toLowerCase().includes(q) ||
      (c.aka || '').toLowerCase().includes(q) ||
      (c.location_zone || '').toLowerCase().includes(q) ||
      (c.aliases || []).some((a) => (a || '').toLowerCase().includes(q)));
  }, [clients, query]);

  const showDetailOnly = narrow && selectedId;

  return (
    <>
      <h1>Clients</h1>
      {!showDetailOnly && (
        <p className="ad-sub">The contact-sheet book. {clients.length} active clients (seen within the past year). Pick one to open its sheet.</p>
      )}
      {!showDetailOnly && <NoFlyPanel onChanged={load} />}
      {!showDetailOnly && <ArchivedPanel onChanged={load} />}

      {showDetailOnly ? (
        <div>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setSelectedId(null)} style={{ marginBottom: 12 }}>← All clients</button>
          <ClientSheet clientId={selectedId} onChanged={load} />
        </div>
      ) : (
        <div style={{ display: 'flex', gap: 20, alignItems: 'flex-start', flexWrap: 'wrap' }}>
          <div style={{ flex: '1 1 320px', minWidth: narrow ? 0 : 280, maxWidth: narrow ? 'none' : 460, width: narrow ? '100%' : undefined }}>
            <input
              className="ad-input"
              placeholder="Search name, account, or zone"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              style={{ width: '100%', marginBottom: 12 }}
            />
            {error && <div className="ad-error">{error}</div>}
            {loading ? (
              <div className="ad-panel">Loading the book…</div>
            ) : (
              <div className="ad-panel" style={{ padding: 0, maxHeight: narrow ? 'none' : '70vh', overflow: 'auto' }}>
                <table className="ad-table">
                  <tbody>
                    {filtered.map((c) => (
                      <tr
                        key={c.id}
                        onClick={() => setSelectedId(c.id)}
                        style={{
                          cursor: 'pointer',
                          background: c.id === selectedId ? 'var(--ad-surface-container-high, #eef1fb)' : undefined,
                        }}
                      >
                        <td>
                          <strong>{c.name}</strong>
                          {c.aka ? <span className="ad-mono" style={{ marginLeft: 6, opacity: 0.6 }}>{c.aka}</span> : null}
                          <div style={{ fontSize: 12, opacity: 0.7 }}>
                            {SERVICE_LABELS[c.service_type] || c.service_type || 'service unset'}
                            {c.cadence_days ? ` · every ${c.cadence_days}d` : ''}
                            {c.location_zone ? ` · ${c.location_zone}` : ''}
                            {c.dog_count ? ` · ${c.dog_count} dog${c.dog_count === 1 ? '' : 's'}` : ''}
                          </div>
                        </td>
                        <td style={{ textAlign: 'right', fontSize: 12, whiteSpace: 'nowrap', opacity: 0.7 }}>
                          {c.last_visit_at ? fmtDate(c.last_visit_at) : <span style={{ opacity: 0.5 }}>no visits</span>}
                        </td>
                      </tr>
                    ))}
                    {filtered.length === 0 && (
                      <tr><td style={{ opacity: 0.6 }}>No clients match.</td></tr>
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {!narrow && (
            <div style={{ flex: '2 1 460px', minWidth: 320 }}>
              {selectedId
                ? <ClientSheet clientId={selectedId} onChanged={load} />
                : <div className="ad-panel" style={{ opacity: 0.7 }}>Select a client to open the contact sheet.</div>}
            </div>
          )}
        </div>
      )}
    </>
  );
}

function ClientSheet({ clientId, onChanged }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      setData(await getClient(clientId));
    } catch (e) {
      setError(e.message || 'load_failed');
    } finally {
      setLoading(false);
    }
  }, [clientId]);
  useEffect(() => { load(); }, [load]);

  if (loading) return <div className="ad-panel">Opening the sheet…</div>;
  if (error) return <div className="ad-panel"><div className="ad-error">{error}</div></div>;
  if (!data) return null;

  const c = data.client || {};
  const dogs = data.dogs || [];
  const visits = data.visits || [];
  const upcoming = data.upcoming || [];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {/* Semi-permanent header */}
      <div className="ad-panel">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', flexWrap: 'wrap', gap: 8 }}>
          <h2 style={{ margin: 0 }}>{c.name}{c.aka ? <span className="ad-mono" style={{ marginLeft: 8, opacity: 0.6, fontSize: 14 }}>{c.aka}</span> : null}</h2>
          <span className="ad-mono" style={{ fontSize: 12, opacity: 0.7 }}>{c.roster_group} · {c.status}</span>
        </div>
        <NoFlyControl client={c} onChanged={() => { load(); onChanged?.(); }} />
        <AliasManager clientId={clientId} onChanged={onChanged} />
        <dl style={{ display: 'grid', gridTemplateColumns: 'max-content 1fr', gap: '4px 14px', margin: '12px 0 0' }}>
          <Field label="Service" value={SERVICE_LABELS[c.service_type] || c.service_type} />
          <Field label="Frequency" value={c.cadence_days ? `every ${c.cadence_days} days${c.cadence_confidence ? ` (${c.cadence_confidence})` : ''}` : c.cadence_note} />
          <Field label="Hardness" value={c.hardness} />
          <Field label="Availability" value={c.availability_hard} />
          <Field label="Avoid" value={(c.availability_not_days || []).join(', ')} />
          <Field label="Seasonal" value={c.availability_seasonal} />
          <Field label="Location" value={c.location_address || c.location_zone} />
          <Field label="Plus codes" value={c.location_plus} />
          <Field label="Geo notes" value={c.location_geo_notes} />
          <Field label="Phone" value={c.phone_e164} />
          <Field label="Flags" value={(c.flags || []).join(', ')} />
          <Field label="Data gaps" value={(c.data_gaps || []).join(', ')} />
        </dl>
        {dogs.length > 0 && (
          <div style={{ marginTop: 14 }}>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Dogs</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
              {dogs.map((d) => (
                <div key={d.id} className="ad-mono" style={{ fontSize: 13, border: '1px solid var(--ad-outline, #d9dbe6)', borderRadius: 10, padding: '6px 10px' }}>
                  <strong>{d.name}</strong>{d.breed ? ` · ${d.breed}` : ''}{d.price_cents != null ? ` · ${money(d.price_cents)}` : ''}
                  {d.notes ? <div style={{ opacity: 0.7, marginTop: 2 }}>{d.notes}</div> : null}
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Log a visit */}
      <LogVisitForm
        clientId={clientId}
        subscriberId={data.subscriber?.id || null}
        defaultService={c.service_type}
        dogs={dogs}
        onLogged={() => { load(); onChanged?.(); }}
      />

      {/* Upcoming */}
      {upcoming.length > 0 && (
        <div className="ad-panel">
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8 }}>Upcoming</div>
          {upcoming.map((a) => (
            <div key={a.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', fontSize: 14 }}>
              <span>{fmtDate(a.scheduled_start)} · {SERVICE_LABELS[a.service_type] || a.service_type}</span>
              <span className="ad-mono" style={{ opacity: 0.7 }}>{a.status} · {money(a.amount_cents)}</span>
            </div>
          ))}
        </div>
      )}

      {/* Visit history (the growing bottom) */}
      <div className="ad-panel">
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8 }}>
          Visit history · {visits.length}
        </div>
        {visits.length === 0 ? (
          <div style={{ opacity: 0.6 }}>No visits logged yet. The history grows one row per appointment as it happens.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {visits.map((v) => (
              <div key={v.id} style={{ borderLeft: '3px solid var(--ad-primary, #2563d8)', paddingLeft: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: 6 }}>
                  <strong>{fmtDate(v.visited_at)}</strong>
                  <span className="ad-mono" style={{ fontSize: 12, opacity: 0.7 }}>
                    {SERVICE_LABELS[v.service_type] || v.service_type || ''}
                    {v.actual_minutes ? ` · ${v.actual_minutes} min` : ''}
                    {v.amount_collected_cents != null ? ` · ${money(v.amount_collected_cents)}` : ''}
                    {v.tip_cents ? ` (+${money(v.tip_cents)} tip)` : ''}
                  </span>
                </div>
                {(v.dog_ratings || []).length > 0 && (
                  <div style={{ marginTop: 4, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    {v.dog_ratings.map((r) => (
                      <span key={r.dog_id || r.name} title="vibe score (1 unsafe to 5 a joy)" style={{ fontSize: 12, display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                        {r.name || 'dog'} <ScoreDot score={r.score} />
                      </span>
                    ))}
                  </div>
                )}
                {v.work_done ? <div style={{ fontSize: 14, marginTop: 2 }}>{v.work_done}</div> : null}
                {v.visit_notes ? <div style={{ fontSize: 13, opacity: 0.75, marginTop: 2 }}>{v.visit_notes}</div> : null}
                {(v.condition_flags || []).length > 0 && (
                  <div style={{ marginTop: 4, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    {v.condition_flags.map((f) => (
                      <span key={f} className="ad-mono" style={{ fontSize: 11, background: 'var(--ad-surface-container-high, #eef1fb)', borderRadius: 6, padding: '1px 6px' }}>{f}</span>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function Field({ label, value }) {
  if (!value) return null;
  return (
    <>
      <dt style={{ fontSize: 12, opacity: 0.55, textTransform: 'uppercase', letterSpacing: 0.3 }}>{label}</dt>
      <dd style={{ margin: 0, fontSize: 14 }}>{value}</dd>
    </>
  );
}

function ScoreDot({ score }) {
  // 1 roughest (red) to 5 a joy (green).
  const colors = { 1: '#dc2626', 2: '#d97706', 3: '#b9770a', 4: '#3f9142', 5: '#1f8a4b' };
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 18, height: 18, borderRadius: '50%', background: colors[score] || '#565b6c', color: '#fff', fontSize: 11, fontWeight: 700 }}>{score}</span>
  );
}

function LogVisitForm({ clientId, subscriberId, defaultService, dogs, onLogged }) {
  const [open, setOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const today = new Date().toISOString().slice(0, 10);
  const [form, setForm] = useState({
    visitedAt: today,
    serviceType: ['full_groom', 'bath', 'nails'].includes(defaultService) ? defaultService : 'bath',
    workDone: '',
    visitNotes: '',
    actualMinutes: '',
    amount: '',
    paymentMethod: '',
  });

  const [scores, setScores] = useState({});
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.value }));

  async function submit(e) {
    e.preventDefault();
    setSaving(true); setError(null);
    try {
      const dogScores = Object.entries(scores)
        .filter(([, s]) => s)
        .map(([dog_id, score]) => ({ dog_id, score }));
      await logVisit({
        clientId,
        subscriberId,
        visitedAt: form.visitedAt ? new Date(form.visitedAt + 'T12:00:00').toISOString() : null,
        serviceType: form.serviceType,
        workDone: form.workDone || null,
        visitNotes: form.visitNotes || null,
        actualMinutes: form.actualMinutes ? parseInt(form.actualMinutes, 10) : null,
        amountCollectedCents: form.amount ? Math.round(parseFloat(form.amount) * 100) : null,
        paymentMethod: form.paymentMethod || null,
        dogIds: dogScores.length ? dogScores.map((d) => d.dog_id) : null,
        dogScores: dogScores.length ? dogScores : null,
        source: 'manual',
      });
      setForm((f) => ({ ...f, workDone: '', visitNotes: '', actualMinutes: '', amount: '' }));
      setScores({});
      setOpen(false);
      onLogged?.();
    } catch (err) {
      setError(err.message || 'save_failed');
    } finally {
      setSaving(false);
    }
  }

  if (!open) {
    return (
      <div>
        <button className="ad-btn" onClick={() => setOpen(true)}>Log a visit</button>
      </div>
    );
  }

  return (
    <form className="ad-panel" onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Log a visit</div>
      {error && <div className="ad-error">{error}</div>}
      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
        <label style={{ fontSize: 13 }}>
          Date<br />
          <input className="ad-input" type="date" value={form.visitedAt} onChange={set('visitedAt')} />
        </label>
        <label style={{ fontSize: 13 }}>
          Service<br />
          <select className="ad-select" value={form.serviceType} onChange={set('serviceType')}>
            <option value="bath">Bath</option>
            <option value="full_groom">Full groom</option>
            <option value="nails">Nails</option>
          </select>
        </label>
        <label style={{ fontSize: 13 }}>
          Minutes<br />
          <input className="ad-input" type="number" min="1" value={form.actualMinutes} onChange={set('actualMinutes')} style={{ width: 90 }} />
        </label>
        <label style={{ fontSize: 13 }}>
          Collected ($)<br />
          <input className="ad-input" type="number" min="0" step="0.01" value={form.amount} onChange={set('amount')} style={{ width: 110 }} />
        </label>
        <label style={{ fontSize: 13 }}>
          Paid via<br />
          <select className="ad-select" value={form.paymentMethod} onChange={set('paymentMethod')}>
            <option value="">unset</option>
            <option value="square_in_person">Square</option>
            <option value="stripe_card">Stripe</option>
            <option value="cash">Cash</option>
            <option value="wallet">Wallet</option>
          </select>
        </label>
      </div>
      {(dogs || []).length > 0 && (
        <div>
          <div style={{ fontSize: 12, opacity: 0.6 }}>Vibe score</div>
          <div style={{ fontSize: 11, opacity: 0.55, marginTop: 2, lineHeight: 1.45 }}>
            1 unsafe / aggression, not eligible · 2 poor, conditional · 3 average · 4 cooperative · 5 a joy, anticipates you
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 6 }}>
            {dogs.map((d) => (
              <div key={d.id} style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                <span style={{ fontSize: 14, minWidth: 90 }}>{d.name}</span>
                <div style={{ display: 'flex', gap: 4 }}>
                  {[1, 2, 3, 4, 5].map((n) => (
                    <button
                      key={n}
                      type="button"
                      onClick={() => setScores((s) => ({ ...s, [d.id]: s[d.id] === n ? undefined : n }))}
                      className={'ad-btn ad-btn--sm ' + (scores[d.id] === n ? '' : 'ad-btn--ghost')}
                      style={{ minWidth: 34 }}
                    >{n}</button>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
      <label style={{ fontSize: 13 }}>
        What was done<br />
        <input className="ad-input" value={form.workDone} onChange={set('workDone')} style={{ width: '100%' }} />
      </label>
      <label style={{ fontSize: 13 }}>
        Notes (behavior, condition, what to watch next time)<br />
        <textarea className="ad-textarea" value={form.visitNotes} onChange={set('visitNotes')} rows={2} style={{ width: '100%' }} />
      </label>
      <div style={{ display: 'flex', gap: 8 }}>
        <button className="ad-btn" type="submit" disabled={saving}>{saving ? 'Saving…' : 'Save visit'}</button>
        <button className="ad-btn ad-btn--ghost" type="button" onClick={() => setOpen(false)}>Cancel</button>
      </div>
    </form>
  );
}

function NoFlyPanel({ onChanged }) {
  const [list, setList] = useState(null);
  const [open, setOpen] = useState(false);
  const load = useCallback(async () => { try { setList(await listNofly()); } catch { setList([]); } }, []);
  useEffect(() => { load(); }, [load]);
  if (!list) return null;

  async function remove(id) {
    try { await setClientNofly(id, false); await load(); onChanged?.(); } catch { /* noop */ }
  }
  return (
    <div className="ad-panel" style={{ marginBottom: 16, borderLeft: '4px solid var(--ad-bad, #dc2626)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }} onClick={() => setOpen((o) => !o)}>
        <strong style={{ fontSize: 14 }}>No-fly list · {list.length}</strong>
        <span style={{ fontSize: 12, opacity: 0.6 }}>{open ? 'hide' : 'show'}</span>
      </div>
      {open && (
        <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 6 }}>
          {list.length === 0 && <div style={{ opacity: 0.6, fontSize: 13 }}>No one is on the no-fly list. Open a client and use "Put on no-fly list".</div>}
          {list.map((c) => (
            <div key={c.id} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, borderBottom: '1px solid var(--ad-outline, #ececf1)', paddingBottom: 4 }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <strong>{c.name}</strong>{c.aka ? <span className="ad-mono" style={{ opacity: 0.55, marginLeft: 6 }}>{c.aka}</span> : null}
                {c.reason ? <div style={{ fontSize: 12, opacity: 0.7 }}>{c.reason}</div> : null}
              </div>
              <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => remove(c.id)}>Remove</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function ArchivedPanel({ onChanged }) {
  const [list, setList] = useState(null);
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(null);
  const load = useCallback(async () => { try { setList(await listArchivedClients()); } catch { setList([]); } }, []);
  useEffect(() => { load(); }, [load]);
  if (!list || list.length === 0) return null;

  async function restore(id) {
    setBusy(id);
    try { await unarchiveClient(id); await load(); onChanged?.(); }
    finally { setBusy(null); }
  }
  return (
    <div className="ad-panel" style={{ marginBottom: 16, borderLeft: '4px solid var(--ad-text-dim, #565b6c)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }} onClick={() => setOpen((o) => !o)}>
        <strong style={{ fontSize: 14 }}>Archived · {list.length}</strong>
        <span style={{ fontSize: 12, opacity: 0.6 }}>{open ? 'hide' : 'show'}</span>
      </div>
      {open && (
        <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 6 }}>
          <div style={{ fontSize: 12, opacity: 0.65, marginBottom: 2 }}>Not seen in over a year, hidden from the book. Anyone who books or gets a visit logged comes back automatically; or bring one back here.</div>
          {list.map((c) => (
            <div key={c.id} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, borderBottom: '1px solid var(--ad-outline, #ececf1)', paddingBottom: 4 }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <strong>{c.name}</strong>{c.aka ? <span className="ad-mono" style={{ opacity: 0.55, marginLeft: 6 }}>{c.aka}</span> : null}
                <div style={{ fontSize: 12, opacity: 0.7 }}>
                  {SERVICE_LABELS[c.service_type] || c.service_type || 'service unset'}
                  {c.location_zone ? ` · ${c.location_zone}` : ''}
                  {c.last_visit_at ? ` · last seen ${fmtDate(c.last_visit_at)}` : ''}
                </div>
              </div>
              <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => restore(c.id)} disabled={busy === c.id}>{busy === c.id ? '…' : 'Bring back'}</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function AliasManager({ clientId, onChanged }) {
  const [aliases, setAliases] = useState([]);
  const [adding, setAdding] = useState(false);
  const [val, setVal] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => { try { setAliases(await listAliases(clientId)); } catch { setAliases([]); } }, [clientId]);
  useEffect(() => { load(); }, [load]);

  async function add() {
    if (!val.trim()) return;
    setBusy(true);
    try { await addAlias(clientId, val.trim()); setVal(''); setAdding(false); await load(); onChanged?.(); }
    finally { setBusy(false); }
  }
  async function remove(id) {
    setBusy(true);
    try { await removeAlias(id); await load(); onChanged?.(); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ marginTop: 10 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55, marginBottom: 4 }}>
        Also known as / household names
      </div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
        {aliases.map((a) => (
          <span key={a.id} className="ad-mono" style={{ fontSize: 12, padding: '3px 8px', borderRadius: 8, background: 'var(--ad-surface-container-high, #eef1fb)', display: 'inline-flex', gap: 6, alignItems: 'center' }}>
            {a.alias}
            <button onClick={() => remove(a.id)} disabled={busy} title="remove" style={{ border: 'none', background: 'none', cursor: 'pointer', opacity: 0.5, fontSize: 13, lineHeight: 1, padding: 0 }}>×</button>
          </span>
        ))}
        {adding ? (
          <span style={{ display: 'inline-flex', gap: 4 }}>
            <input className="ad-input" autoFocus value={val} onChange={(e) => setVal(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && add()} placeholder="another name or spelling" style={{ width: 180, fontSize: 13, padding: '3px 6px' }} />
            <button className="ad-btn ad-btn--sm" onClick={add} disabled={busy}>Add</button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setAdding(false); setVal(''); }}>Cancel</button>
          </span>
        ) : (
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setAdding(true)}>+ name</button>
        )}
      </div>
      <div style={{ fontSize: 11, opacity: 0.5, marginTop: 3 }}>Searching any of these names opens this household.</div>
    </div>
  );
}

function NoFlyControl({ client, onChanged }) {
  const [adding, setAdding] = useState(false);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  async function ban() {
    setBusy(true);
    try { await setClientNofly(client.id, true, reason.trim() || null); setAdding(false); setReason(''); onChanged?.(); }
    finally { setBusy(false); }
  }
  async function unban() {
    setBusy(true);
    try { await setClientNofly(client.id, false); onChanged?.(); }
    finally { setBusy(false); }
  }

  if (client.nofly) {
    return (
      <div style={{ marginTop: 10, padding: '8px 10px', borderRadius: 8, background: 'rgba(220,38,38,0.08)', display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <strong style={{ color: 'var(--ad-bad, #dc2626)', fontSize: 13 }}>ON NO-FLY LIST</strong>
        {client.nofly_reason && <span style={{ fontSize: 13, opacity: 0.8, flex: 1 }}>{client.nofly_reason}</span>}
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={unban} disabled={busy}>Remove</button>
      </div>
    );
  }
  if (adding) {
    return (
      <div style={{ marginTop: 10, display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
        <input className="ad-input" placeholder="reason (do not serve / contact)" value={reason} onChange={(e) => setReason(e.target.value)} style={{ flex: '1 1 220px' }} autoFocus />
        <button className="ad-btn ad-btn--sm" onClick={ban} disabled={busy}>Add to no-fly</button>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setAdding(false)}>Cancel</button>
      </div>
    );
  }
  return (
    <div style={{ marginTop: 10 }}>
      <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setAdding(true)}>Put on no-fly list</button>
    </div>
  );
}
