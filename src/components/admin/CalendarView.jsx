// src/components/admin/CalendarView.jsx
//
// The Calendar floor: the appointment schedule as an agenda, grouped by day,
// newest window around today. Display is unchanged; each UPCOMING visit now
// carries a low-key "manage" link that opens deliberate Reschedule and Cancel
// actions (owner authority, no client-style 24-hour lock). New bookings still
// come in through the /book funnel. Reschedule/cancel run through the admin_*
// RPCs and reload the agenda on success.

import { useCallback, useEffect, useRef, useState } from 'react';
import { calendar, adminRescheduleAppointment, adminCancelAppointment } from './supabase.js';

const SERVICE = { full_groom: 'Full groom', bath: 'Bath', nails: 'Nails' };
const STATUS_COLOR = { confirmed: 'var(--ad-good,#1f8a4b)', tentative: 'var(--ad-accent,#2563eb)', requested: 'var(--ad-warn,#b9770a)', completed: 'var(--ad-text-dim,#565b6c)', cancelled: 'var(--ad-bad,#dc2626)', no_show: 'var(--ad-bad,#dc2626)' };
// A tentative appointment is one you pencilled in with a trailing "?" in your
// calendar. It is your private placeholder and never shown to the client; here
// in your own operator view it reads as "pencilled" so you can tell it apart.
const STATUS_LABEL = { tentative: 'pencilled' };
// Only an upcoming, still-open visit can be reshuffled. Past, completed, and
// cancelled rows stay look-only.
const ACTIONABLE = new Set(['requested', 'confirmed', 'tentative']);
const RESCHEDULE_ERR = {
  overlap: 'That time runs into another visit. Pick a different time.',
  not_reschedulable: 'This visit can no longer be moved.',
  not_found: 'Could not find that visit, try reloading.',
  no_time: 'Pick a date and time first.',
};

function money(c) { return c == null ? '' : '$' + Math.round(c / 100); }
function dayKey(ts) { return new Date(ts).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }); }
function time(ts) { try { return new Date(ts).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }); } catch { return ''; } }
function pad2(n) { return String(n).padStart(2, '0'); }
// Current start as a value the datetime-local input understands, in device-local
// time (Paul's Eastern), so the picker opens on the visit's existing time.
function toLocalInput(ts) {
  const d = new Date(ts);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

const LINK = { background: 'transparent', border: 0, padding: 0, fontSize: 12, color: 'var(--ad-text-dim,#565b6c)', textDecoration: 'underline', cursor: 'pointer' };

// One agenda row. The visible line is exactly the old read-only row; the manage
// affordance and its actions are additive and only render for upcoming visits.
function ApptRow({ a, onChanged }) {
  const [open, setOpen] = useState(false);
  const [mode, setMode] = useState(null); // null | 'reschedule' | 'cancel'
  const [when, setWhen] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);

  const actionable = ACTIONABLE.has(a.status) && new Date(a.scheduled_start).getTime() >= Date.now();

  function close() { setOpen(false); setMode(null); setErr(null); }
  function startReschedule() { setWhen(toLocalInput(a.scheduled_start)); setMode('reschedule'); setErr(null); }

  async function doReschedule() {
    if (!when) { setErr(RESCHEDULE_ERR.no_time); return; }
    setBusy(true); setErr(null);
    try {
      const res = await adminRescheduleAppointment(a.id, new Date(when).toISOString());
      if (res && res.ok) { close(); onChanged(); }
      else setErr(RESCHEDULE_ERR[res && res.error] || 'Could not reschedule, try again.');
    } catch (e) { setErr(e.message || 'Could not reschedule, try again.'); }
    finally { setBusy(false); }
  }
  async function doCancel() {
    setBusy(true); setErr(null);
    try {
      const res = await adminCancelAppointment(a.id);
      if (res && res.ok) { close(); onChanged(); }
      else setErr(res && res.error === 'not_found' ? 'Could not find that visit, try reloading.' : 'Could not cancel, try again.');
    } catch (e) { setErr(e.message || 'Could not cancel, try again.'); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ borderBottom: '1px solid var(--ad-outline,#ececf1)', padding: '3px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 14 }}>
        <span className="ad-mono" style={{ width: 72, opacity: 0.75 }}>{time(a.scheduled_start)}</span>
        <span style={{ flex: 1, minWidth: 0 }}>
          {a.client
            ? <strong>{a.client}</strong>
            : <strong style={{ color: 'var(--ad-warn,#b9770a)' }}>{a.fallback ? `${a.fallback} (unmatched)` : 'Unmatched import'}</strong>}
          <span style={{ opacity: 0.6, fontSize: 12 }}> · {SERVICE[a.service_type] || a.service_type || ''}{a.dog_count ? ` · ${a.dog_count} dog${a.dog_count === 1 ? '' : 's'}` : ''}</span>
        </span>
        {a.amount_cents != null && <span className="ad-mono" style={{ fontSize: 12, opacity: 0.7 }}>{money(a.amount_cents)}</span>}
        <span className="ad-mono" style={{ fontSize: 11, color: STATUS_COLOR[a.status] || 'var(--ad-text-dim,#565b6c)', fontStyle: a.status === 'tentative' ? 'italic' : 'normal', width: 76, textAlign: 'right' }}>{STATUS_LABEL[a.status] || a.status}</span>
        {actionable
          ? <button type="button" style={{ ...LINK, width: 52, textAlign: 'right' }} onClick={() => (open ? close() : setOpen(true))}>{open ? 'close' : 'manage'}</button>
          : <span style={{ width: 52 }} />}
      </div>

      {open && actionable && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, alignItems: 'center', padding: '8px 0 4px 82px' }}>
          {mode === null && (
            <>
              <button type="button" className="ad-btn ad-btn--sm ad-btn--ghost" onClick={startReschedule}>Reschedule</button>
              <button type="button" className="ad-btn ad-btn--sm ad-btn--ghost" onClick={() => { setMode('cancel'); setErr(null); }}>Cancel visit</button>
            </>
          )}
          {mode === 'reschedule' && (
            <>
              <input type="datetime-local" value={when} onChange={(e) => setWhen(e.target.value)}
                className="ad-mono" style={{ fontSize: 13, padding: '5px 8px', borderRadius: 8, border: '1px solid var(--ad-outline,#d8d8de)' }} />
              <button type="button" className="ad-btn ad-btn--sm" disabled={busy || !when} onClick={doReschedule}>{busy ? '…' : 'Save new time'}</button>
              <button type="button" style={LINK} disabled={busy} onClick={() => { setMode(null); setErr(null); }}>back</button>
            </>
          )}
          {mode === 'cancel' && (
            <>
              <span style={{ fontSize: 13 }}>Cancel this visit?</span>
              <button type="button" className="ad-btn ad-btn--sm" disabled={busy} onClick={doCancel}>{busy ? '…' : 'Yes, cancel'}</button>
              <button type="button" style={LINK} disabled={busy} onClick={() => { setMode(null); setErr(null); }}>keep it</button>
            </>
          )}
          {err && <span style={{ fontSize: 12, color: 'var(--ad-bad,#dc2626)', width: '100%' }}>{err}</span>}
        </div>
      )}
    </div>
  );
}

export default function CalendarView() {
  const [appts, setAppts] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [window, setWindow] = useState(30);
  // The calendar floor opens on today, not on last week. The window loads 7 days
  // of history for context, so without this the floor lands a week in the past
  // and Paul has to scroll forward every time. Pin today's group to the top of
  // the view once the appointments land (Paul, 2026-06-18).
  const todayRef = useRef(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setAppts(await calendar(7, window)); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, [window]);
  useEffect(() => { load(); }, [load]);
  // After the list renders, bring today (or the next future day) to the top.
  useEffect(() => {
    if (todayRef.current) todayRef.current.scrollIntoView({ block: 'start' });
  }, [appts]);

  if (error) return <><h1>Calendar</h1><div className="ad-error">{error}</div></>;
  if (loading || !appts) return <><h1>Calendar</h1><div className="ad-panel">Loading…</div></>;

  const now = Date.now();
  const upcoming = appts.filter((a) => new Date(a.scheduled_start).getTime() >= now).length;

  // group by day
  const todayStart = new Date(); todayStart.setHours(0, 0, 0, 0);
  const groups = [];
  let cur = null;
  for (const a of appts) {
    const k = dayKey(a.scheduled_start);
    if (!cur || cur.key !== k) { cur = { key: k, items: [], isPast: new Date(a.scheduled_start).getTime() < now, isFuture: new Date(a.scheduled_start).getTime() >= todayStart.getTime() }; groups.push(cur); }
    cur.items.push(a);
  }
  // The first group on or after today is where the floor should open.
  const anchor = groups.find((g) => g.isFuture);

  return (
    <>
      <h1>Calendar</h1>
      <p className="ad-sub">Your appointment schedule. {upcoming} upcoming in the next {window} days.</p>

      <div style={{ display: 'flex', gap: 8, marginBottom: 14 }}>
        {[14, 30, 90].map((d) => (
          <button key={d} className={'ad-btn ad-btn--sm ' + (window === d ? '' : 'ad-btn--ghost')} onClick={() => setWindow(d)}>{d} days</button>
        ))}
      </div>

      {groups.length === 0 ? (
        <div className="ad-panel" style={{ opacity: 0.7 }}>No appointments in this window.</div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {groups.map((g) => (
            <div key={g.key} ref={g === anchor ? todayRef : null} style={{ scrollMarginTop: 12 }}>
            <div className="ad-panel" style={{ opacity: g.isPast ? 0.6 : 1 }}>
              <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>{g.key}</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                {g.items.map((a) => (
                  <ApptRow key={a.id} a={a} onChanged={load} />
                ))}
              </div>
            </div>
            </div>
          ))}
        </div>
      )}
      <div style={{ fontSize: 12, opacity: 0.5, marginTop: 10 }}>Reschedule or cancel an upcoming visit with its "manage" link. New bookings come in through the /book funnel.</div>
    </>
  );
}
