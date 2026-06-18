// src/components/admin/CalendarView.jsx
//
// The Calendar floor: the appointment schedule as an agenda, grouped by day,
// newest window around today. Read-only for now; the booking surface is the
// /book funnel. This is the operator's view of what is coming.

import { useCallback, useEffect, useRef, useState } from 'react';
import { calendar } from './supabase.js';

const SERVICE = { full_groom: 'Full groom', bath: 'Bath', nails: 'Nails' };
const STATUS_COLOR = { confirmed: 'var(--ad-good,#1f8a4b)', tentative: 'var(--ad-accent,#2563eb)', requested: 'var(--ad-warn,#b9770a)', completed: 'var(--ad-text-dim,#565b6c)', cancelled: 'var(--ad-bad,#dc2626)', no_show: 'var(--ad-bad,#dc2626)' };
// A tentative appointment is one you pencilled in with a trailing "?" in your
// calendar. It is your private placeholder and never shown to the client; here
// in your own operator view it reads as "pencilled" so you can tell it apart.
const STATUS_LABEL = { tentative: 'pencilled' };

function money(c) { return c == null ? '' : '$' + Math.round(c / 100); }
function dayKey(ts) { return new Date(ts).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }); }
function time(ts) { try { return new Date(ts).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }); } catch { return ''; } }

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
                  <div key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 14, padding: '3px 0', borderBottom: '1px solid var(--ad-outline,#ececf1)' }}>
                    <span className="ad-mono" style={{ width: 72, opacity: 0.75 }}>{time(a.scheduled_start)}</span>
                    <span style={{ flex: 1, minWidth: 0 }}>
                      {a.client
                        ? <strong>{a.client}</strong>
                        : <strong style={{ color: 'var(--ad-warn,#b9770a)' }}>{a.fallback ? `${a.fallback} (unmatched)` : 'Unmatched import'}</strong>}
                      <span style={{ opacity: 0.6, fontSize: 12 }}> · {SERVICE[a.service_type] || a.service_type || ''}{a.dog_count ? ` · ${a.dog_count} dog${a.dog_count === 1 ? '' : 's'}` : ''}</span>
                    </span>
                    {a.amount_cents != null && <span className="ad-mono" style={{ fontSize: 12, opacity: 0.7 }}>{money(a.amount_cents)}</span>}
                    <span className="ad-mono" style={{ fontSize: 11, color: STATUS_COLOR[a.status] || 'var(--ad-text-dim,#565b6c)', fontStyle: a.status === 'tentative' ? 'italic' : 'normal', width: 76, textAlign: 'right' }}>{STATUS_LABEL[a.status] || a.status}</span>
                  </div>
                ))}
              </div>
            </div>
            </div>
          ))}
        </div>
      )}
      <div style={{ fontSize: 12, opacity: 0.5, marginTop: 10 }}>Read-only. Bookings come in through the /book funnel; this is your operator view.</div>
    </>
  );
}
