// src/components/admin/ScheduleView.jsx
//
// The Schedule department: Paul sets his work days and work hours, and adds
// per-date exceptions (close a day, or open a one-off). Writes the real
// availability tables through admin RPCs, so the booking funnel and the rest of
// the app see the same hours.

import { useCallback, useEffect, useState } from 'react';
import { listSchedule, setWindow, deleteWindow, addException, deleteException } from './supabase.js';
import HelpToggle from './Help.jsx';

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function fmtDate(d) {
  if (!d) return '';
  try { return new Date(d + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' }); }
  catch { return d; }
}

export default function ScheduleView() {
  const [cities, setCities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setCities(await listSchedule()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  return (
    <>
      <h1>Schedule</h1>
      <p className="ad-sub">Your work days, your work hours, and any one-off changes. This is the real availability the booking funnel reads.</p>
      {error && <div className="ad-error">{error}</div>}
      {loading ? (
        <div className="ad-panel">Loading your schedule…</div>
      ) : cities.length === 0 ? (
        <div className="ad-panel">No cities configured yet.</div>
      ) : (
        cities.map((city) => <CitySchedule key={city.id} city={city} onChanged={load} />)
      )}
    </>
  );
}

function CitySchedule({ city, onChanged }) {
  return (
    <div style={{ marginBottom: 28 }}>
      <h2 style={{ marginBottom: 4 }}>{city.name}</h2>
      <p className="ad-sub" style={{ marginTop: 0 }}>{city.timezone}</p>

      <div className="ad-panel" style={{ display: 'flex', flexDirection: 'column', gap: 6, position: 'relative' }}>
        <HelpToggle corner items={[
          ['Add hours', 'Opens that weekday for work. The booking funnel will offer slots inside the time window you set.'],
          ['on', 'Uncheck to switch a window off without deleting it. The day goes Off if no window is on.'],
          ['Save', 'Locks in the start and end time for that day.'],
          ['Remove', 'Deletes that time window.'],
        ]} />
        {DAYS.map((dayName, dow) => (
          <WeekdayRow
            key={dow}
            cityId={city.id}
            dow={dow}
            dayName={dayName}
            windows={(city.windows || []).filter((w) => w.weekday === dow)}
            onChanged={onChanged}
          />
        ))}
      </div>

      <Exceptions cityId={city.id} exceptions={city.exceptions || []} onChanged={onChanged} />
    </div>
  );
}

function WeekdayRow({ cityId, dow, dayName, windows, onChanged }) {
  const [adding, setAdding] = useState(false);
  const off = windows.length === 0;
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, padding: '6px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)' }}>
      <div style={{ width: 96, fontWeight: 600, opacity: off ? 0.5 : 1 }}>{dayName}</div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
        {off && !adding && <span style={{ opacity: 0.5, fontSize: 14 }}>Off</span>}
        {windows.map((w) => (
          <WindowEditor key={w.id} cityId={cityId} dow={dow} win={w} onChanged={onChanged} />
        ))}
        {adding && (
          <WindowEditor cityId={cityId} dow={dow} win={null} onChanged={() => { setAdding(false); onChanged(); }} onCancel={() => setAdding(false)} />
        )}
        {!adding && (
          <button className="ad-btn ad-btn--ghost ad-btn--sm" style={{ alignSelf: 'flex-start' }} onClick={() => setAdding(true)}>
            + Add hours
          </button>
        )}
      </div>
    </div>
  );
}

function WindowEditor({ cityId, dow, win, onChanged, onCancel }) {
  const [start, setStart] = useState(win?.start_time || '12:00');
  const [end, setEnd] = useState(win?.end_time || '18:00');
  const [active, setActive] = useState(win?.active ?? true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function save() {
    setBusy(true); setError(null);
    try {
      await setWindow({ id: win?.id ?? null, cityId, weekday: dow, start, end, active });
      onChanged();
    } catch (e) { setError(e.message || 'save_failed'); }
    finally { setBusy(false); }
  }
  async function remove() {
    setBusy(true); setError(null);
    try { await deleteWindow(win.id); onChanged(); }
    catch (e) { setError(e.message || 'delete_failed'); }
    finally { setBusy(false); }
  }

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
      <input className="ad-input" type="time" value={start} onChange={(e) => setStart(e.target.value)} style={{ width: 120 }} />
      <span style={{ opacity: 0.5 }}>to</span>
      <input className="ad-input" type="time" value={end} onChange={(e) => setEnd(e.target.value)} style={{ width: 120 }} />
      <label style={{ fontSize: 13, display: 'flex', alignItems: 'center', gap: 4 }}>
        <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} /> on
      </label>
      <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy}>{win ? 'Save' : 'Add'}</button>
      {win && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={remove} disabled={busy}>Remove</button>}
      {!win && onCancel && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={onCancel}>Cancel</button>}
      {error && <span className="ad-error" style={{ fontSize: 12 }}>{error}</span>}
    </div>
  );
}

function Exceptions({ cityId, exceptions, onChanged }) {
  const [open, setOpen] = useState(false);
  const today = new Date().toISOString().slice(0, 10);
  const [form, setForm] = useState({ date: today, isClosed: true, start: '12:00', end: '18:00', note: '' });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function add() {
    setBusy(true); setError(null);
    try {
      await addException({ cityId, date: form.date, isClosed: form.isClosed, start: form.isClosed ? null : form.start, end: form.isClosed ? null : form.end, note: form.note || null });
      setForm((f) => ({ ...f, note: '' })); setOpen(false); onChanged();
    } catch (e) { setError(e.message || 'save_failed'); }
    finally { setBusy(false); }
  }
  async function remove(id) {
    try { await deleteException(id); onChanged(); } catch (e) { setError(e.message || 'delete_failed'); }
  }

  return (
    <div className="ad-panel" style={{ marginTop: 12, position: 'relative' }}>
      <HelpToggle corner items={[
        ['Add', 'Overrides a single date: close a day you normally work, or open a one-off day you normally do not.'],
        ['closed', 'Checked means that date is closed. Unchecked lets you set special open hours just for that date.'],
        ['Remove', 'Deletes the exception; that date goes back to your normal weekly hours.'],
      ]} />
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingRight: 24 }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Exceptions (close a day or open a one-off)</div>
        {!open && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(true)}>+ Add</button>}
      </div>
      {error && <div className="ad-error" style={{ marginTop: 6 }}>{error}</div>}
      {open && (
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center', marginTop: 10 }}>
          <input className="ad-input" type="date" value={form.date} onChange={(e) => setForm((f) => ({ ...f, date: e.target.value }))} />
          <label style={{ fontSize: 13, display: 'flex', alignItems: 'center', gap: 4 }}>
            <input type="checkbox" checked={form.isClosed} onChange={(e) => setForm((f) => ({ ...f, isClosed: e.target.checked }))} /> closed
          </label>
          {!form.isClosed && (
            <>
              <input className="ad-input" type="time" value={form.start} onChange={(e) => setForm((f) => ({ ...f, start: e.target.value }))} style={{ width: 120 }} />
              <span style={{ opacity: 0.5 }}>to</span>
              <input className="ad-input" type="time" value={form.end} onChange={(e) => setForm((f) => ({ ...f, end: e.target.value }))} style={{ width: 120 }} />
            </>
          )}
          <input className="ad-input" placeholder="note (optional)" value={form.note} onChange={(e) => setForm((f) => ({ ...f, note: e.target.value }))} style={{ flex: 1, minWidth: 140 }} />
          <button className="ad-btn ad-btn--sm" onClick={add} disabled={busy}>Add</button>
          <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(false)}>Cancel</button>
        </div>
      )}
      {exceptions.length === 0 ? (
        <div style={{ opacity: 0.6, marginTop: 8, fontSize: 14 }}>No exceptions on the books.</div>
      ) : (
        <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 4 }}>
          {exceptions.map((e) => (
            <div key={e.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 14 }}>
              <span>
                <strong>{fmtDate(e.exception_date)}</strong>{' '}
                {e.is_closed ? <span style={{ color: 'var(--ad-bad, #dc2626)' }}>closed</span> : <span>{e.start_time}–{e.end_time}</span>}
                {e.note ? <span style={{ opacity: 0.7 }}> · {e.note}</span> : null}
              </span>
              <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => remove(e.id)}>Remove</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
