// src/components/admin/TodayView.jsx
//
// Today: the crystal ball. The standing feed of briefings from the AI department
// heads, newest first. Each card is a two-way conversation: read it, reply to the
// agent with context, approve its action, or mark it intentional so the agent
// stands down on that exact thing for good. The AI proposes; you decide and can
// talk back.

import { useCallback, useEffect, useState } from 'react';
import { listBriefings, setBriefingStatus, replyBriefing, resolveBriefing, reopenBriefing, listAgents, todayAppointments, stampAppointmentTime, onMyWay, adminArrived, adminReturning, adminDepart, trackerUndo, trackerLocation, setEquipmentHoursByName, listReminders, setReminderDone, messageDraft, appointmentMeta, setAppointmentOperator, listTeam, adminSelf, listTasks, addTask, completeTask, dropTask, clearTask, clearDoneTasks, delegateBriefing, setVisitRequest, fieldFlags, markFieldSeen, uploadTaskProof, signedPhotoUrl, addTaskNote, addTaskFile, nowCard } from './supabase.js';
import HelpToggle from './Help.jsx';

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
  requestWakeLock();
}
function stopLocationShare() {
  if (locShare.watchId != null && navigator.geolocation) {
    navigator.geolocation.clearWatch(locShare.watchId);
  }
  locShare.apptId = null;
  locShare.watchId = null;
  locShare.lastPush = 0;
  releaseWakeLock();
}

// Screen Wake Lock: while a stop is actively sharing location (you are driving
// it), hold the phone screen awake so Chrome keeps this tab in the foreground
// and the live fixes keep flowing. It is released the instant the share stops.
// Honest limit (same as the tracker itself): the lock only holds while Laelaps
// is the visible tab. Android drops it the moment you switch apps or the screen
// goes off, so it cannot keep the tracker alive off-screen. Truly surviving a
// backgrounded tab needs a native app, parked in CLEAN_PARKING_LOT.md.
const wake = { sentinel: null };
async function requestWakeLock() {
  try {
    if ('wakeLock' in navigator && !wake.sentinel) {
      wake.sentinel = await navigator.wakeLock.request('screen');
      wake.sentinel.addEventListener('release', () => { wake.sentinel = null; });
    }
  } catch { /* a denied wake lock never blocks the share */ }
}
function releaseWakeLock() {
  try { wake.sentinel?.release(); } catch { /* ignore */ }
  wake.sentinel = null;
}
// The OS auto-releases the lock when the tab hides; re-take it when Paul comes
// back to Laelaps if a stop is still sharing, so a glance away does not end it.
if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && locShare.apptId != null) requestWakeLock();
  });
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
  cfo: 5, value_coach: 6, chief_of_staff: 7, bookkeeper: 8, growth: 9,
  compliance: 9, infra: 10, maintenance: 11, reorder: 12,
};
function sortByValue(cards) {
  return [...cards].sort((a, b) =>
    (SEV_RANK[a.severity] ?? 1) - (SEV_RANK[b.severity] ?? 1)
    || (AGENT_RANK[a.agent_key] ?? 99) - (AGENT_RANK[b.agent_key] ?? 99)
    || new Date(b.created_at) - new Date(a.created_at));
}

// Everything you can do with a stop card, on demand (help_on_demand). One toggle
// for the whole stops section, since every stop card works the same way.
const STOP_HELP = [
  ['Open the record', 'Tap the client name at the top of a stop to open their full contact sheet: dogs, history, notes, access, everything.'],
  ['The big button', 'Your visit flow, one tap each: On my way (shares the live tracker link and starts sharing your location) then I\'m here (you arrived) then Bringing them back (tells them to watch the door) then All done, rolling out (you left and the stop closes). Every tap also stamps the time.'],
  ['Tracker link', 'Share or copy the client\'s live tracking link any time, as many times as you need.'],
  ['Operator', 'Set who is running this stop, you or a teammate. Their name is the one the client sees on the tracker.'],
  ['Special request', 'Type what they asked for at the door (e.g. ears a little shorter). It shows on their tracker, then the photo you tag as the answer proves it was done. Tap Save.'],
  ['fix times', 'Opens the three clocks: Inbound (when you left for the stop), Arrived, Departed. Tap to stamp the time now, or type the exact time.'],
  ['Forgot to tap a button?', 'Open fix times and enter it by hand. Typing a Departed time closes the stop exactly like All done does; clearing a Departed time reopens it. The little x clears a time you entered by mistake.'],
  ['undo step', 'Tapped a step by accident? This rolls the last one back. It names the step and asks you to confirm first, so it cannot be fat-fingered.'],
  ['Things to ask', 'The arrow lines are reminders to bring something up with this client, carried over from last visit.'],
  ['While you are here', 'A nudge that shows when something is missing from the record (a gate code, the visit rhythm). Tap it to fill it in on the sheet.'],
  ['Send a thank-you', 'After a stop wraps: one tap drafts a warm, personal thank-you you can edit, copy, and send from your own messages.'],
];

export default function TodayView({ onOpenClient }) {
  const [briefings, setBriefings] = useState([]);
  const [agents, setAgents] = useState([]);
  const [appts, setAppts] = useState([]);
  const [reminders, setReminders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [me, setMe] = useState(null);
  const [team, setTeam] = useState([]);
  // Counts that decide whether the day is clear (drives the rest screen below).
  const [openTasks, setOpenTasks] = useState(0);
  const [openFlags, setOpenFlags] = useState(0);

  // Who is looking, and who they can hand a card to. Only the owner delegates
  // and only the owner needs the team list.
  useEffect(() => {
    adminSelf().then((a) => {
      setMe(a);
      if (a?.role === 'owner') listTeam().then((t) => setTeam(t || [])).catch(() => {});
    }).catch(() => {});
  }, []);
  const isOwner = me?.role === 'owner';

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const [b, a, t, r, tasks, flags] = await Promise.all([
        listBriefings(), listAgents(), todayAppointments(),
        listReminders().catch(() => null),
        listTasks().catch(() => []), fieldFlags().catch(() => []),
      ]);
      setBriefings(sortByValue(b.filter((x) => x.status === 'new' || x.status === 'read')));
      setAgents(a);
      setAppts(t);
      setReminders(r && Array.isArray(r.open) ? r.open : []);
      setOpenTasks((tasks || []).filter((x) => x.status === 'open').length);
      setOpenFlags((flags || []).filter((x) => !x.seen).length);
    } catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  // If a stop was already on_the_way when the floor loaded (page reload mid
  // drive), resume the live-location broadcast without another tap. When more
  // than one stop is somehow still rolling (a forgotten test booking did this
  // on 2026-06-11 and hijacked Becky's tracker mid-route), resume the LATEST
  // scheduled one: that is the stop Paul is actually driving to.
  // Two-operator guard: only the phone of the ASSIGNED operator resumes the
  // broadcast (an unassigned stop belongs to the owner). Otherwise Paul
  // opening Orbit at home while Jake drives would overwrite Jake's live
  // position with Paul's living room.
  useEffect(() => {
    const rolling = appts
      .filter((x) => x.status === 'on_the_way')
      .sort((a, b) => new Date(b.scheduled_start) - new Date(a.scheduled_start))[0];
    if (!rolling) return;
    let alive = true;
    (async () => {
      try {
        const [me, m] = await Promise.all([adminSelf(), appointmentMeta(rolling.id)]);
        if (!alive || !me) return;
        const mine = m?.operator_admin_id ? m.operator_admin_id === me.id : me.role === 'owner';
        if (mine) startLocationShare(rolling.id);
      } catch { /* no resume is safer than a wrong-phone broadcast */ }
    })();
    return () => { alive = false; };
  }, [appts]);

  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
  const activeHeads = agents.filter((a) => a.is_active).map((a) => a.label);

  // The day is "clear" when nothing on the screen needs Paul: no live or
  // upcoming stop, no reminder, no open briefing, no open task, and (owner) no
  // field flag waiting. A wrapped-but-not-empty day still counts as clear, so
  // the rest photo shows as a reward while the day's finished stops stay visible
  // below it. When clear, the empty "nothing here" boxes are hidden so the photo
  // stands alone instead of sitting under a stack of empty panels.
  const pendingStops = appts.filter((a) => !['completed', 'cancelled', 'skipped'].includes(a.status)).length;
  // A rolled-out (completed) stop drops off Today the instant it is wrapped, so
  // the list only ever shows what is still ahead. Two parts hold this: dropStop
  // removes it on the spot (before any refresh), and visibleAppts keeps it gone
  // after a reload refetches the day's finished stops. Finished visits are never
  // lost; each lives on in its client's history (Paul, 2026-06-23).
  const visibleAppts = appts.filter((a) => a.status !== 'completed');
  const dropStop = useCallback((id) => setAppts((prev) => prev.filter((a) => a.id !== id)), []);
  const dayIsClear = !loading && pendingStops === 0 && reminders.length === 0
    && briefings.length === 0 && openTasks === 0 && (!isOwner || openFlags === 0);

  return (
    <>
      <h1>Today</h1>
      <p className="ad-sub">{today}. {isOwner ? 'Your stops for the day, then the feed from your AI department heads. Talk back to any of them.' : 'Your stops for the day.'}</p>

      {dayIsClear && <RestfulToday />}

      <NowCard reloadKey={appts} onOpenClient={onOpenClient} />

      {!(dayIsClear && visibleAppts.length === 0) && (
      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
            <span style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Today's stops</span>
            <HelpToggle label="What can I do with a stop?" items={STOP_HELP} />
          </div>
          <span style={{ fontSize: 12, opacity: 0.6 }}>{visibleAppts.length} {visibleAppts.length === 1 ? 'stop' : 'stops'}</span>
        </div>
        {visibleAppts.length === 0 ? (
          <div style={{ opacity: 0.65, fontSize: 14 }}>
            {appts.length > 0 ? 'All stops done for today.' : 'Nothing on the calendar for today.'}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {visibleAppts.map((a) => <StopCard key={a.id} appt={a} onOpenClient={onOpenClient} onDone={dropStop} />)}
          </div>
        )}
      </div>
      )}

      {isOwner && reminders.length > 0 && (
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

      {/* Riker's inline card retired from Today (Paul, 2026-06-11): the
          floating + button is the one gateway everywhere, and two boxes for
          the same agent on one screen read as clutter. The client sheet
          keeps its fixed-client Riker box. */}

      {isOwner && <FromTheField />}

      <TasksPanel />

      {error && <div className="ad-error">{error}</div>}

      {/* The AI department-head feed is the Emperor's crystal ball: owner-only.
          An operator's Today is the route (stops + the Now card) and their
          assigned tasks, with money masked. The server (admin_list_briefings)
          returns nothing to a non-owner regardless; this is the matching UI. */}
      {isOwner && (loading ? (
        <div className="ad-panel">Loading the feed…</div>
      ) : briefings.length === 0 ? (
        dayIsClear ? null : (
        <div className="ad-panel" style={{ opacity: 0.7 }}>
          No open briefings. {activeHeads.length ? `${activeHeads.join(', ')} ${activeHeads.length === 1 ? 'is' : 'are'} watching.` : 'Bring a department head online to start the feed.'}
        </div>
        )
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {briefings.map((b) => <BriefingCard key={b.id} b={b} team={team} isOwner={isOwner} onChanged={load} onError={setError} />)}
        </div>
      ))}
    </>
  );
}

// The rest screen: when the day is clear (no stop, reminder, task, briefing, or
// field flag waiting), Today shows this instead of a stack of empty panels. The
// art is the "future paw salon" Paul picked. Quiet reward, not a call to action.
function RestfulToday() {
  return (
    <div className="ad-panel" style={{ textAlign: 'center', padding: '20px 16px', marginBottom: 16 }}>
      <div style={{ fontSize: 20, fontWeight: 800, lineHeight: 1.15 }}>All clear</div>
      <div style={{ fontSize: 14, opacity: 0.65, marginTop: 2, marginBottom: 16 }}>
        Nothing needs you right now. Enjoy the quiet.
      </div>
      <img
        src="/today-allclear.jpg"
        alt="The future Dog Gone Clean paw salon"
        loading="lazy"
        style={{
          width: '100%', maxWidth: 460, height: 'auto', display: 'block', margin: '0 auto',
          borderRadius: 16, boxShadow: 'var(--ad-brand-glow, 0 8px 24px rgba(37,99,216,0.16))',
        }}
      />
    </div>
  );
}

// From the field (field_flag): photos an operator flagged for the owner with a
// private note. Owner-only; hidden when there is nothing flagged. Mark "Got it"
// to clear it.
function FromTheField() {
  const [items, setItems] = useState(null);
  const [urls, setUrls] = useState({});
  const [busy, setBusy] = useState(false);
  const load = useCallback(() => { fieldFlags().then((d) => setItems(d || [])).catch(() => setItems([])); }, []);
  useEffect(() => { load(); }, [load]);
  useEffect(() => {
    let alive = true;
    (async () => {
      for (const i of (items || [])) {
        if (urls[i.id]) continue;
        try { const u = await signedPhotoUrl(i.path); if (alive) setUrls((prev) => ({ ...prev, [i.id]: u })); } catch { /* skip preview */ }
      }
    })();
    return () => { alive = false; };
  }, [items]); // eslint-disable-line react-hooks/exhaustive-deps
  async function seen(id) {
    setBusy(true);
    try { await markFieldSeen(id); load(); } catch { /* leave it */ } finally { setBusy(false); }
  }
  if (!items || items.length === 0) return null;
  return (
    <div className="ad-panel" style={{ marginBottom: 16, position: 'relative' }}>
      <HelpToggle corner items={[
        ['What this is', 'Things a teammate spotted on a visit and wanted you, privately, to see. The client never sees these.'],
        ['Got it', 'You have seen it. It moves out of the way. Nothing is deleted.'],
        ['The photo', 'Tap it to open the full picture.'],
      ]} />
      <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8, paddingRight: 24 }}>From the field</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {items.map((i) => (
          <div key={i.id} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', opacity: i.seen ? 0.55 : 1 }}>
            {urls[i.id] && (
              <a href={urls[i.id]} target="_blank" rel="noreferrer">
                <img src={urls[i.id]} alt="" style={{ width: 64, height: 64, objectFit: 'cover', borderRadius: 8 }} />
              </a>
            )}
            <div style={{ flex: 1, fontSize: 14 }}>
              <strong>{i.by || 'A teammate'}</strong> flagged{i.dog_name ? ` ${i.dog_name}` : ''}{i.client ? ` (${i.client})` : ''}
              {i.note && <div style={{ fontSize: 13, opacity: 0.8, marginTop: 2 }}>{i.note}</div>}
            </div>
            {!i.seen && <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => seen(i.id)}>Got it</button>}
          </div>
        ))}
      </div>
    </div>
  );
}

// Tasks (tasks_with_receipts). Paul assigns ("clean the intake filter"), the
// assignee's Today shows it, Done can demand a photo receipt, and Paul sees
// status and receipt in this same panel. Owner assigns and drops; assignee
// or owner completes. Hidden entirely when there is nothing to show and no
// one to assign (a solo owner with zero tasks sees no clutter).
function TasksPanel() {
  const [tasks, setTasks] = useState([]);
  const [me, setMe] = useState(null);
  const [team, setTeam] = useState([]);
  const [title, setTitle] = useState('');
  const [details, setDetails] = useState('');
  const [file, setFile] = useState(null);
  const [assignee, setAssignee] = useState('');
  const [needsProof, setNeedsProof] = useState(true);
  const [adding, setAdding] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState(null);

  const load = useCallback(async () => {
    try { setTasks(await listTasks() || []); } catch { /* panel stays quiet */ }
  }, []);
  useEffect(() => {
    load();
    adminSelf().then((a) => {
      setMe(a);
      if (a?.role === 'owner') listTeam().then((t) => setTeam(t || [])).catch(() => {});
    }).catch(() => {});
  }, [load]);

  const isOwner = me?.role === 'owner';
  const open = tasks.filter((t) => t.status === 'open');
  const recentDone = tasks.filter((t) => t.status === 'done').slice(0, 5);
  if (!isOwner && tasks.length === 0) return null;

  async function create() {
    if (!title.trim() || !assignee) return;
    setBusy(true); setErr(null);
    try {
      const id = await addTask(title.trim(), assignee, details.trim() || null, needsProof);
      // A screenshot or paste rides along with the handoff. A failed attach
      // never loses the task itself.
      if (file && id) { try { await addTaskFile(id, file); } catch { /* task still created */ } }
      setTitle(''); setDetails(''); setFile(null); setAdding(false); load();
    } catch (e) { setErr(e.message || 'add_failed'); }
    finally { setBusy(false); }
  }

  // The assignee (or owner) types the answer, or attaches a screenshot/photo,
  // onto an open task. This is how Jake enters the information he was asked for,
  // separate from finishing the task.
  async function addInfo(t, { note, file: f }) {
    setBusy(true); setErr(null);
    try {
      if (note && note.trim()) await addTaskNote(t.id, note.trim());
      if (f) await addTaskFile(t.id, f);
      load();
    } catch (e) { setErr(e.message || 'add_info_failed'); }
    finally { setBusy(false); }
  }

  async function markDone(t, file, actionValue = null) {
    setBusy(true); setErr(null);
    try {
      let proofPath = null;
      if (file) proofPath = await uploadTaskProof(t.id, file);
      await completeTask(t.id, proofPath, actionValue);
      load();
    } catch (e) {
      const msg = e.message === 'proof_required'
        ? 'This one needs a photo receipt: snap the finished work, then tap Done with photo.'
        : e.message === 'hours_required'
          ? 'Enter the hours reading first, then save.'
          : (e.message || 'done_failed');
      setErr(msg);
    } finally { setBusy(false); }
  }

  async function clearOne(t) {
    setErr(null);
    try { await clearTask(t.id); load(); } catch (e) { setErr(e.message || 'clear_failed'); }
  }
  async function clearAllDone() {
    setErr(null);
    try { await clearDoneTasks(); load(); } catch (e) { setErr(e.message || 'clear_failed'); }
  }
  // Take a handed-off card back: drops the teammate's task and returns the card
  // to your own feed (admin_reopen_briefing). Only possible while the task is
  // still open; once they finish it, the work happened and there is nothing to
  // take back.
  async function takeBack(t) {
    if (!t.briefing_id) return;
    setErr(null);
    try { await reopenBriefing(t.briefing_id); load(); }
    catch (e) { setErr(e.message === 'already_done' ? 'Too late to take it back: it was already finished.' : (e.message || 'take_back_failed')); }
  }

  async function viewReceipt(path) {
    try { const u = await signedPhotoUrl(path); window.open(u, '_blank', 'noopener'); }
    catch { setErr('could not open the receipt'); }
  }

  return (
    <div className="ad-panel" style={{ marginBottom: 16, position: 'relative' }}>
      <HelpToggle corner items={[
        ['Assign a task', 'The job lands on a teammate\'s day, not just yours. You can require a photo when they finish.'],
        ['Done', 'The job is finished and drops to the bottom. If a photo was required, you add it here to close it.'],
        ['Save hours', 'On an hours task: type the panel reading. The equipment\'s hours update and this closes.'],
        ['Take back', 'On a handed-off card: pulls it back onto your own list and cancels the teammate\'s task. Use it if you decide to handle it yourself. Only works until they finish it.'],
        ['Drop', 'Cancels a job that was never done, when it turns out nobody needs to do it. It disappears.'],
        ['Clear', 'On a finished job: tucks that one off the board. The work already happened; this just tidies the list.'],
        ['Clear finished', 'Tucks every finished job off the board at once. One tap to tidy up. Nothing is deleted.'],
        ['Receipt', 'Opens the photo a teammate left as proof the job got done.'],
      ]} />
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, paddingRight: 24 }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Tasks</div>
        {isOwner && !adding && (
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setAdding(true)}>Assign a task</button>
        )}
      </div>

      {isOwner && adding && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, margin: '8px 0' }}>
          <input className="pt-input" type="text" value={title} autoFocus placeholder="What needs doing? (e.g. clean the dryer intake filter)"
            onChange={(e) => setTitle(e.target.value)}
            style={{ width: '100%', fontSize: 13, padding: '7px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', boxSizing: 'border-box' }} />
          <textarea value={details} placeholder="Anything they need to know (paste it here). They can reply or attach a photo back."
            onChange={(e) => setDetails(e.target.value)} rows={2}
            style={{ width: '100%', fontSize: 13, padding: '7px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', boxSizing: 'border-box', resize: 'vertical', fontFamily: 'inherit' }} />
          <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', fontSize: 13 }}>
            <select value={assignee} onChange={(e) => setAssignee(e.target.value)}
              style={{ fontSize: 13, padding: '6px 8px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)' }}>
              <option value="">Who does it?</option>
              {team.map((t) => <option key={t.id} value={t.id}>{t.first_name}{t.last_name ? ` ${t.last_name}` : ''}</option>)}
            </select>
            <label className="ad-btn ad-btn--ghost ad-btn--sm" style={{ cursor: 'pointer' }}>
              {file ? 'photo attached' : 'attach a photo'}
              <input type="file" accept="image/*" disabled={busy} style={{ display: 'none' }}
                onChange={(e) => setFile((e.target.files && e.target.files[0]) || null)} />
            </label>
            <label style={{ display: 'flex', gap: 6, alignItems: 'center', cursor: 'pointer' }}>
              <input type="checkbox" checked={needsProof} onChange={(e) => setNeedsProof(e.target.checked)} />
              ask for a photo receipt
            </label>
            <button className="ad-btn ad-btn--sm" disabled={busy || !title.trim() || !assignee} onClick={create}>
              {busy ? '…' : 'Assign'}
            </button>
            <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => { setAdding(false); setFile(null); setDetails(''); }}>Cancel</button>
          </div>
        </div>
      )}

      {err && <div className="ad-error" style={{ fontSize: 12, marginTop: 6 }}>{err}</div>}

      {open.length === 0 && recentDone.length === 0 ? (
        <div style={{ fontSize: 13, opacity: 0.6, marginTop: 6 }}>Nothing assigned right now.</div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 8 }}>
          {open.map((t) => (
            <OpenTaskRow key={t.id} t={t} isOwner={isOwner} busy={busy}
              onDone={markDone}
              onAddInfo={addInfo}
              onViewFile={viewReceipt}
              onTakeBack={takeBack}
              onDrop={async (task) => { try { await dropTask(task.id); load(); } catch (e) { setErr(e.message); } }} />
          ))}
          {recentDone.length > 0 && isOwner && (
            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={clearAllDone}>Clear finished</button>
            </div>
          )}
          {recentDone.map((t) => (
            <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', opacity: 0.7, fontSize: 13 }}>
              <div style={{ flex: 1, minWidth: 180 }}>
                <span style={{ textDecoration: 'line-through' }}>{t.title}</span>
                <span style={{ display: 'block', fontSize: 12, opacity: 0.7 }}>
                  done by {t.assignee}{t.done_at ? ` · ${new Date(t.done_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}` : ''}
                </span>
                {(t.attachments || []).map((x) => (
                  x.kind === 'file' ? (
                    <button key={x.id} className="ad-btn ad-btn--ghost ad-btn--sm" style={{ marginTop: 4 }} onClick={() => viewReceipt(x.storage_path)}>
                      {x.author_name ? `${x.author_name}: ` : ''}view attachment
                    </button>
                  ) : (
                    <span key={x.id} style={{ display: 'block', fontSize: 12, marginTop: 2 }}>
                      {x.author_name ? <strong>{x.author_name}: </strong> : null}{x.body}
                    </span>
                  )
                ))}
              </div>
              {t.proof_photo_path && (
                <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => viewReceipt(t.proof_photo_path)}>Receipt</button>
              )}
              {isOwner && (
                <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => clearOne(t)}>Clear</button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// One open task row. A plain task gets Done (or Done-with-photo when a receipt
// was asked). A task that carries an equipment_hours action gets a number box so
// the assignee enters the reading from their own task (the only way an operator
// writes hours), which lands the value and closes the source card. Overdue and
// from-a-card are surfaced so a delegated card cannot quietly rot.
function OpenTaskRow({ t, isOwner, busy, onDone, onDrop, onTakeBack, onAddInfo, onViewFile }) {
  const [hours, setHours] = useState('');
  const [reply, setReply] = useState('');
  const [replyOpen, setReplyOpen] = useState(false);
  const isHours = t.action && t.action.type === 'equipment_hours';
  const canDo = t.mine || isOwner;
  const attachments = t.attachments || [];

  function sendReply(f = null) {
    if (!reply.trim() && !f) return;
    onAddInfo?.(t, { note: reply, file: f });
    setReply('');
  }

  return (
    <div style={{
      borderLeft: t.overdue ? '3px solid var(--ad-warn, #b9770a)' : '3px solid transparent',
      paddingLeft: 8,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <div style={{ flex: 1, minWidth: 180, fontSize: 14 }}>
          {t.title}
          <span style={{ display: 'block', fontSize: 12, opacity: 0.6 }}>
            {t.overdue && <strong style={{ color: 'var(--ad-warn, #b9770a)' }}>Overdue · </strong>}
            {t.mine ? 'yours' : `waiting on ${t.assignee}`}
            {t.from_card ? ' · from a card' : ''}
            {t.needs_proof ? ' · photo receipt asked' : ''}
          </span>
        </div>
        {canDo && isHours ? (
          <>
            <input type="number" inputMode="decimal" min="0" value={hours} disabled={busy}
              onChange={(e) => setHours(e.target.value)} placeholder="Panel hours"
              style={{ width: 110, fontSize: 13, padding: '6px 9px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)' }} />
            <button className="ad-btn ad-btn--sm" disabled={busy || !hours.trim()} onClick={() => onDone(t, null, hours.trim())}>
              {busy ? '…' : 'Save hours'}
            </button>
          </>
        ) : canDo && (t.needs_proof ? (
          <label className="ad-btn ad-btn--sm" style={{ cursor: 'pointer' }}>
            {busy ? '…' : 'Done with photo'}
            <input type="file" accept="image/*" capture="environment" disabled={busy} style={{ display: 'none' }}
              onChange={(e) => { const f = e.target.files && e.target.files[0]; if (f) onDone(t, f); }} />
          </label>
        ) : (
          <button className="ad-btn ad-btn--sm" disabled={busy} onClick={() => onDone(t, null)}>Done</button>
        ))}
        {isOwner && (t.from_card
          ? <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy}
              title="Pull this card back onto your own list and cancel the handoff"
              onClick={() => onTakeBack(t)}>Take back</button>
          : <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => onDrop(t)}>Drop</button>
        )}
      </div>

      {/* What the assigner handed over, then the running thread of notes and
          files either side has added. This is how Jake reads the context Paul
          attached and how Paul reads what Jake entered back. */}
      {t.details && (
        <div style={{ fontSize: 13, opacity: 0.85, marginTop: 4, whiteSpace: 'pre-wrap' }}>{t.details}</div>
      )}
      {attachments.length > 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 3, marginTop: 6 }}>
          {attachments.map((x) => (
            x.kind === 'file' ? (
              <button key={x.id} className="ad-btn ad-btn--ghost ad-btn--sm" style={{ alignSelf: 'flex-start' }}
                onClick={() => onViewFile?.(x.storage_path)}>
                {x.author_name ? `${x.author_name}: ` : ''}view attachment
              </button>
            ) : (
              <div key={x.id} style={{ fontSize: 13 }}>
                {x.author_name ? <strong>{x.author_name}: </strong> : null}{x.body}
              </div>
            )
          ))}
        </div>
      )}

      {canDo && (
        replyOpen ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 6 }}>
            <textarea value={reply} onChange={(e) => setReply(e.target.value)} disabled={busy} rows={2} autoFocus
              placeholder="Type the answer here (or attach a photo)"
              style={{ width: '100%', fontSize: 13, padding: '7px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', boxSizing: 'border-box', resize: 'vertical', fontFamily: 'inherit' }} />
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <button className="ad-btn ad-btn--sm" disabled={busy || !reply.trim()} onClick={() => sendReply(null)}>
                {busy ? '…' : 'Send'}
              </button>
              <label className="ad-btn ad-btn--ghost ad-btn--sm" style={{ cursor: 'pointer' }}>
                {busy ? '…' : 'Attach photo'}
                <input type="file" accept="image/*" disabled={busy} style={{ display: 'none' }}
                  onChange={(e) => { const f = e.target.files && e.target.files[0]; if (f) sendReply(f); }} />
              </label>
              <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => { setReplyOpen(false); setReply(''); }}>Close</button>
            </div>
          </div>
        ) : (
          <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ marginTop: 6 }} onClick={() => setReplyOpen(true)}>
            Add info
          </button>
        )
      )}
    </div>
  );
}

// The "right now" card (now_card_v1): a focused, glanceable view of the stop
// Paul is on his way to or working. Two moments, top to bottom: ARRIVING (how to
// get in, who is at the door) then THE DOGS on this appointment (photo to tell
// them apart, the handling note framed as reassurance, standing instructions,
// the follow-up, and the price for the door). Surfaces the in-progress stop,
// else the next not-yet-wrapped stop today; hides itself when there is nothing.
function NowCard({ reloadKey, onOpenClient }) {
  const [card, setCard] = useState(null);
  const [photos, setPhotos] = useState({});
  const [request, setRequest] = useState('');
  const [reqBusy, setReqBusy] = useState(false);
  const [reqSaved, setReqSaved] = useState(false);

  useEffect(() => {
    let alive = true;
    nowCard().then((c) => { if (alive) setCard(c && c.found ? c : null); }).catch(() => { if (alive) setCard(null); });
    return () => { alive = false; };
  }, [reloadKey]);

  // Keep the request box in sync with whatever is on record for this stop.
  useEffect(() => { setRequest(card?.special_request || ''); }, [card]);

  async function saveRequest() {
    if (!card) return;
    setReqBusy(true);
    try {
      await setVisitRequest(card.appointment_id, request);
      setReqSaved(true); setTimeout(() => setReqSaved(false), 2000);
    } catch { /* leave the text in the box to retry */ }
    finally { setReqBusy(false); }
  }

  // Sign each dog's photo once it is known.
  useEffect(() => {
    let alive = true;
    (async () => {
      for (const d of [...(card?.dogs || []), ...(card?.other_dogs || [])]) {
        if (!d.photo_path || photos[d.id]) continue;
        try { const u = await signedPhotoUrl(d.photo_path); if (alive) setPhotos((p) => ({ ...p, [d.id]: u })); } catch { /* skip */ }
      }
    })();
    return () => { alive = false; };
  }, [card]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!card) return null;

  const when = apptTime(card.scheduled_start);
  const heading = card.in_progress ? 'Right now' : 'On your way to';
  const dogs = card.dogs || [];
  const otherDogs = card.other_dogs || [];

  return (
    <div style={{ borderRadius: 16, overflow: 'hidden', marginBottom: 16, border: '1px solid var(--ad-outline, #e6e3dc)',
      boxShadow: 'var(--ad-brand-glow, 0 8px 24px rgba(37,99,216,0.16))' }}>
      {/* Gradient header: the moment and who. Tap to open the full record. */}
      <button type="button" onClick={() => card.client_id && onOpenClient?.(card.client_id)}
        style={{ display: 'block', width: '100%', textAlign: 'left', border: 0, cursor: card.client_id ? 'pointer' : 'default',
          color: '#fff', padding: '14px 16px', backgroundImage: 'var(--ad-ne-gradient)' }}>
        <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 1, opacity: 0.85 }}>
          {heading}{when ? ` · ${when}` : ''}
        </div>
        <div style={{ fontSize: 24, fontWeight: 800, lineHeight: 1.1, marginTop: 2 }}>{card.client || 'This stop'}</div>
      </button>

      <div style={{ background: 'var(--ad-surface, #fff)', padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {/* ARRIVING */}
        {(card.access_notes || card.onsite_people) && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {card.access_notes && (
              <div>
                <div style={{ fontSize: 10.5, textTransform: 'uppercase', letterSpacing: 0.5, opacity: 0.55, fontWeight: 700 }}>Getting in</div>
                <div style={{ fontSize: 14, lineHeight: 1.45, marginTop: 1 }}>{card.access_notes}</div>
              </div>
            )}
            {card.onsite_people && (
              <div>
                <div style={{ fontSize: 10.5, textTransform: 'uppercase', letterSpacing: 0.5, opacity: 0.55, fontWeight: 700 }}>At the door</div>
                <div style={{ fontSize: 14, lineHeight: 1.45, marginTop: 1 }}>{card.onsite_people}</div>
              </div>
            )}
          </div>
        )}

        {/* Special request the client makes at the door (heard-and-delivered):
            shows on their tracker as "you asked for", proven by the answer photo. */}
        <div>
          <div style={{ fontSize: 10.5, textTransform: 'uppercase', letterSpacing: 0.5, opacity: 0.55, fontWeight: 700, marginBottom: 4 }}>Special request at the door</div>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
            <input
              type="text" value={request} onChange={(e) => setRequest(e.target.value)}
              placeholder="What did they ask for? (e.g. ears a little shorter)"
              style={{ flex: 1, minWidth: 180, fontSize: 14, padding: '9px 11px', borderRadius: 9, border: '1px solid var(--ad-outline, #d8d8de)', boxSizing: 'border-box' }}
            />
            <button type="button" className="ad-btn ad-btn--sm" disabled={reqBusy || request === (card.special_request || '')} onClick={saveRequest}>
              {reqBusy ? '…' : reqSaved ? 'Saved' : 'Save'}
            </button>
          </div>
        </div>

        {/* THE DOGS on this appointment */}
        {dogs.length > 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {dogs.map((d) => (
              <div key={d.id} style={{ display: 'flex', gap: 12, alignItems: 'flex-start',
                borderTop: '1px solid var(--ad-line, #eee)', paddingTop: 10 }}>
                <div style={{ width: 60, height: 60, borderRadius: 12, flexShrink: 0, overflow: 'hidden',
                  background: 'var(--ad-surface-container, #f1f1f4)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 22, color: 'var(--ad-text-dim, #9a9aa2)' }}>
                  {photos[d.id] ? <img src={photos[d.id]} alt={d.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : '🐾'}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
                    <strong style={{ fontSize: 16 }}>{d.name}</strong>
                    {d.breed && <span style={{ fontSize: 12.5, opacity: 0.6 }}>{d.breed}</span>}
                  </div>
                  {d.standing_instructions && (
                    <div style={{ fontSize: 13, marginTop: 3, lineHeight: 1.4 }}>{d.standing_instructions}</div>
                  )}
                  {d.handling && (
                    <div style={{ fontSize: 13, marginTop: 5, lineHeight: 1.4, padding: '6px 9px', borderRadius: 9,
                      background: 'var(--ad-primary-container, #e8eefc)', color: 'var(--ad-text, #1b1b1f)' }}>
                      <strong>We've got this:</strong> {d.handling}
                    </div>
                  )}
                  {(d.followups || []).map((f, i) => (
                    <div key={i} style={{ fontSize: 12.5, marginTop: 4, color: 'var(--ad-warn, #b9770a)' }}>↳ mention: {f}</div>
                  ))}
                  {d.price_cents != null && (
                    <div style={{ fontSize: 12, marginTop: 4, opacity: 0.6 }}>{money(d.price_cents)}</div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Other dogs on site, not being groomed today: know them at the door. */}
        {otherDogs.length > 0 && (
          <div style={{ borderTop: '1px solid var(--ad-line, #eee)', paddingTop: 10 }}>
            <div style={{ fontSize: 10.5, textTransform: 'uppercase', letterSpacing: 0.5, opacity: 0.55, fontWeight: 700, marginBottom: 6 }}>Also home, not today</div>
            <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
              {otherDogs.map((d) => (
                <div key={d.id} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                  <div style={{ width: 38, height: 38, borderRadius: 9, flexShrink: 0, overflow: 'hidden',
                    background: 'var(--ad-surface-container, #f1f1f4)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 15, color: 'var(--ad-text-dim, #9a9aa2)' }}>
                    {photos[d.id] ? <img src={photos[d.id]} alt={d.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : '🐾'}
                  </div>
                  <div style={{ lineHeight: 1.2 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 600 }}>{d.name}</div>
                    {d.breed && <div style={{ fontSize: 11, opacity: 0.6 }}>{d.breed}</div>}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {card.total_price_cents > 0 && (
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
            borderTop: '1px solid var(--ad-line, #eee)', paddingTop: 8, fontSize: 14 }}>
            <span style={{ opacity: 0.6 }}>If they ask</span>
            <strong style={{ fontSize: 17 }}>{money(card.total_price_cents)} total</strong>
          </div>
        )}
      </div>
    </div>
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

const CLOCKS = [['inbound', 'Inbound'], ['arrived', 'Arrived'], ['departed', 'Departed']];

// Join dog names the way a person says them: "Cooper", "Cooper and Tilly",
// "Cooper, Tilly and Max". No existing helper did this, so this is the one.
function joinNames(names) {
  const n = (names || []).filter(Boolean);
  if (n.length === 0) return '';
  if (n.length === 1) return n[0];
  if (n.length === 2) return `${n[0]} and ${n[1]}`;
  return `${n.slice(0, -1).join(', ')} and ${n[n.length - 1]}`;
}

// The paste-ready tracker text the operator sends a client, personalized with
// the client's first name, the specialist's first name, and the dog name(s),
// and spaced out (blank line between every beat) so it reads at a glance
// instead of as a wall of text. One dog reads "follow Cooper's bath"; two or
// more reads "follow their baths".
function trackerShareText({ url, clientName, operatorName, dogNames }) {
  const clientFirst = (clientName || '').trim().split(/\s+/)[0] || 'there';
  const specialist = operatorName ? operatorName.split(' ')[0] : 'Paul';
  const names = (dogNames || []).filter(Boolean);
  const dogs = joinNames(names);
  const arrivingAt = dogs || 'your pup';
  const parked = names.length >= 2
    ? 'follow their baths right there on the screen.'
    : names.length === 1
      ? `follow ${names[0]}'s bath right there on the screen.`
      : 'follow the bath right there on the screen.';
  return [
    `Hi ${clientFirst}! ${specialist} is on the way to ${arrivingAt} now.`,
    `Here's your window into the whole visit: ${url}`,
    'Right now: a live map, so you can watch the truck roll up.',
    `Once we're parked: ${parked}`,
    "When we're done: before and after photos worth showing someone.",
    "Peek whenever you feel like it. No need to watch. It'll be there when you want it.",
  ].join('\n\n');
}

// One stop, one card (Paul 2026-06-10: the old dense row mixed the open-the-
// record tap with a strip of small buttons and everything fat-fingered).
// Layout rule: the whole header is the open-the-record target, the visit flow
// is ONE big button showing only the next step, and the three time cells hide
// behind a small "fix times" link for the forgot-to-tap case.
function StopCard({ appt, onOpenClient, onDone }) {
  const [status, setStatus] = useState(appt.status);
  const [times, setTimes] = useState({
    inbound: appt.inbound_at || null,
    arrived: appt.arrived_at || null,
    departed: appt.departed_at || null,
  });
  const [busyCell, setBusyCell] = useState(null);
  const [busyStep, setBusyStep] = useState(false);
  const [undoAsk, setUndoAsk] = useState(false);
  const [err, setErr] = useState(false);
  const [shareState, setShareState] = useState(null); // null | 'shared' | 'copied'
  const [request, setRequest] = useState(appt.special_request || '');
  const [reqBusy, setReqBusy] = useState(false);
  const [reqSaved, setReqSaved] = useState(false);
  const [showTimes, setShowTimes] = useState(false);
  const [meta, setMeta] = useState(null);   // { tracker_token, operator_admin_id, operator_name }
  const [team, setTeam] = useState(null);
  const [opOpen, setOpOpen] = useState(false);

  async function loadMeta() {
    try { const m = await appointmentMeta(appt.id); setMeta(m); return m; }
    catch { return null; }
  }
  useEffect(() => { if (clickable || appt.id) loadMeta(); }, [appt.id]);

  // Roll out and the stop leaves Today on the spot. The moment it is wrapped
  // (departed time stamped, whether by the big "rolling out" button or the fix
  // times cell), tell the floor to drop it so the screen only shows what is
  // still ahead. A card only mounts when it is NOT already done, so this fires
  // on the real roll-out, not on load. Nothing is lost: the finished visit lives
  // on in the client's history, a couple taps away (Paul chose the clean screen
  // over parking done stops here all day, 2026-06-23).
  useEffect(() => {
    if (status === 'completed' || times.departed) onDone?.(appt.id);
  }, [status, times.departed]);

  // The tracker link is never fleeting: this works at ANY stage, shares on
  // phones with a share sheet and copies everywhere else, as many times as
  // needed (Jake's iPhone got no sheet on the step tap and the link was gone).
  async function shareTracker() {
    const m = meta || await loadMeta();
    if (!m || !m.tracker_token) { setErr(true); return; }
    const url = `https://hurricanebath.com/track?t=${m.tracker_token}`;
    const text = trackerShareText({ url, clientName: appt.client, operatorName: m.operator_name, dogNames: m.dog_names });
    if (navigator.share) {
      try { await navigator.share({ text }); setShareState('shared'); return; }
      catch { /* sheet closed; fall through to copy */ }
    }
    try {
      await navigator.clipboard.writeText(text);
      setShareState('copied');
      setTimeout(() => setShareState(null), 2500);
    } catch { setErr(true); }
  }

  const clickable = !!appt.client_id;
  const followups = appt.followups || [];

  async function set(field, at) {
    const prev = times;
    setTimes((t) => ({ ...t, [field]: at }));   // optimistic
    setBusyCell(field); setErr(false);
    try {
      await stampAppointmentTime(appt.id, field, at);
      // A departed time closes the stop wherever it is entered; clearing it
      // reopens it. Mirror the server so the card flips without a reload.
      if (field === 'departed') setStatus(at ? 'completed' : 'returning');
    }
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
        const m = meta || await loadMeta();
        const url = `https://hurricanebath.com/track?t=${res.tracker_token || m?.tracker_token}`;
        const text = trackerShareText({ url, clientName: appt.client, operatorName: m?.operator_name, dogNames: m?.dog_names });
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
        const at = new Date().toISOString();
        setTimes((t) => ({ ...t, departed: at }));   // optimistic
        await adminDepart(appt.id, at);              // stamps departed AND completes the stop
        setStatus('completed');
      }
    } catch { setErr(true); }
    finally { setBusyStep(false); }
  }

  // Undo (tracker_undo_is_deliberate): one step back for a fast-fingered tap.
  // Deliberately quiet (small text link) and deliberately two-stage (tap, then
  // confirm with the step named), so the undo itself cannot be fat-fingered.
  const lastStep = (times.departed || status === 'completed') ? 'All done'
    : status === 'returning' ? 'Bringing them back'
    : (status === 'on_site' || status === 'in_service') ? "I'm here"
    : status === 'on_the_way' ? 'On my way'
    : null;
  async function undo() {
    setBusyStep(true); setErr(false);
    try {
      const res = await trackerUndo(appt.id);
      if (res && res.undone) {
        setStatus(res.status);
        setTimes({ inbound: res.inbound_at || null, arrived: res.arrived_at || null, departed: res.departed_at || null });
        if (res.status === 'on_the_way') startLocationShare(appt.id); else stopLocationShare();
      }
      setUndoAsk(false);
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

  async function saveRequest() {
    setReqBusy(true);
    try { await setVisitRequest(appt.id, request); setReqSaved(true); setTimeout(() => setReqSaved(false), 2000); }
    catch { setErr(true); }
    finally { setReqBusy(false); }
  }

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
            className="ad-btn ad-btn--full"
            onClick={step}
            disabled={busyStep}
            style={{ minHeight: 48, fontSize: 15 }}
            title={stepHint || ''}
          >
            {busyStep ? '…' : stepLabel}
          </button>
        )}
        {!wrapped && stepHint && (
          <div style={{ fontSize: 11, opacity: 0.5, textAlign: 'center' }}>{stepHint}</div>
        )}

        {/* Always-available tracker link + the operator on this stop. */}
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
          <button type="button" className="ad-btn ad-btn--ghost ad-btn--sm" onClick={shareTracker}>
            {shareState === 'copied' ? 'Link copied' : shareState === 'shared' ? 'Link shared' : 'Tracker link'}
          </button>
          {meta && (opOpen && team ? (
            <select className="ad-select" value={meta.operator_admin_id || ''}
              onChange={async (e) => {
                try {
                  await setAppointmentOperator(appt.id, e.target.value || null);
                  setOpOpen(false);
                  loadMeta();
                } catch { setErr(true); }
              }}>
              <option value="">Paul (default)</option>
              {team.map((t) => <option key={t.id} value={t.id}>{t.first_name}{t.last_name ? ` ${t.last_name}` : ''}</option>)}
            </select>
          ) : (
            <button type="button" className="ad-btn ad-btn--ghost ad-btn--sm"
              onClick={async () => {
                if (!team) { try { setTeam(await listTeam()); } catch { setTeam([]); } }
                setOpOpen(true);
              }}>
              Operator: {meta.operator_name ? meta.operator_name.split(' ')[0] : 'Paul'}
            </button>
          ))}
        </div>

        {/* Special request the client made at the door. Shows on their tracker
            as "you asked for", then proven with the photo tagged Answer. */}
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
          <input
            type="text" value={request} onChange={(e) => setRequest(e.target.value)}
            placeholder="Special request (e.g. ears a little shorter)"
            style={{ flex: 1, minWidth: 160, fontSize: 13, padding: '6px 9px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', boxSizing: 'border-box' }}
          />
          <button type="button" className="ad-btn ad-btn--ghost ad-btn--sm" disabled={reqBusy || request === (appt.special_request || '')} onClick={saveRequest}>
            {reqBusy ? '…' : reqSaved ? 'Saved' : 'Save'}
          </button>
        </div>

        <div style={{ display: 'flex', gap: 14, alignItems: 'baseline', flexWrap: 'wrap' }}>
          <button
            type="button"
            onClick={() => setShowTimes((v) => !v)}
            style={{ background: 'transparent', border: 0, padding: 0,
              fontSize: 12, color: 'var(--ad-text-dim,#565b6c)', textDecoration: 'underline', cursor: 'pointer' }}
          >
            {showTimes ? 'hide times' : 'fix times'}
          </button>
          {lastStep && !undoAsk && (
            <button
              type="button"
              onClick={() => setUndoAsk(true)}
              style={{ background: 'transparent', border: 0, padding: 0,
                fontSize: 12, color: 'var(--ad-text-dim,#565b6c)', opacity: 0.7, textDecoration: 'underline', cursor: 'pointer' }}
            >
              undo step
            </button>
          )}
          {lastStep && undoAsk && (
            <span style={{ fontSize: 12, display: 'inline-flex', gap: 8, alignItems: 'baseline', flexWrap: 'wrap' }}>
              <span>Roll back "{lastStep}"?</span>
              <button type="button" className="ad-btn ad-btn--sm" disabled={busyStep} onClick={undo}>
                {busyStep ? '…' : 'Yes, roll it back'}
              </button>
              <button type="button" className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busyStep} onClick={() => setUndoAsk(false)}>
                Keep it
              </button>
            </span>
          )}
        </div>
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

        {/* Moat nudge: while you are at this client, capture the knowledge only
            you have. Computed live from the record, so it clears itself once the
            field is filled. Tap opens the contact sheet to fill it. */}
        {clickable && (appt.context_gaps || []).length > 0 && (
          <button
            type="button"
            onClick={() => onOpenClient?.(appt.client_id)}
            style={{
              textAlign: 'left', cursor: 'pointer', width: '100%',
              border: '1px solid var(--ad-outline, #d8d8de)', borderRadius: 10,
              background: 'var(--ad-primary-container, #e8eefc)', color: 'var(--ad-text, #1b1b1f)',
              padding: '8px 10px',
            }}
            title="Open the contact sheet to fill this in"
          >
            <strong style={{ display: 'block', fontSize: 12.5 }}>While you are here, capture what only you know</strong>
            <span style={{ display: 'block', fontSize: 12, opacity: 0.8, marginTop: 1, lineHeight: 1.45 }}>
              Still missing for {appt.client || 'this client'}: {appt.context_gaps.join(', ')}. Tap to add it.
            </span>
          </button>
        )}
      </div>
    </div>
  );
}

export function TimeCell({ label, value, busy, onStampNow, onSet, onClear }) {
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
        <span style={{ display: 'inline-flex', gap: 5, alignItems: 'center' }}>
          <button onClick={() => setEditing(true)} disabled={busy} title="tap to adjust"
            className="ad-mono"
            style={{ fontSize: 13, fontWeight: 700, padding: '5px 14px', borderRadius: 999, cursor: 'pointer',
              color: '#fff', border: 0, backgroundImage: 'var(--ad-ne-gradient)',
              boxShadow: 'var(--ad-brand-glow, 0 6px 18px rgba(37,99,216,0.28))' }}>
            {shown}
          </button>
          <button onClick={onClear} disabled={busy} title="clear" aria-label="clear time"
            style={{ width: 28, height: 28, lineHeight: 1, borderRadius: '50%', cursor: 'pointer', fontSize: 14,
              color: 'var(--ad-text-dim,#565b6c)', background: 'var(--ad-surface-container-low,#fff)', border: '1px solid var(--ad-line,#e6e3dc)' }}>×</button>
        </span>
      ) : (
        <span style={{ display: 'inline-flex', gap: 5, alignItems: 'center' }}>
          <button onClick={onStampNow} disabled={busy} title="tap to stamp the current time"
            style={{ fontSize: 13, fontWeight: 600, padding: '5px 18px', borderRadius: 999, cursor: 'pointer',
              color: 'var(--ad-primary-strong, #1d50b8)', background: 'var(--ad-primary-container,#e6edfc)',
              border: '1px solid rgba(37,99,216,0.18)', boxShadow: 'var(--ad-elev-1, 0 1px 2px rgba(0,0,0,0.06))' }}>
            {busy ? '…' : 'tap'}
          </button>
          <button onClick={() => setEditing(true)} disabled={busy} title="forgot to tap? enter the time you actually left, arrived, or finished" aria-label="enter time"
            style={{ width: 28, height: 28, lineHeight: 1, borderRadius: '50%', cursor: 'pointer', fontSize: 12,
              color: 'var(--ad-text-dim,#565b6c)', background: 'var(--ad-surface-container-low,#fff)', border: '1px solid var(--ad-line,#e6e3dc)' }}>✎</button>
        </span>
      )}
    </span>
  );
}

function BriefingCard({ b, team = [], isOwner = false, onChanged, onError }) {
  const sev = SEV[b.severity] || SEV.info;
  const ev = b.evidence || {};
  const notes = b.notes || [];
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);
  const [delegating, setDelegating] = useState(false);
  const [delegateTo, setDelegateTo] = useState('');
  // After an answer the card collapses to a one-line outcome that stays put with
  // an Undo, instead of vanishing, so a fat-fingered tap is always reversible
  // until the next refresh (cards_resolve_or_stay).
  const [outcome, setOutcome] = useState(null);

  // An hours-ask card carries its own number box. A free-text reply is just a
  // recorded note (the 641-hours-into-the-void lesson, 2026-06-09): the data
  // entry the card asks for has to BE on the card, one field, one save, done.
  const hoursAsk = /^Update hours: (.+)$/.exec(b.title || '');
  const [hoursVal, setHoursVal] = useState('');

  // act runs an answer. When it resolves the card it sets a local outcome stub
  // (the card stays, showing Undo) instead of reloading the feed; a plain note
  // keeps the card open and just refreshes the thread.
  async function act(fn, outcomeLabel, undoable) {
    setBusy(true);
    try {
      await fn();
      if (outcomeLabel) setOutcome({ label: outcomeLabel, undoable: !!undoable });
      else onChanged();
    } catch (e) { onError(e.message || 'action_failed'); }
    finally { setBusy(false); }
  }

  const teamName = (id) => { const m = team.find((x) => x.id === id); return m ? `${m.first_name}${m.last_name ? ` ${m.last_name}` : ''}` : 'a teammate'; };
  const doHandle = () => act(() => resolveBriefing(b.id, 'done', reply.trim() || null), 'Handled', true);
  const doLeaveAlone = () => act(() => resolveBriefing(b.id, 'intentional', reply.trim() || null), 'Left alone, the agent will stop flagging it', true);
  const doDismiss = () => act(() => resolveBriefing(b.id, 'dismissed', reply.trim() || null), 'Set aside for now', true);
  const doNote = () => reply.trim() && act(async () => { await replyBriefing(b.id, reply.trim()); setReply(''); }, null, false);
  // Hand the card to whoever works for Clean as a task. It leaves the feed and
  // resolves itself when they finish it; an hours-ask card carries its hours
  // entry along so the assignee fills it from their own task.
  const doDelegate = () => delegateTo && act(() => delegateBriefing(b.id, delegateTo), `Handed to ${teamName(delegateTo)}`, true);
  const canDelegate = isOwner && team.length > 0;
  const doSaveHours = () => {
    const n = Number(hoursVal);
    if (!hoursVal.trim() || Number.isNaN(n) || n < 0) { onError('Enter the hours as a number.'); return; }
    act(async () => {
      await setEquipmentHoursByName(hoursAsk[1], n);
      await setBriefingStatus(b.id, 'resolved');
    }, 'Hours saved', false);
  };
  async function doUndo() {
    setBusy(true);
    try { await reopenBriefing(b.id); setOutcome(null); onChanged(); }
    catch (e) { onError(e.message === 'already_done' ? 'Too late to undo: the task was already finished.' : (e.message || 'undo_failed')); }
    finally { setBusy(false); }
  }

  if (outcome) {
    return (
      <div className="ad-panel" style={{ borderLeft: `4px solid ${sev.color}`, display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        <span style={{ flex: 1, minWidth: 180, fontSize: 14 }}>
          <span style={{ color: 'var(--ad-good, #1f8a4b)', fontWeight: 700 }}>Done · </span>
          <span style={{ opacity: 0.8 }}>{b.title}</span>
          <span style={{ display: 'block', fontSize: 12, opacity: 0.6 }}>{outcome.label}</span>
        </span>
        {outcome.undoable && <button className="ad-btn ad-btn--sm" disabled={busy} onClick={doUndo}>{busy ? '…' : 'Undo'}</button>}
        <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={onChanged}>Hide</button>
      </div>
    );
  }

  return (
    <div className="ad-panel" style={{ borderLeft: `4px solid ${sev.color}`, position: 'relative' }}>
      <HelpToggle corner items={[
        ['Handled it', 'The card goes away. For when you already took care of this yourself.'],
        ['Hand off', 'It leaves your list and becomes a teammate\'s job. It comes back only once they finish it.'],
        ['Leave it alone', 'The card goes away and you never hear about this one again. For things that are fine on purpose.'],
        ['Not now', 'The card goes away for now, but it can come back later if it still matters.'],
        ['Save hours', 'On an hours card: type the number off the panel and the card goes away, hours updated.'],
        ['Reply box', 'Your reason sticks to the card for good and the agent writes back, so the why behind a decision is never lost. It rides along with whatever answer you tap; Just leave a note keeps the card open.'],
        ['Undo', 'Tapped the wrong one? An Undo shows for a moment and puts the card right back.'],
      ]} />
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
        <strong style={{ fontSize: 16, paddingRight: 24 }}>{b.title}</strong>
        <span className="ad-mono" style={{ fontSize: 11, color: sev.color }}>{sev.label} · {b.agent_key.toUpperCase()}</span>
      </div>
      {b.body && <p style={{ margin: '8px 0', fontSize: 14, lineHeight: 1.5 }}>{b.body}</p>}

      {ev.file_url && (
        <div style={{ margin: '8px 0' }}>
          <a className="ad-btn ad-btn--sm" href={ev.file_url} target="_blank" rel="noreferrer">Open the document</a>
        </div>
      )}

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

      {/* An optional note rides along with whichever answer you pick. It is not
          an answer by itself: a note alone keeps the card open on purpose. */}
      <textarea
        value={reply} onChange={(e) => setReply(e.target.value)} disabled={busy}
        placeholder="Optional: tell the agent why (rides along with your answer, e.g. she's on a fixed income)"
        rows={2}
        style={{ width: '100%', marginTop: 8, fontSize: 13, padding: '6px 8px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }}
      />
      {/* The four answers, all equal weight (none pre-filled, none looks tapped). */}
      <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
        {!hoursAsk && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={doHandle} disabled={busy} title="I already took care of this">Handled it</button>}
        {canDelegate && !delegating && (
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setDelegating(true)} disabled={busy} title="Give it to someone as a task">Hand off</button>
        )}
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={doLeaveAlone} disabled={busy} title="On purpose; stop flagging it for good">Leave it alone</button>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={doDismiss} disabled={busy} title="Clear it for now; it can come back later">Not now</button>
        {reply.trim() && (
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={doNote} disabled={busy} title="Record a note and keep the card open">Just leave a note</button>
        )}
      </div>
      {canDelegate && delegating && (
        <div style={{ display: 'flex', gap: 8, marginTop: 8, alignItems: 'center', flexWrap: 'wrap', fontSize: 13 }}>
          <select value={delegateTo} onChange={(e) => setDelegateTo(e.target.value)}
            style={{ fontSize: 13, padding: '6px 8px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)' }}>
            <option value="">Hand it to…</option>
            {team.map((m) => <option key={m.id} value={m.id}>{m.first_name}{m.last_name ? ` ${m.last_name}` : ''}</option>)}
          </select>
          <button className="ad-btn ad-btn--sm" disabled={busy || !delegateTo} onClick={doDelegate}>{busy ? '…' : 'Hand off'}</button>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" disabled={busy} onClick={() => { setDelegating(false); setDelegateTo(''); }}>Cancel</button>
          <span style={{ fontSize: 11, opacity: 0.55 }}>Becomes their task; this card resolves when they finish it.</span>
        </div>
      )}
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
