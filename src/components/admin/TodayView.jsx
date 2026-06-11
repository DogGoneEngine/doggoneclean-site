// src/components/admin/TodayView.jsx
//
// Today: the crystal ball. The standing feed of briefings from the AI department
// heads, newest first. Each card is a two-way conversation: read it, reply to the
// agent with context, approve its action, or mark it intentional so the agent
// stands down on that exact thing for good. The AI proposes; you decide and can
// talk back.

import { useCallback, useEffect, useState } from 'react';
import { listBriefings, setBriefingStatus, replyBriefing, resolveBriefing, listAgents, todayAppointments, stampAppointmentTime, onMyWay, adminArrived, adminReturning, trackerLocation, setEquipmentHoursByName, listReminders, setReminderDone, messageDraft } from './supabase.js';
import RikerCapture from './RikerCapture.jsx';

const SERVICE_LABEL = { full_groom: 'Full groom', bath: 'Bath', nails: 'Nails' };
const STATUS_TINT = { confirmed: '#1f8a4b', tentative: '#2563d8', requested: '#b9770a', on_the_way: '#2563d8', on_site: '#2563d8', returning: '#2563d8', in_service: '#2563d8', completed: '#565b6c' };
function apptTime(ts) { try { return new Date(ts).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }); } catch { return ''; } }

// One live-location broadcast at a time, module-level so it survives floor
// changes and re-renders. While a stop is on_the_way the Pixel's geolocation
// watch pushes the truck's position (throttled to one write per 15s) so the
// client's tracker can show live progress and a real drive ETA. Stops on the
// "I'm here" tap (the server also deletes the row then). Honest limit: Chrome
// only delivers fixes while the tab is alive; if Orbit is fully backgrounded
// behind navigation the client sees the last fix with its age, never a guess.
const locShare = { apptId: null, watchId: null, lastPush: 0 };
function startLocationShare(apptId) {
  if (!navigator.geolocation) return;
  if (locShare.apptId === apptId && locShare.watchId != null) return;
  stopLocationShare();
  locShare.apptId = apptId;
  locShare.watchId = navigator.geolocation.watchPosition(
    (pos) => {
      const now = Date.now();
      if (now - locShare.lastPush < 15000) return;
      locShare.lastPush = now;
      trackerLocation(apptId, pos.coords.latitude, pos.coords.longitude).catch(() => {});
    },
    () => {},
    { enableHighAccuracy: true, maximumAge: 10000, timeout: 20000 },
  );
}
function stopLocationShare() {
  if (locShare.watchId != null && navigator.geolocation) {
    navigator.geolocation.clearWatch(locShare.watchId);
  }
  locShare.apptId = null;
  locShare.watchId = null;
  locShare.lastPush = 0;
}

const SEV = {
  alert:  { color: '#dc2626', label: 'Alert' },
  signal: { color: '#2563d8', label: 'Signal' },
  info:   { color: '#1f8a4b', label: 'Info' },
};
function money(c) { return c == null ? null : '$' + (c / 100).toFixed(2).replace(/\.00$/, ''); }

// The feed is ordered by value, not arrival time: severity first (an alert
// outranks counsel), then by how asymmetric the card's payoff usually is. A
// capacity or win-back card is a one-tap action worth a whole visit's revenue;
// money counsel reads next; housekeeping (filters, reorders) waits politely.
// Within the info tier the day-before route brief leads, because it is the
// card Paul acts on every single evening.
const SEV_RANK = { alert: 0, signal: 1, info: 2 };
const AGENT_RANK = {
  tomorrow: 0, capacity: 1, winback: 2, pricing: 3, retention: 4,
  cfo: 5, chief_of_staff: 6, bookkeeper: 7, growth: 8,
  compliance: 9, infra: 10, maintenance: 11, reorder: 12,
};
function sortByValue(cards) {
  return [...cards].sort((a, b) =>
    (SEV_RANK[a.severity] ?? 1) - (SEV_RANK[b.severity] ?? 1)
    || (AGENT_RANK[a.agent_key] ?? 99) - (AGENT_RANK[b.agent_key] ?? 99)
    || new Date(b.created_at) - new Date(a.created_at));
}

export default function TodayView({ onOpenClient }) {
  const [briefings, setBriefings] = useState([]);
  const [agents, setAgents] = useState([]);
  const [appts, setAppts] = useState([]);
  const [reminders, setReminders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const [b, a, t, r] = await Promise.all([
        listBriefings(), listAgents(), todayAppointments(),
        listReminders().catch(() => null),
      ]);
      setBriefings(sortByValue(b.filter((x) => x.status === 'new' || x.status === 'read')));
      setAgents(a);
      setAppts(t);
      setReminders(r && Array.isArray(r.open) ? r.open : []);
    } catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  // If a stop was already on_the_way when the floor loaded (page reload mid
  // drive), resume the live-location broadcast without another tap.
  useEffect(() => {
    const rolling = appts.find((x) => x.status === 'on_the_way');
    if (rolling) startLocationShare(rolling.id);
  }, [appts]);

  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
  const activeHeads = agents.filter((a) => a.is_active).map((a) => a.label);

  return (
    <>
      <h1>Today</h1>
      <p className="ad-sub">{today}. Your stops for the day, then the feed from your AI department heads. Talk back to any of them.</p>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Today's stops</div>
          <span style={{ fontSize: 12, opacity: 0.6 }}>{appts.length} {appts.length === 1 ? 'stop' : 'stops'}</span>
        </div>
        {appts.length === 0 ? (
          <div style={{ opacity: 0.65, fontSize: 14 }}>Nothing on the calendar for today.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {appts.map((a) => <StopCard key={a.id} appt={a} onOpenClient={onOpenClient} />)}
          </div>
        )}
      </div>

      {reminders.length > 0 && (
        <div className="ad-panel" style={{ marginBottom: 16 }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>On your plate</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {reminders.map((r) => (
              <div key={r.id} style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
                <div style={{ flex: 1, fontSize: 14, lineHeight: 1.45 }}>
                  {r.overdue ? <strong style={{ color: 'var(--ad-warn, #b9770a)' }}>Overdue · </strong>
                    : r.due ? <strong>Today · </strong>
                    : <span style={{ opacity: 0.6 }}>{new Date(r.due_date + 'T12:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} · </span>}
                  {r.body}
                </div>
                <button className="ad-btn ad-btn--sm ad-btn--ghost" onClick={async () => {
                  try { await setReminderDone(r.id); load(); } catch (e) { setError(e.message); }
                }}>Done</button>
              </div>
            ))}
          </div>
        </div>
      )}

      <RikerCapture onApplied={load} />

      {error && <div className="ad-error">{error}</div>}

      {loading ? (
        <div className="ad-panel">Loading the feed…</div>
      ) : briefings.length === 0 ? (
        <div className="ad-panel" style={{ opacity: 0.7 }}>
          No open briefings. {activeHeads.length ? `${activeHeads.join(', ')} ${activeHeads.length === 1 ? 'is' : 'are'} watching.` : 'Bring a department head online to start the feed.'}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {briefings.map((b) => <BriefingCard key={b.id} b={b} onChanged={load} onError={setError} />)}
        </div>
      )}
    </>
  );
}

// Time is money, on the stop. Each stop carries three tappable times: when Paul
// left for it (inbound), when he arrived, when he finished. A tap stamps the
// current moment; he can adjust or clear. Persisted to the appointment's visit
// so the existing time_is_money export picks it up. Mirrors the paper sheet.
function fmtClock(iso) {
  if (!iso) return null;
  try { return new Date(iso).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }); } catch { return null; }
}
function isoToHHMM(iso) {
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
function hhmmToISO(hhmm) {
  const [h, m] = hhmm.split(':').map(Number);
  const d = new Date();
  d.setHours(h, m, 0, 0);
  return d.toISOString();
}

const CLOCKS = [['inbound', 'Left'], ['arrived', 'Arrived'], ['departed', 'Done']];

// One stop, one card (Paul 2026-06-10: the old dense row mixed the open-the-
// record tap with a strip of small buttons and everything fat-fingered).
// Layout rule: the whole header is the open-the-record target, the visit flow
// is ONE big button showing only the next step, and the three time cells hide
// behind a small "fix times" link for the forgot-to-tap case.
function StopCard({ appt, onOpenClient }) {
  const [status, setStatus] = useState(appt.status);
  const [times, setTimes] = useState({
    inbound: appt.inbound_at || null,
    arrived: appt.arrived_at || null,
    departed: appt.departed_at || null,
  });
  const [busyCell, setBusyCell] = useState(null);
  const [busyStep, setBusyStep] = useState(false);
  const [err, setErr] = useState(false);
  const [shareState, setShareState] = useState(null); // null | 'shared' | 'copied'
  const [showTimes, setShowTimes] = useState(false);

  const clickable = !!appt.client_id;
  const followups = appt.followups || [];

  async function set(field, at) {
    const prev = times;
    setTimes((t) => ({ ...t, [field]: at }));   // optimistic
    setBusyCell(field); setErr(false);
    try { await stampAppointmentTime(appt.id, field, at); }
    catch { setTimes(prev); setErr(true); }     // revert on failure
    finally { setBusyCell(null); }
  }

  // The visit flow, one tap per step:
  // On my way -> I'm here -> Bringing them back -> All done.
  // Each tap flips the appointment status (tracker stage), stamps the
  // matching time_is_money clock, and the first one opens the share sheet
  // with the tracker link (Google Voice paste until Twilio sends it).
  async function step() {
    setBusyStep(true); setErr(false);
    try {
      if (status === 'requested' || status === 'confirmed' || status === 'tentative') {
        const res = await onMyWay(appt.id);
        if (!times.inbound) set('inbound', new Date().toISOString());
        setStatus('on_the_way');
        startLocationShare(appt.id);
        const url = `https://hurricanebath.com/track?t=${res.tracker_token}`;
        const text = `Dog Gone Clean is rolling your way. Follow along: ${url}`;
        if (navigator.share) {
          try { await navigator.share({ text }); setShareState('shared'); }
          catch { setShareState(null); } // user closed the sheet; no-op
        } else {
          await navigator.clipboard.writeText(text);
          setShareState('copied');
        }
      } else if (status === 'on_the_way') {
        await adminArrived(appt.id);
        stopLocationShare();
        if (!times.arrived) setTimes((t) => ({ ...t, arrived: new Date().toISOString() }));
        setStatus('on_site');
      } else if (status === 'on_site' || status === 'in_service') {
        await adminReturning(appt.id);
        setStatus('returning');
      } else if (status === 'returning') {
        await set('departed', new Date().toISOString());
      }
    } catch { setErr(true); }
    finally { setBusyStep(false); }
  }

  const wrapped = status === 'completed' || !!times.departed;
  const stepLabel = wrapped ? null
    : status === 'on_the_way' ? "I'm here"
    : (status === 'on_site' || status === 'in_service') ? 'Bringing them back'
    : status === 'returning' ? 'All done, rolling out'
    : shareState === 'copied' ? 'Message copied. Tap when here'
    : shareState === 'shared' ? 'Heads up sent. Tap when here'
    : 'On my way';
  const stepHint = wrapped ? null
    : status === 'on_the_way' ? 'flips their tracker to "We’re here, getting set up"'
    : (status === 'on_site' || status === 'in_service') ? 'tells them to watch the door'
    : status === 'returning' ? 'stamps Done and closes the stop'
    : 'marks on the way and shares the tracker link';

  return (
    <div style={{ border: '1px solid var(--ad-outline, #ececf1)', borderRadius: 12, overflow: 'hidden' }}>
      <div
        onClick={clickable ? () => onOpenClient?.(appt.client_id) : undefined}
        style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 14, padding: '12px 12px',
          cursor: clickable ? 'pointer' : 'default',
          background: 'var(--ad-surface-container, #f7f7fa)' }}
        title={clickable ? 'Open contact sheet' : 'Unmatched import'}
      >
        <span className="ad-mono" style={{ width: 64, opacity: 0.75, flexShrink: 0 }}>{apptTime(appt.scheduled_start)}</span>
        <span style={{ flex: 1, minWidth: 0 }}>
          {appt.client
            ? <strong style={{ fontSize: 15 }}>{appt.client}</strong>
            : <strong style={{ color: 'var(--ad-warn,#b9770a)' }}>{appt.fallback ? `${appt.fallback} (unmatched)` : 'Unmatched import'}</strong>}
          <span style={{ display: 'block', opacity: 0.6, fontSize: 12 }}>
            {SERVICE_LABEL[appt.service_type] || appt.service_type || ''}{appt.dog_count ? ` · ${appt.dog_count} dog${appt.dog_count === 1 ? '' : 's'}` : ''}{status === 'tentative' ? ' · pencilled' : ''}{appt.amount_cents > 0 ? ` · ${money(appt.amount_cents)}` : ''}
          </span>
        </span>
        {clickable && <span style={{ fontSize: 20, opacity: 0.45, flexShrink: 0 }}>›</span>}
      </div>

      <div style={{ padding: '10px 12px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {wrapped ? (
          <>
            <div style={{ fontSize: 13, color: 'var(--ad-text-dim,#565b6c)' }}>
              Wrapped{times.departed ? ` at ${fmtClock(times.departed)}` : ''}.
            </div>
            {clickable && <ThankYouDraft clientId={appt.client_id} sms={appt.contact_links?.sms} />}
          </>
        ) : (
          <button
            type="button"
            onClick={step}
            disabled={busyStep}
            style={{ width: '100%', padding: '12px 14px', borderRadius: 10, border: 0, cursor: 'pointer',
              background: 'linear-gradient(135deg, var(--ad-primary,#2563d8), #4f46e5)',
              color: '#fff', fontSize: 15, fontWeight: 800, letterSpacing: 0.2 }}
            title={stepHint || ''}
          >
            {busyStep ? '...' : stepLabel}
          </button>
        )}
        {!wrapped && stepHint && (
          <div style={{ fontSize: 11, opacity: 0.5, textAlign: 'center' }}>{stepHint}</div>
        )}

        <button
          type="button"
          onClick={() => setShowTimes((v) => !v)}
          style={{ alignSelf: 'flex-start', background: 'transparent', border: 0, padding: 0,
            fontSize: 12, color: 'var(--ad-text-dim,#565b6c)', textDecoration: 'underline', cursor: 'pointer' }}
        >
          {showTimes ? 'hide times' : 'fix times'}
        </button>
        {showTimes && (
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'flex-start' }}>
            {CLOCKS.map(([field, label]) => (
              <TimeCell
                key={field}
                label={label}
                value={times[field]}
                busy={busyCell === field}
                onStampNow={() => set(field, new Date().toISOString())}
                onSet={(hhmm) => set(field, hhmmToISO(hhmm))}
                onClear={() => set(field, null)}
              />
            ))}
          </div>
        )}
        {err && <span style={{ fontSize: 11, color: 'var(--ad-bad, #dc2626)' }}>save failed, try again</span>}

        {followups.length > 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            {followups.map((f, i) => (
              <div key={i} style={{ fontSize: 12, color: 'var(--ad-warn, #b9770a)' }}>↳ ask{f.dog ? ` (${f.dog})` : ''}: {f.body}</div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function TimeCell({ label, value, busy, onStampNow, onSet, onClear }) {
  const [editing, setEditing] = useState(false);
  const shown = fmtClock(value);

  if (editing) {
    return (
      <span style={{ display: 'inline-flex', flexDirection: 'column', gap: 2 }}>
        <span style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>{label}</span>
        <span style={{ display: 'inline-flex', gap: 4, alignItems: 'center' }}>
          <input type="time" autoFocus defaultValue={value ? isoToHHMM(value) : isoToHHMM(new Date().toISOString())}
            onChange={(e) => e.target.value && onSet(e.target.value)}
            className="ad-mono" style={{ fontSize: 13, padding: '2px 4px', borderRadius: 6, border: '1px solid var(--ad-outline,#d8d8de)' }} />
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setEditing(false)}>ok</button>
        </span>
      </span>
    );
  }

  return (
    <span style={{ display: 'inline-flex', flexDirection: 'column', gap: 2, minWidth: 64 }}>
      <span style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>{label}</span>
      {shown ? (
        <span style={{ display: 'inline-flex', gap: 4, alignItems: 'center' }}>
          <button onClick={() => setEditing(true)} disabled={busy} title="tap to adjust"
            className="ad-mono"
            style={{ fontSize: 13, fontWeight: 700, padding: '3px 8px', borderRadius: 8, cursor: 'pointer',
              color: 'var(--ad-on-primary,#fff)', background: 'var(--ad-primary,#2563d8)', border: 0 }}>
            {shown}
          </button>
          <button onClick={onClear} disabled={busy} title="clear"
            style={{ fontSize: 12, lineHeight: 1, padding: '2px 5px', borderRadius: 6, cursor: 'pointer',
              color: 'var(--ad-text-dim,#565b6c)', background: 'transparent', border: '1px solid var(--ad-outline,#e0e0e6)' }}>×</button>
        </span>
      ) : (
        <span style={{ display: 'inline-flex', gap: 4, alignItems: 'center' }}>
          <button onClick={onStampNow} disabled={busy} title="tap to stamp the current time"
            style={{ fontSize: 13, padding: '3px 12px', borderRadius: 8, cursor: 'pointer',
              color: 'var(--ad-primary,#2563d8)', background: 'var(--ad-primary-container,#e6edfc)',
              border: '1px dashed rgba(37,99,216,0.4)' }}>
            {busy ? '…' : 'tap'}
          </button>
          <button onClick={() => setEditing(true)} disabled={busy} title="forgot to tap? enter the time you actually left/arrived/finished"
            style={{ fontSize: 12, lineHeight: 1, padding: '3px 6px', borderRadius: 6, cursor: 'pointer',
              color: 'var(--ad-text-dim,#565b6c)', background: 'transparent', border: '1px solid var(--ad-outline,#e0e0e6)' }}>✎</button>
        </span>
      )}
    </span>
  );
}

function BriefingCard({ b, onChanged, onError }) {
  const sev = SEV[b.severity] || SEV.info;
  const ev = b.evidence || {};
  const notes = b.notes || [];
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);

  // An hours-ask card carries its own number box. A free-text reply is just a
  // recorded note (the 641-hours-into-the-void lesson, 2026-06-09): the data
  // entry the card asks for has to BE on the card, one field, one save, done.
  const hoursAsk = /^Update hours: (.+)$/.exec(b.title || '');
  const [hoursVal, setHoursVal] = useState('');

  async function run(fn) {
    setBusy(true);
    try { await fn(); onChanged(); }
    catch (e) { onError(e.message || 'action_failed'); setBusy(false); }
  }
  const doReply = () => reply.trim() && run(() => replyBriefing(b.id, reply.trim()));
  const doIntentional = () => run(() => resolveBriefing(b.id, 'intentional', reply.trim() || null));
  const doDismiss = () => run(() => resolveBriefing(b.id, 'dismissed', reply.trim() || null));
  const doSaveHours = () => {
    const n = Number(hoursVal);
    if (!hoursVal.trim() || Number.isNaN(n) || n < 0) { onError('Enter the hours as a number.'); return; }
    run(async () => {
      await setEquipmentHoursByName(hoursAsk[1], n);
      await setBriefingStatus(b.id, 'resolved');
    });
  };

  return (
    <div className="ad-panel" style={{ borderLeft: `4px solid ${sev.color}` }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
        <strong style={{ fontSize: 16 }}>{b.title}</strong>
        <span className="ad-mono" style={{ fontSize: 11, color: sev.color }}>{sev.label} · {b.agent_key.toUpperCase()}</span>
      </div>
      {b.body && <p style={{ margin: '8px 0', fontSize: 14, lineHeight: 1.5 }}>{b.body}</p>}

      {hoursAsk && (
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', margin: '8px 0', flexWrap: 'wrap' }}>
          <input
            type="number" inputMode="decimal" min="0" value={hoursVal} disabled={busy}
            onChange={(e) => setHoursVal(e.target.value)}
            placeholder="Panel hours"
            style={{ width: 120, fontSize: 14, padding: '7px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)' }}
          />
          <button className="ad-btn ad-btn--sm" onClick={doSaveHours} disabled={busy || !hoursVal.trim()}>
            Save hours
          </button>
          <span style={{ fontSize: 11, opacity: 0.55 }}>Saves to {hoursAsk[1]} and clears this card.</span>
        </div>
      )}
      {Object.keys(ev).length > 0 && (
        <div className="ad-mono" style={{ fontSize: 11, opacity: 0.65, display: 'flex', flexWrap: 'wrap', gap: 10 }}>
          {ev.visits != null && <span>visits {ev.visits}</span>}
          {ev.revenue_per_hour != null && <span>rev/hr ${ev.revenue_per_hour}</span>}
          {ev.business_rate != null && <span>rate ${ev.business_rate}</span>}
          {ev.days_since != null && <span>{ev.days_since}d since visit</span>}
          {ev.revenue_cents != null && <span>collected {money(ev.revenue_cents)}</span>}
          {ev.ar_count != null && ev.ar_count > 0 && <span>A/R {ev.ar_count}</span>}
        </div>
      )}

      {/* conversation thread */}
      {notes.length > 0 && (
        <div style={{ margin: '10px 0', display: 'flex', flexDirection: 'column', gap: 6 }}>
          {notes.map((n, i) => (
            <div key={i} style={{ alignSelf: n.author === 'paul' ? 'flex-end' : 'flex-start', maxWidth: '85%' }}>
              <div style={{
                fontSize: 13, padding: '6px 10px', borderRadius: 10, lineHeight: 1.4,
                background: n.author === 'paul' ? 'var(--ad-primary-container, #e6edfc)' : 'var(--ad-surface-container, #f1f1f4)',
              }}>{n.body}</div>
              <div className="ad-mono" style={{ fontSize: 10, opacity: 0.4, textAlign: n.author === 'paul' ? 'right' : 'left', marginTop: 1 }}>
                {n.author === 'paul' ? 'you' : b.agent_key}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* reply box */}
      <textarea
        value={reply} onChange={(e) => setReply(e.target.value)} disabled={busy}
        placeholder="Tell the agent what's up (e.g. she's on a fixed income, leave her price alone)…"
        rows={2}
        style={{ width: '100%', marginTop: 8, fontSize: 13, padding: '6px 8px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }}
      />
      <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
        <button className="ad-btn ad-btn--sm" onClick={doReply} disabled={busy || !reply.trim()}>Reply</button>
        {b.recommended_action && <button className="ad-btn ad-btn--sm" onClick={() => run(() => setBriefingStatus(b.id, 'approved'))} disabled={busy}>Approve</button>}
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={doIntentional} disabled={busy} title="This is on purpose; stop flagging it">This is intentional</button>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={doDismiss} disabled={busy}>Dismiss</button>
        {b.status === 'new' && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => run(() => setBriefingStatus(b.id, 'read'))} disabled={busy}>Mark read</button>}
      </div>
    </div>
  );
}

// After a stop wraps: one tap turns the visit into a warm personal message.
// The drafter (message-draft edge fn) writes it from whatever Paul wants to
// mention; he edits, copies, and sends it from his own messages app. This is
// the grateful-clients moat in its smallest possible form.
function ThankYouDraft({ clientId, sms }) {
  const [open, setOpen] = useState(false);
  const [thoughts, setThoughts] = useState('');
  const [draft, setDraft] = useState(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);
  const [copied, setCopied] = useState(false);

  async function go() {
    setBusy(true); setErr(null);
    try {
      const out = await messageDraft(clientId, thoughts.trim() || "Write a short warm thank-you for today's visit; the dogs did great.");
      setDraft(out.draft || '');
    } catch (e) { setErr(e.message || 'draft_failed'); }
    finally { setBusy(false); }
  }
  async function copy() {
    try { await navigator.clipboard.writeText(draft || ''); setCopied(true); setTimeout(() => setCopied(false), 1500); } catch { /* noop */ }
  }

  if (!open) {
    return (
      <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ alignSelf: 'flex-start' }} onClick={() => setOpen(true)}>
        Send a thank-you?
      </button>
    );
  }
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      {draft === null ? (
        <>
          <textarea rows={2} value={thoughts} onChange={(e) => setThoughts(e.target.value)}
            placeholder="Anything to mention? (optional: how the dogs did, something you noticed)"
            style={{ width: '100%', fontSize: 13, padding: '8px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }} />
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="ad-btn ad-btn--sm" onClick={go} disabled={busy}>{busy ? 'Writing…' : 'Draft it'}</button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(false)}>Never mind</button>
          </div>
        </>
      ) : (
        <>
          <textarea rows={4} value={draft} onChange={(e) => setDraft(e.target.value)}
            style={{ width: '100%', fontSize: 13, padding: '8px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }} />
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <button className="ad-btn ad-btn--sm" onClick={copy}>{copied ? 'Copied' : 'Copy'}</button>
            {sms && <a className="ad-btn ad-btn--ghost ad-btn--sm" href={sms}>Text the client</a>}
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setDraft(null)} disabled={busy}>Redo</button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setOpen(false); setDraft(null); }}>Done</button>
          </div>
        </>
      )}
      {err && <div className="ad-error" style={{ fontSize: 12 }}>{err}</div>}
    </div>
  );
}
