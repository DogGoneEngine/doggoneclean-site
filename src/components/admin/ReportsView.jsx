// src/components/admin/ReportsView.jsx
//
// The Reports department: the business on one page. A rollup across the book and
// the full archive of every briefing your department heads have written.

import { useCallback, useEffect, useState } from 'react';
import { reportsSummary, listBriefings, scheduleAdherence, timeIsMoneyBackup } from './supabase.js';

function money(cents) {
  if (cents === null || cents === undefined) return '$0';
  return '$' + Math.round(cents / 100).toLocaleString('en-US');
}
function fmtDate(ts) {
  try { return new Date(ts).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }); } catch { return ts; }
}

export default function ReportsView() {
  const [sum, setSum] = useState(null);
  const [briefs, setBriefs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [adh, setAdh] = useState(null);
  const [tim, setTim] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const [s, b, a, t] = await Promise.all([
        reportsSummary(), listBriefings(), scheduleAdherence(90),
        timeIsMoneyBackup().catch(() => null),
      ]);
      setSum(s); setBriefs(b); setAdh(a); setTim(t);
    } catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  if (error) return <><h1>Reports</h1><div className="ad-error">{error}</div></>;
  if (loading || !sum) return <><h1>Reports</h1><div className="ad-panel">Pulling the numbers…</div></>;

  const monthDelta = sum.this_month_cents - sum.last_month_cents;
  const groups = sum.clients_by_group || {};
  const totalClients = Object.values(groups).reduce((a, b) => a + b, 0);

  return (
    <>
      <h1>Reports</h1>
      <p className="ad-sub">The whole business at a glance, plus every briefing on the record.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 12, marginBottom: 16 }}>
        <Stat label="Clients" value={String(totalClients)} sub={Object.entries(groups).map(([k, v]) => `${v} ${k}`).join(' · ')} />
        <Stat label="Visits on record" value={sum.total_visits.toLocaleString('en-US')} sub={`${money(sum.alltime_cents)} all time`} />
        <Stat label="This month" value={money(sum.this_month_cents)} sub={`${monthDelta >= 0 ? '+' : ''}${money(monthDelta)} vs last month`} tone={monthDelta >= 0 ? 'good' : 'bad'} />
        <Stat label="Next 7 days" value={String(sum.upcoming_7d)} sub={`${sum.active_subscriptions} active plans`} />
      </div>

      {adh && <AdherencePanel adh={adh} />}

      {tim && <TimeIsMoneyBackupPanel tim={tim} />}

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>Department heads</Cap>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 8 }}>
          {(sum.agents || []).map((a) => (
            <span key={a.label} className="ad-mono" style={{ fontSize: 12, padding: '3px 9px', borderRadius: 8,
              background: a.is_active ? 'var(--ad-primary-container, #e6edfc)' : 'var(--ad-surface-container, #f5f4f1)', opacity: a.is_active ? 1 : 0.55 }}>
              {a.label}{a.is_active ? '' : ' · dormant'}
            </span>
          ))}
        </div>
      </div>

      <div className="ad-panel">
        <Cap>Briefing archive · {briefs.length}</Cap>
        {briefs.length === 0 ? (
          <div style={{ opacity: 0.6, marginTop: 8 }}>No briefings yet.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 8 }}>
            {briefs.map((b) => (
              <div key={b.id} style={{ borderLeft: '3px solid var(--ad-primary, #2563d8)', paddingLeft: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap' }}>
                  <strong style={{ fontSize: 14 }}>{b.title}</strong>
                  <span className="ad-mono" style={{ fontSize: 11, opacity: 0.6 }}>{b.agent_key.toUpperCase()} · {fmtDate(b.created_at)} · {b.status}</span>
                </div>
                {b.body && <div style={{ fontSize: 13, opacity: 0.8, marginTop: 2 }}>{b.body}</div>}
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
}

// Schedule adherence: plan vs reality, tracked like cycle time
// (schedule_adherence_is_a_main_metric). delta_min is signed, late positive.
// The drift row shows how lateness accumulates stop by stop across a day,
// which is the failure mode that actually costs evenings.
function AdherencePanel({ adh }) {
  const fmtDelta = (m) => (m === null || m === undefined) ? '?' : (m > 0 ? `${m} min behind` : m < 0 ? `${-m} min ahead` : 'on the dot');
  const fmtClock = (ts) => { try { return new Date(ts).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }); } catch { return ts; } };
  const recent = adh.recent || [];
  const base = adh.baseline;
  // The history is the benchmark to beat, never blended with the live series:
  // sheet-and-calendar provenance vs tracker stamps are different instruments.
  const baseline = base ? (
    <div style={{ fontSize: 12, marginTop: 10, paddingTop: 8, borderTop: '1px solid var(--ad-outline, #e3e2de)', opacity: 0.75 }}>
      The record to beat ({base.first_day?.slice(0, 4)} to {base.last_day?.slice(0, 4)}, {base.n?.toLocaleString('en-US')} stops from the Time is Money sheet vs the calendar): median {base.median_delta_min} min behind, {base.on_time_15_pct}% within 15 min.
      {(base.by_year || []).length > 1 && (
        <span> By year: {(base.by_year || []).map((y) => `${y.year}: ${y.median_delta_min}`).join(' · ')} (median min behind).</span>
      )}
    </div>
  ) : null;
  if (!adh.n) {
    return (
      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>On schedule · last {adh.days} days</Cap>
        <div style={{ opacity: 0.6, marginTop: 8 }}>No tracked visits with a scheduled time yet. This fills in on its own as the tracker runs.</div>
        {baseline}
      </div>
    );
  }
  return (
    <div className="ad-panel" style={{ marginBottom: 16 }}>
      <Cap>On schedule · last {adh.days} days · {adh.n} tracked stops</Cap>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))', gap: 10, marginTop: 10, marginBottom: 12 }}>
        <Stat label="Typical arrival" value={fmtDelta(adh.median_delta_min)} sub={`average ${fmtDelta(adh.mean_delta_min)}`}
          tone={adh.median_delta_min <= 15 ? 'good' : 'bad'} />
        <Stat label="Within 15 min" value={`${adh.on_time_15_pct ?? 0}%`} sub={`${adh.on_time_5_pct ?? 0}% within 5 min`}
          tone={(adh.on_time_15_pct ?? 0) >= 80 ? 'good' : 'bad'} />
        <Stat label="Over 30 min behind" value={`${adh.late_30_pct ?? 0}%`} sub={`worst tenth: ${fmtDelta(adh.p90_delta_min)}`}
          tone={(adh.late_30_pct ?? 0) <= 10 ? 'good' : 'bad'} />
      </div>
      {(adh.drift_by_stop || []).length > 1 && (
        <div style={{ fontSize: 12, marginBottom: 10 }}>
          <span style={{ opacity: 0.6 }}>Drift across the day: </span>
          {(adh.drift_by_stop || []).map((d, i) => (
            <span key={d.stop} className="ad-mono">{i > 0 ? ' · ' : ''}stop {d.stop}: {fmtDelta(d.mean_delta_min)}</span>
          ))}
        </div>
      )}
      {recent.length > 0 && (
        <div style={{ fontSize: 12 }}>
          {recent.slice(0, 8).map((r, i) => (
            <div key={i} style={{ display: 'flex', justifyContent: 'space-between', gap: 8, padding: '2px 0', flexWrap: 'wrap' }}>
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{fmtDate(r.day)} · {r.client || 'client'}</span>
              <span className="ad-mono" style={{ color: r.delta_min > 30 ? 'var(--ad-bad, #dc2626)' : r.delta_min > 15 ? 'var(--ad-text-dim, #565b6c)' : 'var(--ad-good, #1f8a4b)' }}>
                {fmtClock(r.scheduled_start)} plan, {fmtClock(r.arrived_at)} actual, {fmtDelta(r.delta_min)}
              </span>
            </div>
          ))}
        </div>
      )}
      {baseline}
    </div>
  );
}

// Time is Money backup: the insurance copy of the whole book. The Ledger Keeper files
// the entire visit history as a dated Google Sheet into a Drive folder every Sunday,
// and keeps each week's file (a trail, not a single overwritten copy). This panel is
// the home for that, moved out of the Clients tab where the old append-helper lived.
function TimeIsMoneyBackupPanel({ tim }) {
  const last = tim.last_run;
  const fmtWhen = (ts) => { try { return new Date(ts).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' }); } catch { return ts; } };
  return (
    <div className="ad-panel" style={{ marginBottom: 16 }}>
      <Cap>Time is Money backup</Cap>
      <div style={{ fontSize: 13, opacity: 0.8, marginTop: 8, lineHeight: 1.5 }}>
        The full visit history, every row on record, filed as a dated Google Sheet every Sunday and kept week by week. Your insurance copy of the book, in your own Drive.
      </div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 12 }}>
        {tim.webapp_url && (
          <button className="ad-btn ad-btn--sm" onClick={() => window.open(tim.webapp_url, '_blank', 'noopener')}>Back up now</button>
        )}
        {tim.folder_url && (
          <a className="ad-btn ad-btn--sm" href={tim.folder_url} target="_blank" rel="noopener noreferrer">Open the backups folder</a>
        )}
        {last && last.url && (
          <a className="ad-btn ad-btn--ghost ad-btn--sm" href={last.url} target="_blank" rel="noopener noreferrer">Open the latest backup</a>
        )}
      </div>
      {!tim.webapp_url && (
        <div style={{ fontSize: 12, opacity: 0.6, marginTop: 8 }}>
          One-tap backup turns on after the producer script is published once as a web app.
        </div>
      )}
      <div style={{ fontSize: 12, opacity: 0.65, marginTop: 10 }}>
        {last && last.finished_at
          ? `Last filed ${fmtWhen(last.finished_at)}${last.rows ? ` · ${Number(last.rows).toLocaleString('en-US')} rows` : ''}.`
          : 'No backup filed yet. The first weekly copy lands once the Ledger Keeper is switched on.'}
      </div>
    </div>
  );
}

function Stat({ label, value, sub, tone = 'flat' }) {
  const color = tone === 'good' ? 'var(--ad-good, #1f8a4b)' : tone === 'bad' ? 'var(--ad-bad, #dc2626)' : 'var(--ad-text-dim, #565b6c)';
  return (
    <div className="ad-panel" style={{ padding: '14px 16px' }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
      {sub && <div style={{ fontSize: 12, marginTop: 2, color }}>{sub}</div>}
    </div>
  );
}
function Cap({ children }) {
  return <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>{children}</div>;
}
