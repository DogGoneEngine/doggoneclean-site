// src/components/admin/EarningsView.jsx
//
// "My pay": the operator's own paycheck floor in Laelaps. It shows only the
// signed-in operator's OWN earnings, their share of their own completed-and-
// charged baths, computed server-side by admin_my_pay and scoped to them alone
// (operator_sees_own_pay). It shows no other money: not a bath's price to
// anyone else, not another worker's pay, not the business's books. This is the
// one deliberate carve-out to the operator money mask (orbit_roles_operator_masked).
//
// Earnings are an accumulated fact, never a daily goal or target: no goal bar,
// because a target pushes the operator to overextend against the grind-less aim
// (operator_pay_is_fact_not_goal). The teeth are the RPC and admins.commission_bps,
// so this page is only the renderer and survives a redesign.

import { useCallback, useEffect, useState } from 'react';
import { myPay } from './supabase.js';

function money(c) {
  const n = Number(c || 0) / 100;
  return '$' + n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
function moneyShort(c) {
  // Whole-dollar form for the small trend bars where cents are noise.
  return '$' + Math.round(Number(c || 0) / 100).toLocaleString('en-US');
}
function sharePct(bps) {
  if (!bps) return null;
  const p = bps / 100;
  return (Number.isInteger(p) ? p : p.toFixed(1)) + '%';
}
// A Monday week-start (ISO date) into a short "Jun 16" label.
function weekLabel(iso) {
  if (!iso) return '';
  const d = new Date(iso + 'T00:00:00');
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export default function EarningsView() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await myPay()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  const pct = data ? sharePct(data.rate_bps) : null;
  const weeks = (data && Array.isArray(data.weeks)) ? data.weeks : [];
  const peak = weeks.reduce((m, w) => Math.max(m, Number(w.earned_cents || 0)), 0);
  const nothingYet = data && Number(data.all_time_count || 0) === 0 && Number(data.today_count || 0) === 0;

  return (
    <>
      <h1>My pay</h1>
      <p className="ad-sub">
        {pct
          ? `Your share is ${pct} of every bath you complete. It lands here once the visit is done and the card is charged.`
          : 'Your pay shows up here as you complete baths.'}
      </p>

      {error && <div className="ad-error">{error}</div>}

      {loading || !data ? (
        <div className="ad-panel">Adding up your pay…</div>
      ) : nothingYet ? (
        <div className="ad-panel" style={{ lineHeight: 1.6 }}>
          <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>Today</div>
          <div style={{ fontSize: 36, fontWeight: 800 }}>{money(0)}</div>
          <p style={{ fontSize: 14, margin: '6px 0 0', opacity: 0.75 }}>
            No baths assigned to you yet. Each bath you run adds your {pct || 'share'} here: you
            will see what the day pays you up top, and it builds your week, month, and all-time
            totals as each one is charged.
          </p>
        </div>
      ) : (
        <>
          {/* The hero: what today's route pays. */}
          <div className="ad-panel" style={{ marginBottom: 16 }}>
            <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>Today</div>
            <div style={{ fontSize: 40, fontWeight: 800, marginTop: 2 }}>{money(data.today_cents)}</div>
            <div style={{ fontSize: 13, marginTop: 2, opacity: 0.65 }}>
              {Number(data.today_count || 0) > 0
                ? `your share of ${data.today_count} bath${Number(data.today_count) === 1 ? '' : 's'} on your route today`
                : 'no baths assigned to you today'}
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12 }}>
            <Stat label="This week" value={money(data.this_week_cents)} sub={Number(data.last_week_cents || 0) > 0 ? `${money(data.last_week_cents)} last week` : null} />
            <Stat label="This month" value={money(data.this_month_cents)} />
            <Stat label="All time" value={money(data.all_time_cents)} sub={`${data.all_time_count} bath${Number(data.all_time_count) === 1 ? '' : 's'}`} />
            <Stat label="Your share" value={pct || 'n/a'} sub="of each bath" />
          </div>

          {/* The trend: last eight weeks, oldest to newest. */}
          {weeks.length > 0 && (
            <div className="ad-panel" style={{ marginTop: 16 }}>
              <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 10 }}>Your last eight weeks</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {weeks.map((w) => {
                  const cents = Number(w.earned_cents || 0);
                  const frac = peak > 0 ? cents / peak : 0;
                  return (
                    <div key={w.week_start} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13 }}>
                      <span style={{ width: 52, flexShrink: 0, opacity: 0.65 }}>{weekLabel(w.week_start)}</span>
                      <span style={{ flex: 1, height: 16, background: 'var(--ad-surface-container, #f0eff7)', borderRadius: 6, overflow: 'hidden' }}>
                        <span style={{ display: 'block', height: '100%', width: `${Math.round(frac * 100)}%`, minWidth: cents > 0 ? 4 : 0, background: 'var(--ad-primary, #2563d8)', borderRadius: 6 }} />
                      </span>
                      <span style={{ width: 64, flexShrink: 0, textAlign: 'right', fontWeight: cents > 0 ? 600 : 400, opacity: cents > 0 ? 1 : 0.5 }}>{moneyShort(cents)}</span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          <div className="ad-panel" style={{ marginTop: 16, opacity: 0.85 }}>
            <p style={{ fontSize: 13, margin: 0, lineHeight: 1.5 }}>
              This is your pay and yours alone, the {pct || 'agreed'} share of the baths you ran.
              It is a running tally of what you have earned, not a target to hit.
            </p>
          </div>
        </>
      )}
    </>
  );
}

function Stat({ label, value, sub }) {
  return (
    <div className="ad-panel" style={{ padding: '14px 16px' }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
      {sub && <div style={{ fontSize: 12, marginTop: 2, opacity: 0.65 }}>{sub}</div>}
    </div>
  );
}
