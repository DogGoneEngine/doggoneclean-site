// src/components/admin/FinanceView.jsx
//
// The Finance department: the money on one pane of glass, computed from the real
// book (visits + appointments). Revenue per hour is the headline number; the
// rest is collections, the payment mix, the service mix, the monthly trend, and
// the clients carrying the most weight.

import { useCallback, useEffect, useState } from 'react';
import { financeSummary, businessValue } from './supabase.js';
import RecurringCosts from './RecurringCosts.jsx';
import BankImport from './BankImport.jsx';
import ExpensesLedger from './ExpensesLedger.jsx';

function money(cents) {
  if (cents === null || cents === undefined) return '$0';
  return '$' + Math.round(cents / 100).toLocaleString('en-US');
}
const SERVICE = { full_groom: 'Full groom', bath: 'Bath', nails: 'Nails', unknown: 'Unspecified' };
const PAYMENT = { square_in_person: 'Square', stripe_card: 'Stripe', cash: 'Cash', wallet: 'Wallet', invoice_or_other: 'Invoice / other' };

export default function FinanceView() {
  const [data, setData] = useState(null);
  const [windowDays, setWindowDays] = useState(90);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [expensesRefresh, setExpensesRefresh] = useState(0);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await financeSummary(windowDays)); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, [windowDays]);
  useEffect(() => { load(); }, [load]);

  return (
    <>
      <h1>Finance</h1>
      <p className="ad-sub">The money, from the books. Revenue per hour is the number you run on.</p>

      <ValuePanel />

      <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
        {[30, 90, 365].map((d) => (
          <button key={d} className={'ad-btn ad-btn--sm ' + (windowDays === d ? '' : 'ad-btn--ghost')} onClick={() => setWindowDays(d)}>
            {d === 365 ? '1 year' : `${d} days`}
          </button>
        ))}
      </div>

      {error && <div className="ad-error">{error}</div>}
      {loading || !data ? (
        <div className="ad-panel">Adding it up…</div>
      ) : (
        <FinanceBody d={data} />
      )}

      <h2 style={{ marginTop: 28, marginBottom: 4 }}>Money out</h2>
      <p className="ad-sub" style={{ marginTop: 0 }}>Your business account spend, from the statements. Out of your head, into one place.</p>
      <BankImport onImported={() => setExpensesRefresh((x) => x + 1)} />
      <ExpensesLedger refreshSignal={expensesRefresh} />

      <h3 style={{ marginTop: 24, marginBottom: 4 }}>Subscriptions and billing days</h3>
      <p className="ad-sub" style={{ marginTop: 0 }}>The recurring ones to watch, with the day of the month each hits.</p>
      <RecurringCosts />
    </>
  );
}

function FinanceBody({ d }) {
  const rph = d.revenue_per_hour;
  const prev = d.prev_revenue_per_hour;
  const delta = rph != null && prev != null ? +(rph - prev).toFixed(2) : null;
  const maxPay = Math.max(1, ...(d.payment_mix || []).map((p) => p.cents));
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {/* Headline cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 12 }}>
        <Stat label="Revenue / hour" value={rph != null ? `$${rph}` : 'n/a'}
          sub={delta != null ? `${delta >= 0 ? '+' : ''}$${delta} vs prior` : null}
          tone={delta == null ? 'flat' : delta >= 0 ? 'good' : 'bad'} big />
        <Stat label="Annual run rate" value={money(Math.round((d.revenue_cents || 0) / Math.max(1, d.window_days || 90) * 365))}
          sub={`this window's pace held for a year`} />
        <Stat label="Collected" value={money(d.revenue_cents)} sub={`${d.priced_visits} priced visits`} />
        <Stat label="Visits" value={String(d.visits)} sub={`${d.clients} clients`} />
        <Stat label="A/R outstanding" value={money(d.ar_cents)} sub={`${d.ar_count} appt(s) past due`} tone={d.ar_count > 0 ? 'bad' : 'good'} />
        <Stat label="Net after costs" value={money(d.net_cents)}
          sub={d.expenses_cents > 0 ? `after ${money(d.expenses_cents)} in costs` : 'no costs recorded yet'}
          tone={d.expenses_cents > 0 ? (d.net_cents >= 0 ? 'good' : 'bad') : 'flat'} />
      </div>

      {/* Payment mix */}
      <div className="ad-panel">
        <Cap>Payment mix</Cap>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 8 }}>
          {(d.payment_mix || []).map((p) => (
            <div key={p.method}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, marginBottom: 2 }}>
                <span>{PAYMENT[p.method] || p.method} <span style={{ opacity: 0.5 }}>· {p.visits}</span></span>
                <span className="ad-mono">{money(p.cents)}</span>
              </div>
              <div style={{ height: 6, background: 'var(--ad-surface-container, #f0f0f3)', borderRadius: 4 }}>
                <div style={{ height: 6, width: `${(p.cents / maxPay) * 100}%`, background: 'var(--ad-primary, #2563d8)', borderRadius: 4 }} />
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* By service + monthly trend side by side */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16 }}>
        <div className="ad-panel">
          <Cap>By service</Cap>
          <table className="ad-table" style={{ marginTop: 6 }}>
            <tbody>
              {(d.by_service || []).map((s) => (
                <tr key={s.service}>
                  <td>{SERVICE[s.service] || s.service}</td>
                  <td style={{ textAlign: 'right', opacity: 0.7 }}>{s.visits}</td>
                  <td style={{ textAlign: 'right' }} className="ad-mono">{money(s.cents)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="ad-panel">
          <Cap>Monthly trend</Cap>
          <table className="ad-table" style={{ marginTop: 6 }}>
            <tbody>
              {(d.monthly || []).map((m) => (
                <tr key={m.month}>
                  <td>{m.month}</td>
                  <td style={{ textAlign: 'right' }} className="ad-mono">{money(m.cents)}</td>
                  <td style={{ textAlign: 'right', opacity: 0.7 }} className="ad-mono">{m.rev_per_hour != null ? `$${m.rev_per_hour}/hr` : ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Top clients */}
      <div className="ad-panel">
        <Cap>Top clients by collected</Cap>
        <table className="ad-table" style={{ marginTop: 6 }}>
          <tbody>
            {(d.top_clients || []).map((t) => (
              <tr key={t.name}>
                <td>{t.name}</td>
                <td style={{ textAlign: 'right', opacity: 0.7 }}>{t.visits} visits</td>
                <td style={{ textAlign: 'right' }} className="ad-mono">{money(t.cents)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function Stat({ label, value, sub, tone = 'flat', big }) {
  const color = tone === 'good' ? 'var(--ad-good, #1f8a4b)' : tone === 'bad' ? 'var(--ad-bad, #dc2626)' : 'var(--ad-text-dim, #565b6c)';
  return (
    <div className="ad-panel" style={{ padding: '14px 16px' }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>{label}</div>
      <div style={{ fontSize: big ? 30 : 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
      {sub && <div style={{ fontSize: 12, marginTop: 2, color }}>{sub}</div>}
    </div>
  );
}
function Cap({ children }) {
  return <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>{children}</div>;
}


// The what-would-it-sell-for gauge (business_value_in_sight): the big-picture
// number that stays in sight through the daily hustle. Not because Paul plans
// to sell, but because a business someone would want to buy is a business
// that is going well, and the inputs (recurring share, growth, costs) are the
// health gauges themselves. The math lives in admin_business_value (0159) so
// the assumptions are in one reviewable place.
function ValuePanel() {
  const [v, setV] = useState(null);
  const [err, setErr] = useState(null);
  useEffect(() => {
    businessValue().then(setV).catch((e) => setErr(e.message || 'value_failed'));
  }, []);
  const k = (c) => '$' + Math.round((c || 0) / 100).toLocaleString('en-US');
  if (err) return null;
  if (!v) return <div className="ad-panel" style={{ marginBottom: 16 }}>Sizing up the business…</div>;
  return (
    <div className="ad-panel" style={{ marginBottom: 16, borderLeft: '4px solid var(--ad-primary, #2563d8)' }}>
      <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>What the business is worth</div>
      <div style={{ fontSize: 34, fontWeight: 800, margin: '4px 0 2px' }}>
        {k(v.value_low_cents)} <span style={{ opacity: 0.45, fontWeight: 400 }}>to</span> {k(v.value_high_cents)}
      </div>
      <div style={{ fontSize: 13, opacity: 0.75, lineHeight: 1.5 }}>
        {v.method === 'sde'
          ? <>Earnings method: {k(v.base_cents)} of yearly earnings after costs, at {v.low_multiple} to {v.high_multiple} times (the going range for an owner-run route business).</>
          : <>Revenue method: {k(v.ttm_revenue_cents)} collected in the last 12 months, at {v.low_multiple} to {v.high_multiple} times yearly revenue. Switches to the more accurate earnings method automatically once the expense ledger fills in.</>}
      </div>
      <div style={{ display: 'flex', gap: 18, flexWrap: 'wrap', fontSize: 13, marginTop: 8 }}>
        <span><strong>{v.recurring_share_pct}%</strong> <span style={{ opacity: 0.6 }}>recurring revenue (this is the moat a buyer pays for)</span></span>
        {v.growth_pct != null && <span><strong>{v.growth_pct >= 0 ? '+' : ''}{v.growth_pct}%</strong> <span style={{ opacity: 0.6 }}>vs the year before</span></span>}
      </div>
    </div>
  );
}
