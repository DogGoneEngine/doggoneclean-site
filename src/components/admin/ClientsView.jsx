// src/components/admin/ClientsView.jsx
//
// The Clients department: the contact-sheet database. The list is the book; the
// detail pane is one contact sheet, laid out the way Paul keeps it: the
// semi-permanent header (frequency, availability, location, per-dog specs) on
// top, the growing visit history below. "Log a visit" appends to the ledger.

import { useCallback, useEffect, useMemo, useState } from 'react';
import { listClients, getClient, logVisit, setClientStatus, setDogStanding, setClientAccess, setClientOnsite, setClientPlus, setClientThoughts, setDogBirthday, listDogFollowups, addDogFollowup, resolveDogFollowup, dropDogFollowup, messageDraft, listNofly, listArchivedClients, unarchiveClient, listAliases, addAlias, removeAlias } from './supabase.js';
import RikerCapture from './RikerCapture.jsx';
import VisitPhotos from './VisitPhotos.jsx';

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

export default function ClientsView({ focus = null }) {
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [query, setQuery] = useState('');
  const [selectedId, setSelectedId] = useState(null);
  const narrow = useIsNarrow();

  // Opened from another floor (e.g. a Today stop): focus that client's sheet.
  useEffect(() => { if (focus && focus.id) setSelectedId(focus.id); }, [focus?.id, focus?.n]);

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
        {c.nofly_level && <StatusBadge level={c.nofly_level} reason={c.nofly_reason} />}
        <AliasManager clientId={clientId} onChanged={onChanged} />
        <dl style={{ display: 'grid', gridTemplateColumns: 'max-content 1fr', gap: '4px 14px', margin: '12px 0 0' }}>
          <Field label="Service" value={SERVICE_LABELS[c.service_type] || c.service_type} />
          <Field label="Frequency" value={c.cadence_days ? `every ${c.cadence_days} days${c.cadence_confidence ? ` (${c.cadence_confidence})` : ''}` : c.cadence_note} />
          <Field label="Hardness" value={c.hardness} />
          <Field label="Availability" value={c.availability_hard} />
          <Field label="Avoid" value={(c.availability_not_days || []).join(', ')} />
          <Field label="Seasonal" value={c.availability_seasonal} />
          <LocationField client={c} />
          <Field label="Geo notes" value={c.location_geo_notes} />
          <Field label="Phone" value={c.phone_e164} />
          <Field label="Flags" value={(c.flags || []).join(', ')} />
          <Field label="Data gaps" value={(c.data_gaps || []).join(', ')} />
        </dl>
        <PlusCode client={c} onChanged={() => { load(); onChanged?.(); }} />
        <AccessNotes client={c} onChanged={() => { load(); onChanged?.(); }} />
        <OnsitePeople client={c} onChanged={() => { load(); onChanged?.(); }} />
        <MessageDraftTool client={c} onChanged={() => { load(); onChanged?.(); }} />
        {dogs.length > 0 && (
          <div style={{ marginTop: 14 }}>
            <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Dogs</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {dogs.map((d) => (
                <DogCard key={d.id} dog={d} onChanged={() => { load(); onChanged?.(); }} />
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Riker: say it, it gets entered (one-tap confirm) */}
      <RikerCapture clientId={clientId} clientName={c.name} onApplied={() => { load(); onChanged?.(); }} />

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
                  <div style={{ marginTop: 4, display: 'flex', flexDirection: 'column', gap: 2 }}>
                    {v.dog_ratings.map((r) => (
                      <div key={r.dog_id || r.name} style={{ fontSize: 13, display: 'flex', gap: 6, alignItems: 'baseline', flexWrap: 'wrap' }}>
                        <span style={{ fontWeight: 600 }}>{r.name || 'dog'}</span>
                        {r.score != null && <span title="vibe score (1 unsafe to 5 a joy)"><ScoreDot score={r.score} /></span>}
                        {r.note ? <span style={{ opacity: 0.8 }}>{r.note}</span> : null}
                      </div>
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
                <VisitPhotos visitId={v.id} clientId={clientId} photos={v.photos || []} onChanged={load} />
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Client status (shadow ban / hard ban). Tucked at the bottom on purpose:
          a rare, deliberate action, not something to fat-finger from the header. */}
      <ClientStatusControl client={c} onChanged={() => { load(); onChanged?.(); }} />
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
    try { await setClientStatus(id, null); await load(); onChanged?.(); } catch { /* noop */ }
  }
  if (list.length === 0) return null;
  return (
    <div className="ad-panel" style={{ marginBottom: 16, borderLeft: '4px solid var(--ad-bad, #dc2626)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }} onClick={() => setOpen((o) => !o)}>
        <strong style={{ fontSize: 14 }}>No-fly list · {list.length}</strong>
        <span style={{ fontSize: 12, opacity: 0.6 }}>{open ? 'hide' : 'show'}</span>
      </div>
      {open && (
        <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 6 }}>
          {list.map((c) => (
            <div key={c.id} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, borderBottom: '1px solid var(--ad-outline, #ececf1)', paddingBottom: 4 }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <strong>{c.name}</strong>{c.aka ? <span className="ad-mono" style={{ opacity: 0.55, marginLeft: 6 }}>{c.aka}</span> : null}
                <span className="ad-mono" style={{ fontSize: 10, marginLeft: 8, padding: '1px 6px', borderRadius: 6, color: c.level === 'banned' ? 'var(--ad-bad, #dc2626)' : 'var(--ad-warn, #b9770a)', background: c.level === 'banned' ? 'rgba(220,38,38,0.10)' : 'rgba(185,119,10,0.10)' }}>{c.level === 'banned' ? 'banned' : 'shadow'}</span>
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

// A quiet status banner in the header, shown only when a status is actually set.
function StatusBadge({ level, reason }) {
  const banned = level === 'banned';
  return (
    <div style={{ marginTop: 8, padding: '4px 8px', borderRadius: 8, display: 'inline-flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', background: banned ? 'rgba(220,38,38,0.10)' : 'rgba(185,119,10,0.10)' }}>
      <strong style={{ fontSize: 12, color: banned ? 'var(--ad-bad, #dc2626)' : 'var(--ad-warn, #b9770a)' }}>{banned ? 'BANNED' : 'SHADOW BAN'}</strong>
      {reason && <span style={{ fontSize: 12, opacity: 0.8 }}>{reason}</span>}
    </div>
  );
}

// A Google Maps link, preferring the plus code (reliable when the street address
// routes to the wrong place), then the address, then lat/lng.
function mapsUrl(c) {
  const q = (c.location_plus || '').trim()
    || [c.location_address, c.location_zip].filter(Boolean).join(' ').trim()
    || (c.geo_lat != null && c.geo_lng != null ? `${c.geo_lat},${c.geo_lng}` : '');
  return q ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(q)}` : null;
}

function LocationField({ client }) {
  const text = client.location_address || client.location_zone || '';
  const url = mapsUrl(client);
  if (!text && !url) return null;
  return (
    <>
      <dt style={{ fontSize: 12, opacity: 0.55, textTransform: 'uppercase', letterSpacing: 0.3 }}>Location</dt>
      <dd style={{ margin: 0, fontSize: 14 }}>
        {url
          ? <a href={url} target="_blank" rel="noreferrer" style={{ color: 'var(--ad-primary, #2563d8)' }}>{text || 'Open in Maps'} ↗</a>
          : text}
        {client.location_plus ? <span style={{ opacity: 0.5, fontSize: 12 }}> · maps uses plus code</span> : null}
      </dd>
    </>
  );
}

// Editable plus code. The maps link above prefers it, so set it when the street
// address sends you to the wrong place.
function PlusCode({ client, onChanged }) {
  const [editing, setEditing] = useState(false);
  const [val, setVal] = useState(client.location_plus || '');
  const [busy, setBusy] = useState(false);
  useEffect(() => { setVal(client.location_plus || ''); }, [client.location_plus]);

  async function save() {
    setBusy(true);
    try { await setClientPlus(client.id, val); setEditing(false); onChanged?.(); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ marginTop: 12 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55, marginBottom: 2 }}>Plus code (overrides the address for maps)</div>
      {editing ? (
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
          <input className="ad-input" value={val} onChange={(e) => setVal(e.target.value)} placeholder="e.g. FQH7+5RX Evinston FL" style={{ flex: '1 1 220px' }} />
          <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setVal(client.location_plus || ''); setEditing(false); }}>Cancel</button>
        </div>
      ) : client.location_plus ? (
        <div style={{ fontSize: 14, display: 'flex', gap: 8, alignItems: 'center' }}>
          <span className="ad-mono" style={{ flex: 1 }}>{client.location_plus}</span>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
        </div>
      ) : (
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>+ Add plus code</button>
      )}
    </div>
  );
}

// Client-level "how to get in" notes: gate / door / lock codes, location and
// parking, from the contact sheet. Editable inline.
function AccessNotes({ client, onChanged }) {
  const [editing, setEditing] = useState(false);
  const [val, setVal] = useState(client.access_notes || '');
  const [busy, setBusy] = useState(false);
  useEffect(() => { setVal(client.access_notes || ''); }, [client.access_notes]);

  async function save() {
    setBusy(true);
    try { await setClientAccess(client.id, val); setEditing(false); onChanged?.(); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ marginTop: 12 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55, marginBottom: 2 }}>How to get in</div>
      {editing ? (
        <div>
          <textarea className="ad-textarea" rows={3} value={val} onChange={(e) => setVal(e.target.value)} style={{ width: '100%' }}
            placeholder="Gate / door / lock codes, where to park, how to reach the dog" />
          <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
            <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setVal(client.access_notes || ''); setEditing(false); }}>Cancel</button>
          </div>
        </div>
      ) : client.access_notes ? (
        <div style={{ fontSize: 14, display: 'flex', gap: 8, alignItems: 'flex-start' }}>
          <span style={{ flex: 1 }}>{client.access_notes}</span>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
        </div>
      ) : (
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>+ Add access notes</button>
      )}
    </div>
  );
}

// Who Paul might meet on site (housekeeper, family, staff, who lets him in).
function OnsitePeople({ client, onChanged }) {
  const [editing, setEditing] = useState(false);
  const [val, setVal] = useState(client.onsite_people || '');
  const [busy, setBusy] = useState(false);
  useEffect(() => { setVal(client.onsite_people || ''); }, [client.onsite_people]);

  async function save() {
    setBusy(true);
    try { await setClientOnsite(client.id, val); setEditing(false); onChanged?.(); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ marginTop: 12 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55, marginBottom: 2 }}>Who's on site</div>
      {editing ? (
        <div>
          <textarea className="ad-textarea" rows={3} value={val} onChange={(e) => setVal(e.target.value)} style={{ width: '100%' }}
            placeholder="People you might meet here: housekeeper, family, staff, who lets you in, who to ask for" />
          <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
            <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setVal(client.onsite_people || ''); setEditing(false); }}>Cancel</button>
          </div>
        </div>
      ) : client.onsite_people ? (
        <div style={{ fontSize: 14, display: 'flex', gap: 8, alignItems: 'flex-start' }}>
          <span style={{ flex: 1 }}>{client.onsite_people}</span>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
        </div>
      ) : (
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>+ Add who's on site</button>
      )}
    </div>
  );
}

// One dog: header line, condition notes, and the editable standing instructions
// (the semi-permanent "how to handle this dog every time" from the contact sheet).
// A labeled, inline-editable free-text field (used for a dog's standing
// instructions and its separate follow-up).
function DogField({ label, value, placeholder, onSave }) {
  const [editing, setEditing] = useState(false);
  const [val, setVal] = useState(value || '');
  const [busy, setBusy] = useState(false);
  useEffect(() => { setVal(value || ''); }, [value]);

  async function save() {
    setBusy(true);
    try { await onSave(val); setEditing(false); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ marginTop: 6 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.5 }}>{label}</div>
      {editing ? (
        <div style={{ marginTop: 4 }}>
          <textarea className="ad-textarea" rows={2} value={val} onChange={(e) => setVal(e.target.value)} style={{ width: '100%' }} placeholder={placeholder} />
          <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
            <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setVal(value || ''); setEditing(false); }}>Cancel</button>
          </div>
        </div>
      ) : value ? (
        <div style={{ fontSize: 13, marginTop: 2, display: 'flex', gap: 8, alignItems: 'flex-start' }}>
          <span style={{ flex: 1 }}>{value}</span>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
        </div>
      ) : (
        <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ marginTop: 2 }} onClick={() => setEditing(true)}>+ Add</button>
      )}
    </div>
  );
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
function parseBirth(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s || '');
  return m ? { y: m[1], m: String(+m[2]), d: String(+m[3]) } : { y: '', m: '', d: '' };
}

function DogBirthday({ dog, onChanged }) {
  const [editing, setEditing] = useState(false);
  const init = parseBirth(dog.birth_date);
  const [mo, setMo] = useState(init.m);
  const [day, setDay] = useState(init.d);
  const [year, setYear] = useState(init.y);
  const [approx, setApprox] = useState(!!dog.dob_approximate);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    const p = parseBirth(dog.birth_date);
    setMo(p.m); setDay(p.d); setYear(p.y); setApprox(!!dog.dob_approximate);
  }, [dog.birth_date, dog.dob_approximate]);

  const nowY = new Date().getFullYear();
  const years = [];
  for (let yy = nowY; yy >= nowY - 26; yy--) years.push(yy);
  const pad = (n) => String(n).padStart(2, '0');

  async function save() {
    setBusy(true);
    try {
      const date = (year && mo && day) ? `${year}-${pad(mo)}-${pad(day)}` : null;
      await setDogBirthday(dog.id, date, approx);
      setEditing(false); onChanged?.();
    } finally { setBusy(false); }
  }

  const selStyle = { padding: '6px 8px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', fontSize: 14, background: '#fff' };

  return (
    <div style={{ marginTop: 6 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.5 }}>Birthday</div>
      {editing ? (
        <div style={{ marginTop: 4, display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
          <select className="ad-select" value={mo} onChange={(e) => setMo(e.target.value)} style={selStyle}>
            <option value="">Month</option>
            {MONTHS.map((nm, i) => <option key={i} value={i + 1}>{nm}</option>)}
          </select>
          <select className="ad-select" value={day} onChange={(e) => setDay(e.target.value)} style={selStyle}>
            <option value="">Day</option>
            {Array.from({ length: 31 }, (_, i) => i + 1).map((n) => <option key={n} value={n}>{n}</option>)}
          </select>
          <select className="ad-select" value={year} onChange={(e) => setYear(e.target.value)} style={selStyle}>
            <option value="">Year</option>
            {years.map((yy) => <option key={yy} value={yy}>{yy}</option>)}
          </select>
          <label style={{ fontSize: 13, display: 'inline-flex', gap: 4, alignItems: 'center' }}>
            <input type="checkbox" checked={approx} onChange={(e) => setApprox(e.target.checked)} /> estimated
          </label>
          <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { const p = parseBirth(dog.birth_date); setMo(p.m); setDay(p.d); setYear(p.y); setApprox(!!dog.dob_approximate); setEditing(false); }}>Cancel</button>
        </div>
      ) : dog.birth_date ? (
        <div style={{ fontSize: 13, marginTop: 2, display: 'flex', gap: 8, alignItems: 'center' }}>
          <span style={{ flex: 1 }}>{fmtDate(dog.birth_date + 'T12:00:00')}{dog.dob_approximate ? ' (estimated)' : ' (exact)'}</span>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
        </div>
      ) : (
        <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ marginTop: 2 }} onClick={() => setEditing(true)}>+ Add birthday</button>
      )}
    </div>
  );
}

function DogCard({ dog, onChanged }) {
  return (
    <div style={{ border: '1px solid var(--ad-outline, #d9dbe6)', borderRadius: 10, padding: '8px 10px' }}>
      <div className="ad-mono" style={{ fontSize: 13 }}>
        <strong>{dog.name}</strong>{dog.breed ? ` · ${dog.breed}` : ''}{dog.price_cents != null ? ` · ${money(dog.price_cents)}` : ''}
      </div>
      {dog.notes ? <div style={{ opacity: 0.7, marginTop: 2, fontSize: 12 }}>{dog.notes}</div> : null}
      <DogBirthday dog={dog} onChanged={onChanged} />
      <DogField label="Standing instructions" value={dog.standing_instructions}
        placeholder="How to handle this dog every time (e.g. 8mm comb on body, hates the dryer, do nails first)"
        onSave={async (v) => { await setDogStanding(dog.id, v); onChanged?.(); }} />
      <DogFollowups dogId={dog.id} />
    </div>
  );
}

// "Ask / check next time" as an open->resolved loop. Open items show highlighted
// until Paul resolves one (records what he found), which moves it to a collapsible
// past-follow-up history. Loads its own list so it stays fresh on each action.
function DogFollowups({ dogId }) {
  const [items, setItems] = useState(null);
  const [adding, setAdding] = useState(false);
  const [newBody, setNewBody] = useState('');
  const [resolvingId, setResolvingId] = useState(null);
  const [resolutionText, setResolutionText] = useState('');
  const [showPast, setShowPast] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => { try { setItems(await listDogFollowups(dogId)); } catch { setItems([]); } }, [dogId]);
  useEffect(() => { load(); }, [load]);

  const open = (items || []).filter((f) => f.status === 'open');
  const past = (items || []).filter((f) => f.status === 'resolved');

  async function add() {
    if (!newBody.trim()) return;
    setBusy(true);
    try { await addDogFollowup(dogId, newBody.trim()); setNewBody(''); setAdding(false); await load(); }
    finally { setBusy(false); }
  }
  async function resolve(id) {
    setBusy(true);
    try { await resolveDogFollowup(id, resolutionText.trim() || null); setResolvingId(null); setResolutionText(''); await load(); }
    finally { setBusy(false); }
  }
  async function drop(id) {
    setBusy(true);
    try { await dropDogFollowup(id); await load(); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ marginTop: 6 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.5 }}>Ask / check next time</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 4 }}>
        {open.map((f) => (
          <div key={f.id} style={{ padding: '6px 8px', borderRadius: 8, background: 'rgba(185,119,10,0.10)', borderLeft: '3px solid var(--ad-warn, #b9770a)' }}>
            <div style={{ fontSize: 13 }}>{f.body}</div>
            {resolvingId === f.id ? (
              <div style={{ marginTop: 4 }}>
                <input className="ad-input" autoFocus value={resolutionText} onChange={(e) => setResolutionText(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && resolve(f.id)} placeholder="What did you find / what's the answer?" style={{ width: '100%' }} />
                <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
                  <button className="ad-btn ad-btn--sm" onClick={() => resolve(f.id)} disabled={busy}>Done</button>
                  <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setResolvingId(null); setResolutionText(''); }}>Cancel</button>
                </div>
              </div>
            ) : (
              <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
                <button className="ad-btn ad-btn--sm" onClick={() => { setResolvingId(f.id); setResolutionText(''); }} disabled={busy}>Resolve</button>
                <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => drop(f.id)} disabled={busy} title="Remove without recording">Drop</button>
              </div>
            )}
          </div>
        ))}
        {adding ? (
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <input className="ad-input" autoFocus value={newBody} onChange={(e) => setNewBody(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && add()} placeholder="e.g. ask about her belly, recheck the left ear" style={{ flex: '1 1 220px' }} />
            <button className="ad-btn ad-btn--sm" onClick={add} disabled={busy}>Add</button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setAdding(false); setNewBody(''); }}>Cancel</button>
          </div>
        ) : (
          <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ alignSelf: 'flex-start' }} onClick={() => setAdding(true)}>+ Add follow-up</button>
        )}
        {past.length > 0 && (
          <div style={{ marginTop: 2 }}>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setShowPast((s) => !s)}>{showPast ? 'Hide' : 'Show'} past follow-ups · {past.length}</button>
            {showPast && (
              <div style={{ marginTop: 4, display: 'flex', flexDirection: 'column', gap: 4 }}>
                {past.map((f) => (
                  <div key={f.id} style={{ fontSize: 12, opacity: 0.75, borderLeft: '3px solid var(--ad-outline, #d9dbe6)', paddingLeft: 8 }}>
                    <span style={{ textDecoration: 'line-through', opacity: 0.7 }}>{f.body}</span>
                    {f.resolution ? <span> → {f.resolution}</span> : null}
                    {f.resolved_at ? <span className="ad-mono" style={{ fontSize: 10, opacity: 0.6 }}> · {fmtDate(f.resolved_at)}</span> : null}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// Message draft (test): Paul dumps stream-of-consciousness about the dog or the
// visit, the draft agent turns it into something worth sending the client. Never
// sends; the brain dump is saved so he can keep adding to it.
function MessageDraftTool({ client, onChanged }) {
  const [thoughts, setThoughts] = useState(client.message_thoughts || '');
  const [draft, setDraft] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const [open, setOpen] = useState(false);
  useEffect(() => { setThoughts(client.message_thoughts || ''); }, [client.message_thoughts]);

  async function run() {
    if (!thoughts.trim()) return;
    setBusy(true); setError(null); setDraft(''); setNote('');
    try {
      await setClientThoughts(client.id, thoughts);
      const out = await messageDraft(client.id, thoughts);
      setDraft(out.draft || ''); setNote(out.note || '');
      onChanged?.();
    } catch (e) { setError(e.message || 'draft_failed'); }
    finally { setBusy(false); }
  }

  return (
    <div className="ad-panel" style={{ borderLeft: '4px solid var(--ad-accent, #2563eb)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }} onClick={() => setOpen((o) => !o)}>
        <strong style={{ fontSize: 14 }}>Message draft <span style={{ fontWeight: 400, opacity: 0.6, fontSize: 12 }}>(test, never sends)</span></strong>
        <span style={{ fontSize: 12, opacity: 0.5 }}>{open ? 'hide' : 'open'}</span>
      </div>
      {open && (
        <div style={{ marginTop: 8 }}>
          <div style={{ fontSize: 12, opacity: 0.7, marginBottom: 4 }}>Say whatever you are thinking about the dog or the visit. The draft agent pulls out something worth sending.</div>
          <textarea className="ad-textarea" rows={3} value={thoughts} onChange={(e) => setThoughts(e.target.value)} style={{ width: '100%' }}
            placeholder="Stream of consciousness… e.g. Bella finally let me do her back feet without a fuss today, she has come so far" />
          <div style={{ display: 'flex', gap: 8, marginTop: 6, alignItems: 'center' }}>
            <button className="ad-btn ad-btn--sm" onClick={run} disabled={busy || !thoughts.trim()}>{busy ? 'Drafting…' : 'Draft a message'}</button>
          </div>
          {error && <div className="ad-error" style={{ marginTop: 6 }}>{error}</div>}
          {draft && (
            <div style={{ marginTop: 8, padding: '8px 10px', borderRadius: 8, background: 'var(--ad-surface-container, #f1f1f4)' }}>
              <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.5, marginBottom: 4 }}>Draft (not sent)</div>
              <div style={{ fontSize: 14, whiteSpace: 'pre-wrap' }}>{draft}</div>
              {note && <div style={{ fontSize: 12, opacity: 0.6, marginTop: 6 }}>Agent note: {note}</div>}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// Client status (shadow ban / hard ban). Collapsed by default and parked at the
// bottom of the sheet on purpose: a rare, deliberate action, not a header button
// to fat-finger. Shadow ban keeps the client but stops all solicitation; a hard
// ban removes them everywhere.
function ClientStatusControl({ client, onChanged }) {
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const current = client.nofly_level;

  async function apply(level) {
    setBusy(true);
    try { await setClientStatus(client.id, level, reason.trim() || null); setReason(''); setOpen(false); onChanged?.(); }
    finally { setBusy(false); }
  }

  return (
    <div className="ad-panel">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer' }} onClick={() => setOpen((o) => !o)}>
        <span style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>
          Client status{current ? ` · ${current === 'banned' ? 'banned' : 'shadow ban'}` : ''}
        </span>
        <span style={{ fontSize: 12, opacity: 0.5 }}>{open ? 'hide' : 'manage'}</span>
      </div>
      {open && (
        <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 8 }}>
          {current && (
            <div style={{ fontSize: 13 }}>
              Currently <strong style={{ color: current === 'banned' ? 'var(--ad-bad, #dc2626)' : 'var(--ad-warn, #b9770a)' }}>{current === 'banned' ? 'banned' : 'shadow banned'}</strong>
              {client.nofly_reason ? `: ${client.nofly_reason}` : ''}
            </div>
          )}
          <div style={{ fontSize: 12, opacity: 0.7, lineHeight: 1.5 }}>
            Shadow ban keeps them in the book and still serves them, but never solicits their business (no win-back, no outreach). A hard ban removes them everywhere and stops all contact.
          </div>
          <textarea className="ad-textarea" rows={2} placeholder="reason (kept private)" value={reason} onChange={(e) => setReason(e.target.value)} style={{ width: '100%' }} />
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => apply('shadow')}>Shadow ban</button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} style={{ color: 'var(--ad-bad, #dc2626)' }}
              onClick={() => { if (window.confirm('Hard ban this client? They are removed everywhere and all contact stops.')) apply('banned'); }}>Hard ban</button>
            {current && <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => apply(null)}>Clear status</button>}
          </div>
        </div>
      )}
    </div>
  );
}
