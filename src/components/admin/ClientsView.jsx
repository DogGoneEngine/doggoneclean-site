// src/components/admin/ClientsView.jsx
//
// The Clients department: the contact-sheet database. The list is the book; the
// detail pane is one contact sheet, laid out the way Paul keeps it: the
// semi-permanent header (frequency, availability, location, per-dog specs) on
// top, the growing visit history below. "Log a visit" appends to the ledger.

import { useCallback, useEffect, useMemo, useState } from 'react';
import { listClients, getClient, logVisit, setClientStatus, setDogStanding, setDogStatus, setDogNote, setDogHandling, setDogDoorHandling, setClientAccess, setClientAlt, setClientOnsite, setClientPlus, setClientThoughts, setDogBirthday, listDogFollowups, addDogFollowup, resolveDogFollowup, dropDogFollowup, messageDraft, listNofly, listArchivedClients, unarchiveClient, listAliases, addAlias, removeAlias, listNotifyPeople, upsertNotifyPerson, setNotifyPersonActive, deleteNotifyPerson, adminOpenSlots, adminBookAppointment, suggestSlotsWithDrive, adminArrived } from './supabase.js';
import RikerCapture from './RikerCapture.jsx';
import HelpToggle from './Help.jsx';

const easternDay = (ts) => new Date(ts).toLocaleDateString('en-CA', { timeZone: 'America/New_York' });
import VisitPhotos from './VisitPhotos.jsx';

const SERVICE_LABELS = {
  full_groom: 'Full groom',
  bath: 'Bath',
  nails: 'Nails',
  nails_only_legacy: 'Nails (legacy)',
  mixed_groom_and_nails: 'Groom + nails',
  nails_only: 'Nails only',
};

// Client type, the two real situations: Recurring (on a cadence) or On-demand
// (they reach out when they want). The raw `status`/`roster_group` columns
// currently conflate type with lifecycle (active, moved away, deceased, merged)
// and even banned, which is why the sheet showed "one off one off". Until that is
// untangled in the data, map the known values to one clean human label here.
const CLIENT_TYPE = {
  standing: 'Recurring', active: 'Recurring',
  one_off: 'On-demand', one_off_for_now: 'On-demand', at_will: 'On-demand', at_will_winddown: 'On-demand',
};
const CLIENT_STATE = {
  moved_away: 'Moved away', deceased: 'Deceased', inactive: 'Inactive',
  merged: 'Merged', test_account: 'Test', banned: 'Banned',
};
// One clean label: the type if we can tell, plus a lifecycle note when it is not
// a plain current client. De-duplicated, never the raw enum twice.
function clientTag(c) {
  const s = c.status, r = c.roster_group;
  const type = CLIENT_TYPE[s] || CLIENT_TYPE[r] || null;
  const state = CLIENT_STATE[s] || (CLIENT_STATE[r] && CLIENT_STATE[r] !== type ? CLIENT_STATE[r] : null);
  return [type, state].filter(Boolean).join(' · ') || (s || '').replace(/_/g, ' ');
}

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
  const [starting, setStarting] = useState(false);

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

  // Start the visit from inside the client record: the same arrival path as
  // "I'm here" on the Today sheet (admin_arrived stamps arrival and creates the
  // visit row). Once it exists, the "Today's visit" card with photos and notes
  // takes over from the read-only appointment card, so Paul can add photos from
  // the record without going to the Today screen first. One visit-creation path,
  // not two (Paul, 2026-06-18: the appointment card "had no place to add photos").
  const startVisit = useCallback(async (apptId) => {
    setStarting(true);
    try {
      await adminArrived(apptId);
      await load();
      onChanged?.();
    } catch (e) {
      setError(e.message || 'start_failed');
    } finally {
      setStarting(false);
    }
  }, [load, onChanged]);

  if (loading) return <div className="ad-panel">Opening the sheet…</div>;
  if (error) return <div className="ad-panel"><div className="ad-error">{error}</div></div>;
  if (!data) return null;

  const c = data.client || {};
  const dogs = data.dogs || [];
  const visits = data.visits || [];
  // The visit being worked right now pins to the top of the sheet. It unpins
  // the moment Departed is stamped (Paul, 2026-06-12: once we roll out, the
  // card belongs down in the history), or when the day passes, whichever
  // comes first. Undoing the Departed stamp re-pins it on the next load.
  const todayKey = easternDay(Date.now());
  const isPinned = (v) => easternDay(v.visited_at) === todayKey && !v.departed_at;
  const todayVisits = visits.filter(isPinned);
  const pastVisits = visits.filter((v) => !isPinned(v));
  const upcoming = data.upcoming || [];
  // Today's appointment floats to the top too, not only a started visit: when
  // Paul opens a client he is about to groom, the appointment must be right there
  // (Paul's original rule, current appointment at the top). Once he starts it a
  // visit row exists and the "Today's visit" card takes over; until then this
  // surfaces the scheduled appointment instead of burying it in Upcoming.
  const todayAppt = !todayVisits.length
    ? upcoming.find((a) => easternDay(a.scheduled_start) === todayKey)
    : null;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {/* Must-knows ride above everything: the special request for this visit and
          each dog's standing instructions (blades/tools) plus door handling, so
          Paul has the how-to-cut answer in one glance mid-appointment without
          scrolling (client_sheet_surfaces_the_must_knows, Paul 2026-06-18). */}
      <MustKnows dogs={dogs} todayVisits={todayVisits} />

      {/* The visit being worked RIGHT NOW: front and center so photos, notes,
          and Riker need no scrolling mid-appointment (Paul, 2026-06-11). It
          returns to the history below once the day passes. */}
      {todayVisits.length > 0 && (
        <div className="ad-panel" style={{ borderLeft: '4px solid var(--ad-good, #1f8a4b)' }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8 }}>Today's visit</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {todayVisits.map((v) => <VisitEntry key={v.id} v={v} clientId={clientId} dogs={dogs} onChanged={load} />)}
          </div>
        </div>
      )}

      {/* Today's appointment, when it has not been started yet: floats to the top
          so the current appointment is never buried in Upcoming. The Today's-visit
          card above replaces it the moment a visit is logged. */}
      {todayAppt && (
        <div className="ad-panel" style={{ borderLeft: '4px solid var(--ad-good, #1f8a4b)' }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Today's appointment</div>
          <div style={{ fontSize: 16, fontWeight: 700 }}>
            {(() => { try { return new Date(todayAppt.scheduled_start).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }); } catch { return ''; } })()}
            {todayAppt.service_type ? ` · ${SERVICE_LABELS[todayAppt.service_type] || todayAppt.service_type}` : ''}
          </div>
          {/* The appointment is read-only until it is started. This turns it into
              the working visit (photos, notes, vibe) right here, so Paul never has
              to leave the record to begin. */}
          <button className="ad-btn" style={{ marginTop: 10 }} onClick={() => startVisit(todayAppt.id)} disabled={starting}>
            {starting ? 'Starting…' : 'Start the visit · add photos'}
          </button>
        </div>
      )}

      {/* Riker rides at the top too: mid-appointment he is the most-used tool. */}
      <RikerCapture clientId={clientId} clientName={c.name} onApplied={() => { load(); onChanged?.(); }} />

      {/* Semi-permanent header */}
      <div className="ad-panel" style={{ position: 'relative' }}>
        <HelpToggle corner items={[
          ['Tap any field', 'Most details (access notes, gate codes, who is home, your private thoughts) edit right here: tap the value, type, it saves.'],
          ['Add alternate address', 'Records a second place you sometimes groom this client, clickable to Maps.'],
          ['Status / No-fly', 'Flags a client (watch, or do-not-book) so the booking funnel and the rest of the app know.'],
          ['On each dog', 'Set breed, price, notes, and birthday. The price is what the visit charges.'],
          ['Log a visit', 'Adds a visit to the history below, with what you did, time, and what was collected.'],
          ['Photos', 'Each visit photo can go to the client, the Team gallery, the website, or be flagged. Their own help sits by the photos.'],
        ]} />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', flexWrap: 'wrap', gap: 8, paddingRight: 24 }}>
          <h2 style={{ margin: 0 }}>{c.name}{c.aka ? <span className="ad-mono" style={{ marginLeft: 8, opacity: 0.6, fontSize: 14 }}>{c.aka}</span> : null}</h2>
          <span className="ad-mono" style={{ fontSize: 12, opacity: 0.7 }}>{clientTag(c)}</span>
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
          {data.contact_links?.sms && (
            <Field label="Contact" value={<a className="ad-btn ad-btn--ghost ad-btn--sm" href={data.contact_links.sms}>Text the client</a>} />
          )}
          <Field label="Flags" value={(c.flags || []).join(', ')} />
          <Field label="Data gaps" value={(c.data_gaps || []).join(', ')} />
        </dl>
        <PlusCode client={c} onChanged={() => { load(); onChanged?.(); }} />
        <AltAddress client={c} onChanged={() => { load(); onChanged?.(); }} />
        <AccessNotes client={c} onChanged={() => { load(); onChanged?.(); }} />
        <OnsitePeople client={c} onChanged={() => { load(); onChanged?.(); }} />
        <MessageDraftTool client={c} onChanged={() => { load(); onChanged?.(); }} />
        {dogs.length > 0 && (() => {
          // Regular roster (regular + occasional) shows up top; past/other dogs
          // (former + deceased) are kept but tucked into a collapsed section so the
          // name is always findable without cluttering the working roster.
          const isPast = (d) => d.roster_status === 'former' || d.roster_status === 'deceased' || d.roster_status === 'moved';
          const active = dogs.filter((d) => !isPast(d));
          const past = dogs.filter(isPast);
          const reload = () => { load(); onChanged?.(); };
          return (
            <div style={{ marginTop: 14 }}>
              <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Dogs</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {active.map((d) => (<DogCard key={d.id} dog={d} onChanged={reload} />))}
              </div>
              {past.length > 0 && (
                <details style={{ marginTop: 10 }}>
                  <summary style={{ cursor: 'pointer', fontSize: 12, opacity: 0.6 }}>
                    Past and other dogs ({past.length})
                  </summary>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 8 }}>
                    {past.map((d) => (<DogCard key={d.id} dog={d} onChanged={reload} />))}
                  </div>
                </details>
              )}
            </div>
          );
        })()}
      </div>

      {/* People to notify: a spouse who also gets the appointment messages,
          or a temporary stand-in like a dog sitter, in addition to or instead
          of the client (extra_notification_people). Riker can add these by
          voice; this panel is the by-hand path and the review surface. */}
      <NotifyPeoplePanel clientId={clientId} />

      {/* Log a visit */}
      <LogVisitForm
        clientId={clientId}
        subscriberId={data.subscriber?.id || null}
        defaultService={c.service_type}
        dogs={dogs}
        onLogged={() => { load(); onChanged?.(); }}
      />

      {/* Book the next visit, in the system (admin booking; the engine's open
          times sized to this client's real duration, with Paul's soft
          override per operator_override_with_confirm). */}
      <BookVisitPanel clientId={clientId} clientName={c.name}
        dogs={dogs.filter((d) => !['former', 'deceased', 'moved'].includes(d.roster_status))}
        onBooked={() => { load(); onChanged?.(); }} />

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
          Visit history · {pastVisits.length}
        </div>
        {visits.length === 0 ? (
          <div style={{ opacity: 0.6 }}>No visits logged yet. The history grows one row per appointment as it happens.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {pastVisits.map((v) => (
              <VisitEntry key={v.id} v={v} clientId={clientId} dogs={dogs} onChanged={load} />
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
    charged: '',
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
        chargedCents: form.charged ? Math.round(parseFloat(form.charged) * 100) : null,
        amountCollectedCents: form.amount ? Math.round(parseFloat(form.amount) * 100) : null,
        paymentMethod: form.paymentMethod || null,
        dogIds: dogScores.length ? dogScores.map((d) => d.dog_id) : null,
        dogScores: dogScores.length ? dogScores : null,
        source: 'manual',
      });
      setForm((f) => ({ ...f, workDone: '', visitNotes: '', actualMinutes: '', charged: '', amount: '' }));
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
          Charged ($)<br />
          <input className="ad-input" type="number" min="0" step="0.01" value={form.charged} onChange={set('charged')} style={{ width: 100 }} />
        </label>
        <label style={{ fontSize: 13 }}>
          Paid ($)<br />
          <input className="ad-input" type="number" min="0" step="0.01" value={form.amount} onChange={set('amount')} style={{ width: 100 }} />
        </label>
        <label style={{ fontSize: 13 }}>
          Method<br />
          <select className="ad-select" value={form.paymentMethod} onChange={set('paymentMethod')}>
            <option value="">unset</option>
            <option value="square_in_person">Square</option>
            <option value="stripe_card">Stripe</option>
            <option value="cash">Cash</option>
            <option value="wallet">Wallet</option>
            <option value="invoice">Invoice</option>
            <option value="check">Check</option>
          </select>
        </label>
      </div>
      {/* Time-of-day capture (left / arrived / done) lives on the Today sheet per
          stop, in the field where it gets tapped. Here, just the total minutes. */}
      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'flex-end' }}>
        <label style={{ fontSize: 13 }}>
          Minutes<br />
          <input className="ad-input" type="number" min="1" value={form.actualMinutes} onChange={set('actualMinutes')} style={{ width: 80 }} />
        </label>
      </div>
      {(dogs || []).length > 0 && (
        <div>
          <div style={{ fontSize: 12, opacity: 0.6 }}>Vibe score</div>
          <div style={{ fontSize: 11, opacity: 0.55, marginTop: 2, lineHeight: 1.45 }}>
            1 unsafe / aggression, not eligible · 2 poor, conditional · 3 average · 4 cooperative · 5 a joy, anticipates you
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 6 }}>
            {dogs.filter((d) => !['former', 'deceased', 'moved'].includes(d.roster_status)).map((d) => (
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

// A Google Maps link. Exact coordinates first (the most reliable pin, and the
// only thing that survives a plus code stored without its town or a placeholder
// "PlusCode <town>" street address), then the plus code, then the address.
function mapsUrl(c) {
  const q = (c.geo_lat != null && c.geo_lng != null ? `${c.geo_lat},${c.geo_lng}` : '')
    || (c.location_plus || '').trim()
    || [c.location_address, c.location_zip].filter(Boolean).join(' ').trim();
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
        {client.geo_lat != null && client.geo_lng != null
          ? <span style={{ opacity: 0.5, fontSize: 12 }}> · maps uses exact coordinates</span>
          : client.location_plus ? <span style={{ opacity: 0.5, fontSize: 12 }}> · maps uses plus code</span> : null}
      </dd>
    </>
  );
}

// A second, alternate address for a client who works between two places (Lisa Irwin
// alternates home and her office). Shown clickable to Google Maps, with a label.
function AltAddress({ client, onChanged }) {
  const [editing, setEditing] = useState(false);
  const [label, setLabel] = useState(client.alt_label || '');
  const [addr, setAddr] = useState(client.alt_address || '');
  const [busy, setBusy] = useState(false);
  useEffect(() => { setLabel(client.alt_label || ''); setAddr(client.alt_address || ''); }, [client.alt_label, client.alt_address]);

  async function save() {
    setBusy(true);
    try { await setClientAlt(client.id, label, addr); setEditing(false); onChanged?.(); }
    finally { setBusy(false); }
  }
  const url = client.alt_address
    ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(client.alt_address)}`
    : null;

  return (
    <div style={{ marginTop: 12 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55, marginBottom: 2 }}>Alternate address</div>
      {editing ? (
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
          <input className="ad-input" value={label} onChange={(e) => setLabel(e.target.value)} placeholder="Label (e.g. Office)" style={{ flex: '1 1 140px' }} />
          <input className="ad-input" value={addr} onChange={(e) => setAddr(e.target.value)} placeholder="2322 NE 8th Rd, Ocala, FL 34470" style={{ flex: '2 1 240px' }} />
          <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setLabel(client.alt_label || ''); setAddr(client.alt_address || ''); setEditing(false); }}>Cancel</button>
        </div>
      ) : client.alt_address ? (
        <div style={{ fontSize: 14, display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          <span style={{ flex: 1, minWidth: 200 }}>
            {client.alt_label ? <span style={{ opacity: 0.7 }}>{client.alt_label}: </span> : null}
            <a href={url} target="_blank" rel="noreferrer" style={{ color: 'var(--ad-primary, #2563d8)' }}>{client.alt_address} ↗</a>
          </span>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
        </div>
      ) : (
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>+ Add alternate address</button>
      )}
    </div>
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
function DogField({ label, value, placeholder, onSave, variant }) {
  const [editing, setEditing] = useState(false);
  const [val, setVal] = useState(value || '');
  const [busy, setBusy] = useState(false);
  useEffect(() => { setVal(value || ''); }, [value]);

  async function save() {
    setBusy(true);
    try { await onSave(val); setEditing(false); }
    finally { setBusy(false); }
  }

  const editor = (
    <div style={{ marginTop: 4 }}>
      <textarea className="ad-textarea" rows={2} value={val} onChange={(e) => setVal(e.target.value)} style={{ width: '100%' }} placeholder={placeholder} />
      <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
        <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{busy ? 'Saving…' : 'Save'}</button>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setVal(value || ''); setEditing(false); }}>Cancel</button>
      </div>
    </div>
  );

  // The "standing" variant is the must-see handling instruction for the dog:
  // an amber callout that jumps out when Paul scans the card, not a quiet row.
  if (variant === 'standing') {
    return (
      <div className="ad-standing">
        <div className="ad-standing__label">{'★'} {label}</div>
        {editing ? editor : value ? (
          <div className="ad-standing__row">
            <span className="ad-standing__value">{value}</span>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(true)}>Edit</button>
          </div>
        ) : (
          <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ marginTop: 4 }} onClick={() => setEditing(true)}>+ Add standing instructions</button>
        )}
      </div>
    );
  }

  return (
    <div style={{ marginTop: 6 }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.5 }}>{label}</div>
      {editing ? editor : value ? (
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

// The old "time is money" append-helper export lived here as a tiny link. It is
// retired (Paul, 2026-06-15): the parallel manual sheet is being retired, so there is
// nothing to append rows onto. The full-history backup now lives in Reports as the
// Ledger Keeper's weekly Google Sheet. See time_is_money_weekly_backup in the Oracle.

// Small chip showing a dog's standing on the roster. 'regular' is the default and
// shows nothing (no clutter); the rest get a quiet label so a name is never a mystery.
function DogStatusChip({ status }) {
  if (!status || status === 'regular') return null;
  const map = {
    occasional: { label: 'sometimes', bg: '#eef2ff', fg: '#3a44b0' },
    moved: { label: 'moved', bg: '#fdf0e1', fg: '#9a5b1a' },
    former: { label: 'former', bg: '#f1f1f4', fg: '#666' },
    deceased: { label: 'deceased', bg: '#f1f1f4', fg: '#888' },
  };
  const s = map[status] || { label: status, bg: '#f1f1f4', fg: '#666' };
  return (
    <span style={{ marginLeft: 6, fontSize: 10, textTransform: 'uppercase', letterSpacing: 0.4,
      background: s.bg, color: s.fg, borderRadius: 6, padding: '1px 6px', verticalAlign: 'middle' }}>
      {s.label}
    </span>
  );
}

// Age from a birth_date (date-only string): years and months, e.g. "7 yr 9 mo"
// (just months under a year, just years on an exact birthday), with a ~ when the
// date is estimated.
function ageFromBirthDate(dateStr, approximate) {
  if (!dateStr) return '';
  const b = new Date(dateStr + 'T12:00:00');
  if (Number.isNaN(b.getTime())) return '';
  const now = new Date();
  let years = now.getFullYear() - b.getFullYear();
  let months = now.getMonth() - b.getMonth();
  if (now.getDate() < b.getDate()) months--;
  if (months < 0) { years--; months += 12; }
  if (years < 0) return '';
  const tilde = approximate ? '~' : '';
  if (years < 1) return `${tilde}${months} mo`;
  if (months === 0) return `${tilde}${years} yr`;
  return `${tilde}${years} yr ${months} mo`;
}

// Door-handling toggles (dog_handling_toggles). `door` is the short chip shown on
// the must-knows banner; `label` is the full toggle on the dog card. Keys must
// match the dogs_handling_flags_known DB constraint (migration 0208).
// Door handling (dog_handling_toggles). Each concern is OFF, "usually" (how Paul
// normally does it, a preference), or "always" (a firm rule). The distinction
// matters: most handling is a preference, but some of it (a dog that fights other
// dogs) is a hard rule that has to jump out. Labels read plainly so a new operator
// understands every one without being told.
// Door handling, simplified (dog_handling_toggles). Two parts: how the dog gets
// to the trailer (carry or leash, one pick), and a few plain warnings. No
// usual/always gradient, because these are facts, not preferences.
const TRANSPORT_LABEL = { carry: 'Carry in and out', leash: 'Walk on a leash' };
const DOOR_FLAGS = [
  { key: 'escape',        label: 'Escape risk',                  warn: true },
  { key: 'keep_separate', label: 'Keep apart from other animals', warn: true },
  { key: 'loose_ok',      label: 'OK to turn loose',              warn: false },
];
const WARN_LABEL = { escape: 'Escape risk, keep control at the door', keep_separate: 'Keep away from other animals' };

function PickBtn({ label, on, onClick, disabled, first }) {
  return (
    <button type="button" onClick={onClick} disabled={disabled}
      style={{ fontSize: 12, padding: '5px 14px', border: 'none', cursor: 'pointer',
        borderLeft: first ? 'none' : '1px solid var(--ad-outline,#ececf1)',
        background: on ? 'var(--ad-primary,#2563d8)' : 'transparent',
        color: on ? '#fff' : 'var(--ad-text,#1c1d22)', fontWeight: on ? 600 : 400 }}>
      {label}
    </button>
  );
}

// The dog-card editor: a Carry/Leash pick (which answers "bring a leash to the
// door?") and on/off warning chips. Optimistic, saves on tap, reverts on failure.
function DoorHandling({ dog, onChanged }) {
  const [dh, setDh] = useState(dog.door_handling || {});
  const [saving, setSaving] = useState(false);
  useEffect(() => { setDh(dog.door_handling || {}); }, [dog.door_handling]);
  const save = async (next) => {
    setDh(next); setSaving(true);
    try { await setDogDoorHandling(dog.id, next); onChanged?.(); }
    catch { setDh(dog.door_handling || {}); }
    finally { setSaving(false); }
  };
  const setTransport = (t) => { const n = { ...dh }; if (n.transport === t) delete n.transport; else n.transport = t; save(n); };
  const toggle = (k) => { const n = { ...dh }; if (n[k]) delete n[k]; else n[k] = true; save(n); };
  return (
    <div style={{ margin: '2px 0 6px' }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.3, opacity: 0.55, marginBottom: 6 }}>At the door</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 8 }}>
        <span style={{ fontSize: 13 }}>How I take this dog</span>
        <div style={{ display: 'inline-flex', borderRadius: 8, overflow: 'hidden', border: '1px solid var(--ad-outline,#d8d8de)' }}>
          <PickBtn label="Carry" first on={dh.transport === 'carry'} onClick={() => setTransport('carry')} disabled={saving} />
          <PickBtn label="Leash" on={dh.transport === 'leash'} onClick={() => setTransport('leash')} disabled={saving} />
        </div>
      </div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        {DOOR_FLAGS.map((c) => {
          const on = !!dh[c.key];
          const onColor = c.warn ? 'var(--ad-bad,#dc2626)' : 'var(--ad-good,#1f8a4b)';
          return (
            <button key={c.key} type="button" onClick={() => toggle(c.key)} disabled={saving}
              style={{ fontSize: 12, padding: '5px 11px', borderRadius: 999, cursor: 'pointer',
                border: on ? `1px solid ${onColor}` : '1px solid var(--ad-outline,#d8d8de)',
                background: on ? onColor : 'transparent',
                color: on ? '#fff' : 'var(--ad-text,#1c1d22)', fontWeight: on ? 600 : 400 }}>
              {c.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}

// Pull the loud warnings and the calm facts out of a dog's door handling.
function doorBits(dog) {
  const dh = dog.door_handling || {};
  return {
    warns: ['escape', 'keep_separate'].filter((k) => dh[k]),
    transport: dh.transport ? TRANSPORT_LABEL[dh.transport] : null,
    looseOk: !!dh.loose_ok,
  };
}

// The must-knows banner that rides at the very top of the sheet
// (client_sheet_surfaces_the_must_knows): the special request for this visit and,
// per active dog, the loud door warnings (red), the standing instructions (blades
// and tools), then the calm door facts. What Paul needs in one glance, no scroll.
function MustKnows({ dogs, todayVisits }) {
  const active = (dogs || []).filter((d) => !['former', 'deceased', 'moved'].includes(d.roster_status));
  const requests = (todayVisits || []).map((v) => v.special_request).filter(Boolean);
  const rows = active.map((d) => ({ d, ...doorBits(d) }))
    .filter((r) => r.d.standing_instructions || r.warns.length || r.transport || r.looseOk || r.d.handling);
  if (requests.length === 0 && rows.length === 0) return null;
  return (
    <div className="ad-panel" style={{ borderLeft: '4px solid var(--ad-warn,#b9770a)', background: 'var(--ad-warn-bg,#fff8ec)' }}>
      <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, fontWeight: 700, color: 'var(--ad-warn,#b9770a)', marginBottom: 8 }}>Before you start</div>
      {requests.length > 0 && (
        <div style={{ marginBottom: rows.length ? 12 : 0 }}>
          <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.3, opacity: 0.6, marginBottom: 2 }}>Special request this visit</div>
          {requests.map((r, i) => (<div key={i} style={{ fontSize: 15, fontWeight: 600, lineHeight: 1.35 }}>{r}</div>))}
        </div>
      )}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {rows.map(({ d, warns, transport, looseOk }) => (
          <div key={d.id}>
            <div style={{ fontSize: 13, fontWeight: 700 }}>{d.name}</div>
            {warns.map((k) => (
              <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
                <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.4, padding: '1px 6px', borderRadius: 4, background: 'var(--ad-bad,#dc2626)', color: '#fff' }}>HEADS UP</span>
                <span style={{ fontSize: 14, fontWeight: 600 }}>{WARN_LABEL[k]}</span>
              </div>
            ))}
            {d.standing_instructions && <div style={{ fontSize: 14, lineHeight: 1.4, marginTop: 3 }}>{d.standing_instructions}</div>}
            {transport && <div style={{ fontSize: 13, opacity: 0.8, marginTop: 3 }}>{transport}</div>}
            {looseOk && (
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
                <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: 0.4, padding: '1px 6px', borderRadius: 4, background: 'var(--ad-primary,#2563d8)', color: '#fff' }}>ASK</span>
                <span style={{ fontSize: 13, fontWeight: 600 }}>OK to turn loose, but verify with the client first</span>
              </div>
            )}
            {d.handling && <div style={{ fontSize: 13, opacity: 0.8, marginTop: 3 }}>{d.handling}</div>}
          </div>
        ))}
      </div>
    </div>
  );
}

function DogCard({ dog, onChanged }) {
  const isPast = ['former', 'deceased', 'moved'].includes(dog.roster_status);
  const age = dog.roster_status === 'deceased' ? '' : ageFromBirthDate(dog.birth_date, dog.dob_approximate);
  const meta = [dog.breed, age].filter(Boolean).join(' · ');
  return (
    <div className={`ad-dogcard${isPast ? ' ad-dogcard--past' : ''}`}>
      <div className="ad-dogcard__head">
        <span className="ad-dogcard__name">{dog.name}</span>
        {meta && <span className="ad-dogcard__meta">{meta}</span>}
        <DogStatusChip status={dog.roster_status} />
        {dog.price_cents != null && <span className="ad-dogcard__price">{money(dog.price_cents)}</span>}
      </div>
      <div className="ad-dogcard__body">
      <DogField label="Standing instructions" variant="standing" value={dog.standing_instructions}
        placeholder="How to handle this dog every time (e.g. 8mm comb on body, hates the dryer, do nails first)"
        onSave={async (v) => { await setDogStanding(dog.id, v); onChanged?.(); }} />
      <DogField label="Handling (we've got this)" value={dog.handling}
        placeholder="How to handle this dog: hold this way, sore hip, give a minute to settle. A care note, not a warning."
        onSave={async (v) => { await setDogHandling(dog.id, v); onChanged?.(); }} />
      <DoorHandling dog={dog} onChanged={onChanged} />
      <DogField label="About this dog (always)" value={dog.notes}
        placeholder="Anything that stays true about this dog (e.g. moved to Tampa, on psych meds, sister's dog)"
        onSave={async (v) => { await setDogNote(dog.id, v); onChanged?.(); }} />
      <DogBirthday dog={dog} onChanged={onChanged} />
      <DogFollowups dogId={dog.id} />
      <DogRosterControl dog={dog} onChanged={onChanged} />
      </div>
    </div>
  );
}

// The archive control: set a dog's standing on the roster (or restore it). Setting
// it to moved/former/deceased takes the dog off the working roster (it folds into
// "Past and other dogs") without ever deleting its record or history; setting it
// back to regular restores it. Collapsed by default so it does not crowd the card.
function DogRosterControl({ dog, onChanged }) {
  const [busy, setBusy] = useState(false);
  const status = dog.roster_status || 'regular';
  const OPTIONS = [
    ['regular', 'Regular'],
    ['occasional', 'Sometimes'],
    ['moved', 'Moved away'],
    ['former', 'Former'],
    ['deceased', 'Deceased'],
  ];
  async function change(v) {
    if (v === status) return;
    setBusy(true);
    try { await setDogStatus(dog.id, v); onChanged?.(); }
    finally { setBusy(false); }
  }
  return (
    <details style={{ marginTop: 6 }}>
      <summary style={{ cursor: 'pointer', fontSize: 11, opacity: 0.55 }}>Roster status</summary>
      <div style={{ marginTop: 6, display: 'flex', alignItems: 'center', gap: 8 }}>
        <select value={status} disabled={busy} onChange={(e) => change(e.target.value)}
          style={{ fontSize: 12, padding: '3px 6px', borderRadius: 6, border: '1px solid var(--ad-outline, #d9dbe6)' }}>
          {OPTIONS.map(([v, label]) => (<option key={v} value={v}>{label}</option>))}
        </select>
        <span style={{ fontSize: 11, opacity: 0.5 }}>archive without losing the record</span>
      </div>
    </details>
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
          <div style={{ fontSize: 12.5, lineHeight: 1.55, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div>
              <strong style={{ color: 'var(--ad-warn, #b9770a)' }}>Shadow ban: they stay a client and still get served, but you stop chasing them.</strong>
              {' '}They keep their record and their place in the book, and if they book or show up you still take care of them. What stops is every nudge from your side: no win-back when they go quiet, no outreach, no marketing. The relationship just goes cold on its own, with no confrontation. Use it for someone you would rather not keep but do not need to refuse outright.
            </div>
            <div>
              <strong style={{ color: 'var(--ad-bad, #dc2626)' }}>Hard ban: they leave every working list, so they never surface in your day and nothing goes out to them again.</strong>
              {' '}They drop off your routes, rosters, win-back, and all outreach. Because they are off every list, no appointment gets booked and no message ever gets sent from your side. Their record is not deleted: the name, the history, and your private reason are kept on purpose, so the ban sticks and the same person cannot quietly come back as a new client. It is fully reversible right here if you change your mind. Use it for a true no-fly: someone you will not serve again.
            </div>
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

// ── People to notify ──────────────────────────────────────────────────────
// Extra recipients for this client's appointment messages: a spouse who also
// wants the texts (standing), or Jane's dog sitter while she travels
// (temporary, with an end date), in addition to or instead of the client.
// The reminder dispatcher reads the same rows, so what shows here is exactly
// who gets the messages. Text sends start when Twilio lands; email rides now.
function NotifyPeoplePanel({ clientId }) {
  const [people, setPeople] = useState(null);
  const [adding, setAdding] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);
  const [form, setForm] = useState({ name: '', phone: '', email: '', relationship: '', mode: 'in_addition', until: '' });

  const load = useCallback(async () => {
    try { setPeople(await listNotifyPeople(clientId)); }
    catch (e) { setErr(e.message || 'load_failed'); }
  }, [clientId]);
  useEffect(() => { load(); }, [load]);

  async function save() {
    if (!form.name.trim() || (!form.phone.trim() && !form.email.trim())) { setErr('Name plus a phone or email.'); return; }
    setBusy(true); setErr(null);
    try {
      await upsertNotifyPerson({ client_id: clientId, name: form.name, phone: form.phone, email: form.email, relationship: form.relationship, mode: form.mode, until: form.until || null });
      setForm({ name: '', phone: '', email: '', relationship: '', mode: 'in_addition', until: '' });
      setAdding(false);
      await load();
    } catch (e) { setErr(e.message || 'save_failed'); }
    finally { setBusy(false); }
  }
  async function toggle(p) {
    setBusy(true); setErr(null);
    try { await setNotifyPersonActive(p.id, !p.active); await load(); }
    catch (e) { setErr(e.message || 'toggle_failed'); }
    finally { setBusy(false); }
  }
  async function remove(p) {
    setBusy(true); setErr(null);
    try { await deleteNotifyPerson(p.id); await load(); }
    catch (e) { setErr(e.message || 'delete_failed'); }
    finally { setBusy(false); }
  }

  const lapsed = (p) => p.until_date && new Date(p.until_date + 'T23:59:59') < new Date();
  const inputStyle = { fontSize: 13, padding: '6px 8px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)' };

  if (people === null && !err) return null;
  if ((people || []).length === 0 && !adding) {
    return (
      <div className="ad-panel">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>People to notify</div>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setAdding(true)}>+ Add a person</button>
        </div>
        <div style={{ fontSize: 12, opacity: 0.55, marginTop: 4 }}>
          Appointment messages go to the client. Add a spouse who also wants them, or a temporary stand-in like a dog sitter.
        </div>
        {err && <div className="ad-error" style={{ marginTop: 6 }}>{err}</div>}
      </div>
    );
  }

  return (
    <div className="ad-panel">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>People to notify</div>
        {!adding && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setAdding(true)}>+ Add a person</button>}
      </div>

      {(people || []).map((p) => (
        <div key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '7px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)', flexWrap: 'wrap' }}>
          <span style={{ flex: 1, minWidth: 160, fontSize: 14, opacity: p.active && !lapsed(p) ? 1 : 0.45 }}>
            <strong>{p.name}</strong>
            {p.relationship ? <span style={{ opacity: 0.6 }}> ({p.relationship})</span> : null}
            <span style={{ display: 'block', fontSize: 12, opacity: 0.65 }}>
              {[p.phone_e164, p.email].filter(Boolean).join(' · ')}
              {' · '}{p.mode === 'instead' ? 'instead of the client' : 'in addition'}
              {p.until_date ? ` · until ${p.until_date}${lapsed(p) ? ' (ended)' : ''}` : ''}
              {!p.active ? ' · off' : ''}
            </span>
          </span>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => toggle(p)}>
            {p.active ? 'Turn off' : 'Turn on'}
          </button>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => remove(p)} title="remove entirely">x</button>
        </div>
      ))}

      {adding && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 10 }}>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <input style={{ ...inputStyle, flex: 1, minWidth: 140 }} placeholder="Name" value={form.name} disabled={busy}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
            <input style={{ ...inputStyle, flex: 1, minWidth: 120 }} placeholder="Relationship (spouse, dog sitter)" value={form.relationship} disabled={busy}
              onChange={(e) => setForm((f) => ({ ...f, relationship: e.target.value }))} />
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <input style={{ ...inputStyle, flex: 1, minWidth: 140 }} type="tel" placeholder="Phone (+1...)" value={form.phone} disabled={busy}
              onChange={(e) => setForm((f) => ({ ...f, phone: e.target.value }))} />
            <input style={{ ...inputStyle, flex: 1, minWidth: 160 }} type="email" placeholder="Email" value={form.email} disabled={busy}
              onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))} />
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <select style={inputStyle} value={form.mode} disabled={busy} onChange={(e) => setForm((f) => ({ ...f, mode: e.target.value }))}>
              <option value="in_addition">In addition to the client</option>
              <option value="instead">Instead of the client</option>
            </select>
            <label style={{ fontSize: 12, opacity: 0.6, display: 'inline-flex', alignItems: 'center', gap: 6 }}>
              until
              <input style={inputStyle} type="date" value={form.until} disabled={busy}
                onChange={(e) => setForm((f) => ({ ...f, until: e.target.value }))} />
              <span style={{ opacity: 0.7 }}>(blank = standing)</span>
            </label>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{busy ? '...' : 'Save'}</button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setAdding(false); setErr(null); }} disabled={busy}>Cancel</button>
          </div>
        </div>
      )}
      {err && <div className="ad-error" style={{ marginTop: 6 }}>{err}</div>}
    </div>
  );
}

// ── Book the next visit ───────────────────────────────────────────────────
// Pick a day, see the engine's open times sized to this client's own
// duration, tap one, booked. A time the engine refuses (off-window evening,
// off-week day, too tight) gets the soft override: the conflict is named and
// one more tap books it anyway (operator_override_with_confirm). Clients
// never get that tap; Paul does, because he knows things the engine cannot.
// App-booked appointments live in the system as the source; until the
// calendar flip, the "Add to Google Calendar" link keeps his working calendar
// in the loop with one tap.
function BookVisitPanel({ clientId, clientName, dogs = [], onBooked }) {
  const [open, setOpen] = useState(false);
  const [sugg, setSugg] = useState(null);       // suggestSlotsWithDrive payload
  const [dogSel, setDogSel] = useState(() => new Set(dogs.map((d) => d.id)));
  const [more, setMore] = useState(false);      // the manual fallback flow
  const [date, setDate] = useState(() => {
    const d = new Date(Date.now() + 86400000);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  });
  const [slots, setSlots] = useState(null);
  const [manualTime, setManualTime] = useState('');
  const [conflict, setConflict] = useState(null);
  const [booked, setBooked] = useState(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);

  async function openPanel() {
    setOpen(true); setBusy(true); setErr(null);
    setDogSel(new Set(dogs.map((d) => d.id)));
    try { setSugg(await suggestSlotsWithDrive(clientId)); }
    catch (e) { setErr(e.message || 'suggest_failed'); }
    finally { setBusy(false); }
  }

  async function loadSlots() {
    setBusy(true); setErr(null); setSlots(null); setConflict(null);
    try {
      const res = await adminOpenSlots(clientId, date, 1);
      setSlots(res?.slots || []);
    } catch (e) { setErr(e.message || 'slots_failed'); }
    finally { setBusy(false); }
  }

  async function book(startISO, override = false) {
    setBusy(true); setErr(null);
    // A proper subset of the roster rides as an explicit assignment; the full
    // roster stays null (the everyone-goes default).
    const dogIds = dogs.length > 1 && dogSel.size > 0 && dogSel.size < dogs.length
      ? [...dogSel] : null;
    try {
      const res = await adminBookAppointment(clientId, startISO, override, dogIds);
      if (res?.ok) {
        setBooked(res);
        setConflict(null);
        onBooked?.();
      } else if (res?.error === 'slot_conflict') {
        setConflict({ startISO, overlaps: res.overlaps || [] });
      } else if (res?.error === 'overlaps_existing') {
        setErr('That time overlaps an existing stop minute for minute. Pick another.');
        setConflict(null);
      } else {
        setErr(res?.error || 'booking_failed');
      }
    } catch (e) { setErr(e.message || 'booking_failed'); }
    finally { setBusy(false); }
  }

  const fmtSlot = (iso) => new Date(iso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
  const fmtDay = (d) => new Date(`${d}T12:00:00`).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  const offsetLabel = (n) => n == null ? 'soonest' : n === 0 ? 'on time' : n > 0 ? `${n} day${n === 1 ? '' : 's'} late` : `${-n} day${n === -1 ? '' : 's'} early`;
  function manualISO() {
    if (!manualTime) return null;
    return new Date(`${date}T${manualTime}:00`).toISOString();
  }
  function gcalLink(res) {
    const f = (iso) => new Date(iso).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
    const params = new URLSearchParams({
      action: 'TEMPLATE',
      text: clientName || 'Dog Gone Clean visit',
      dates: `${f(res.scheduled_start)}/${f(res.scheduled_end)}`,
      details: 'Booked in Laelaps (Dog Gone Clean).',
    });
    return `https://calendar.google.com/calendar/render?${params}`;
  }

  if (!open) {
    return (
      <div className="ad-panel">
        <button className="ad-btn ad-btn--sm" onClick={openPanel}>Book next visit</button>
      </div>
    );
  }

  const cadWeeks = sugg?.cadence_days && sugg.cadence_days % 7 === 0 ? sugg.cadence_days / 7 : null;

  return (
    <div className="ad-panel">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>
          Book next visit{sugg?.duration_minutes ? ` (${sugg.duration_minutes} min)` : ''}
        </div>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setOpen(false); setBooked(null); setMore(false); setConflict(null); }}>Close</button>
      </div>

      {booked ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 8 }}>
          <div style={{ fontSize: 14 }}>
            Booked: <strong>{new Date(booked.scheduled_start).toLocaleString('en-US', { weekday: 'long', month: 'long', day: 'numeric', hour: 'numeric', minute: '2-digit' })}</strong>
            {booked.overridden ? <span style={{ color: 'var(--ad-warn,#b9770a)' }}> (override)</span> : ''}
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <a className="ad-btn ad-btn--ghost ad-btn--sm" href={gcalLink(booked)} target="_blank" rel="noreferrer">
              Add to Google Calendar
            </a>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setBooked(null); openPanel(); }}>Book another</button>
          </div>
          <div style={{ fontSize: 11, opacity: 0.55 }}>
            Until the calendar flip, tap Add to Google Calendar so your working calendar shows it too.
          </div>
        </div>
      ) : conflict ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 8 }}>
          <div style={{ fontSize: 14 }}>
            The engine would not offer <strong>{fmtSlot(conflict.startISO)}</strong>
            {conflict.overlaps.length > 0
              ? <> because it brushes {conflict.overlaps.map((o) => `${o.client || 'another stop'} at ${fmtSlot(o.start)}`).join(', ')}.</>
              : ' (outside the working windows for that day, or an off week).'}
            {' '}You know things it does not. Book anyway?
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="ad-btn ad-btn--sm" disabled={busy} onClick={() => book(conflict.startISO, true)}>
              {busy ? '...' : 'Yes, book it'}
            </button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => setConflict(null)}>No, pick another</button>
          </div>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 8 }}>
          {busy && !sugg && <div style={{ fontSize: 13, opacity: 0.6 }}>Working out when they are due...</div>}

          {sugg?.next_booked && (
            <div style={{ fontSize: 13, padding: '8px 10px', borderRadius: 8, background: 'var(--ad-primary-container, #e6edfc)' }}>
              {sugg.next_booked_status === 'tentative' ? 'Penciled in (your calendar pencil, not client-official): ' : 'Already booked: '}
              <strong>{new Date(sugg.next_booked).toLocaleString('en-US', { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}</strong>
              {sugg.next_booked_offset_days != null && sugg.next_booked_offset_days !== 0 && (
                <span style={{ opacity: 0.7 }}> ({offsetLabel(sugg.next_booked_offset_days)} against their rhythm)</span>
              )}
            </div>
          )}

          {dogs.length > 1 && (
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center' }}>
              <span style={{ fontSize: 12, opacity: 0.55 }}>Who's going:</span>
              {dogs.map((d) => {
                const on = dogSel.has(d.id);
                return (
                  <button key={d.id} type="button" disabled={busy}
                    onClick={() => setDogSel((prev) => {
                      const nx = new Set(prev);
                      if (nx.has(d.id)) { if (nx.size > 1) nx.delete(d.id); } else nx.add(d.id);
                      return nx;
                    })}
                    style={{ fontSize: 12, padding: '3px 10px', borderRadius: 999, cursor: 'pointer',
                      border: '1px solid ' + (on ? 'var(--ad-primary, #2f5fd0)' : 'var(--ad-outline, #d8d8de)'),
                      background: on ? 'var(--ad-primary-container, #e6edfc)' : 'transparent',
                      opacity: on ? 1 : 0.6 }}>
                    {d.name}
                  </button>
                );
              })}
            </div>
          )}

          {sugg && (
            <div style={{ fontSize: 13 }}>
              {sugg.due_date ? (
                <>Due <strong>{fmtDay(sugg.due_date)}</strong>
                  {cadWeeks ? ` (every ${cadWeeks} week${cadWeeks === 1 ? '' : 's'}` : sugg.cadence_days ? ` (every ${sugg.cadence_days} days` : ''}
                  {sugg.last_visit ? `; last visit ${fmtDay(sugg.last_visit)})` : ')'}
                </>
              ) : (
                <>No cadence on file; showing the soonest open times.</>
              )}
              {sugg.window_note && (
                <div style={{ opacity: 0.65, marginTop: 2 }}>Their window: {sugg.window_note}</div>
              )}
            </div>
          )}

          {sugg && (sugg.days || []).length === 0 && (
            <div style={{ fontSize: 13, opacity: 0.7 }}>
              Nothing fits their window near the due date (booked solid, off weeks, or the visit is too long for their hours). Use More options to force a time.
            </div>
          )}

          {(sugg?.days || []).map((day) => (
            <div key={day.date} style={{ border: '1px solid var(--ad-outline, #ececf1)', borderRadius: 10, padding: '8px 10px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
                <strong style={{ fontSize: 14 }}>{fmtDay(day.date)}</strong>
                <span style={{ fontSize: 11, fontWeight: 700, padding: '1px 8px', borderRadius: 999,
                  color: day.offset_days === 0 ? '#1f8a4b' : 'var(--ad-warn,#b9770a)',
                  background: day.offset_days === 0 ? 'rgba(31,138,75,0.1)' : 'rgba(185,119,10,0.1)' }}>
                  {offsetLabel(day.offset_days)}
                </span>
              </div>
              <div style={{ fontSize: 11, opacity: 0.6, margin: '2px 0 6px' }}>
                {(day.day_stops || []).length === 0
                  ? 'Nothing booked that day yet.'
                  : 'That day so far: ' + day.day_stops.map((s) => `${fmtSlot(s.start)} ${s.client || 'a stop'}${s.tentative ? ' (penciled)' : ''}`).join(', ')}
              </div>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                {(day.slots || []).map((s) => {
                  const start = typeof s === 'string' ? s : s.start;
                  const drive = [];
                  if (typeof s === 'object' && s.prev_stop) {
                    const who = (s.prev_stop.client || 'the stop before').split(' ')[0];
                    const d = s.prev_stop.drive_minutes != null ? `${s.prev_stop.drive_minutes} min drive from ${who}` : `drive from ${who}`;
                    const w = s.prev_stop.wait_minutes != null
                      ? (s.prev_stop.wait_minutes <= 0 ? ', back to back' : `, then ${s.prev_stop.wait_minutes} min wait`)
                      : '';
                    drive.push(d + w);
                  }
                  if (typeof s === 'object' && s.next_stop) {
                    const who = (s.next_stop.client || 'the next stop').split(' ')[0];
                    const d = s.next_stop.drive_minutes != null ? `${s.next_stop.drive_minutes} min drive to ${who}` : `drive to ${who}`;
                    const w = s.next_stop.wait_minutes != null
                      ? (s.next_stop.wait_minutes <= 0 ? ', tight' : `, ${s.next_stop.wait_minutes} min to spare`)
                      : '';
                    drive.push(d + w);
                  }
                  const tight = typeof s === 'object' && s.tightest;
                  return (
                    <button key={start} className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => book(start)}
                      style={{
                        ...(drive.length ? { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 1, lineHeight: 1.25 } : {}),
                        ...(tight ? { borderColor: 'var(--ad-good, #1f8a4b)' } : {}),
                      }}>
                      <span>{fmtSlot(start)}{tight ? <span style={{ fontSize: 10, color: 'var(--ad-good, #1f8a4b)', fontWeight: 700 }}> · tightest fit</span> : null}</span>
                      {drive.length > 0 && <span style={{ fontSize: 10, opacity: 0.65, fontWeight: 400 }}>{drive.join(' · ')}</span>}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}

          <button type="button" onClick={() => setMore((v) => !v)}
            style={{ alignSelf: 'flex-start', background: 'transparent', border: 0, padding: 0,
              fontSize: 12, color: 'var(--ad-text-dim,#565b6c)', textDecoration: 'underline', cursor: 'pointer' }}>
            {more ? 'hide more options' : 'More options (any day, any time)'}
          </button>

          {more && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
                <input type="date" value={date} disabled={busy} onChange={(e) => { setDate(e.target.value); setSlots(null); }}
                  style={{ fontSize: 14, padding: '7px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)' }} />
                <button className="ad-btn ad-btn--sm" disabled={busy || !date} onClick={loadSlots}>
                  Show open times
                </button>
              </div>
              {slots !== null && (
                slots.length === 0 ? (
                  <div style={{ fontSize: 13, opacity: 0.65 }}>
                    No engine-open times that day. Use a custom time below if you want it anyway.
                  </div>
                ) : (
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    {slots.map((s) => (
                      <button key={s.start} className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => book(s.start)}>
                        {fmtSlot(s.start)}
                      </button>
                    ))}
                  </div>
                )
              )}
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                <span style={{ fontSize: 12, opacity: 0.55 }}>Custom time:</span>
                <input type="time" value={manualTime} disabled={busy} onChange={(e) => setManualTime(e.target.value)}
                  style={{ fontSize: 14, padding: '6px 8px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)' }} />
                <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy || !manualTime}
                  onClick={() => { const iso = manualISO(); if (iso) book(iso); }}>
                  Book this time
                </button>
              </div>
            </div>
          )}
        </div>
      )}
      {err && <div className="ad-error" style={{ marginTop: 6 }}>{err}</div>}
    </div>
  );
}


// One visit record: the unit of the history list AND the pinned today's-visit
// panel, so the two can never drift apart.
function VisitEntry({ v, clientId, dogs, onChanged }) {
  return (
              <div style={{ borderLeft: '3px solid var(--ad-primary, #2563d8)', paddingLeft: 12 }}>
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
                        {r.note ? <span style={{ color: 'var(--ad-text)' }}>{r.note}</span> : null}
                      </div>
                    ))}
                  </div>
                )}
                {v.work_done ? <div style={{ fontSize: 14, marginTop: 2 }}>{v.work_done}</div> : null}
                {v.visit_notes ? <div className="ad-visitnote">{v.visit_notes}</div> : null}
                {(v.condition_flags || []).length > 0 && (
                  <div style={{ marginTop: 4, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    {v.condition_flags.map((f) => (
                      <span key={f} className="ad-mono" style={{ fontSize: 11, background: 'var(--ad-surface-container-high, #eef1fb)', borderRadius: 6, padding: '1px 6px' }}>{f}</span>
                    ))}
                  </div>
                )}
                <VisitPhotos visitId={v.id} clientId={clientId} photos={v.photos || []} dogs={dogs.filter((d) => !['former', 'deceased', 'moved'].includes(d.roster_status))} onChanged={onChanged} />
              </div>
  );
}
