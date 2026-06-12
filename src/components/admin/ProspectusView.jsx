// src/components/admin/ProspectusView.jsx
//
// The Prospectus (living_prospectus): the standing pitch to a buyer who does
// not exist yet. Written as if Dog Gone Clean were for sale today, and held
// to one hard rule: every claim carries a receipt. The numbers come from
// admin_prospectus on every load, computed live from the operating tables,
// so the pitch is always exactly as good as the business actually is. That
// is the point: when the page reads stronger, the business got stronger.

import { useEffect, useState } from 'react';
import { prospectus } from './supabase.js';

function money(cents) {
  if (cents === null || cents === undefined) return '?';
  return '$' + Math.round(cents / 100).toLocaleString('en-US');
}

export default function ProspectusView() {
  const [p, setP] = useState(null);
  const [err, setErr] = useState(null);
  useEffect(() => { prospectus().then(setP).catch((e) => setErr(e.message || 'load_failed')); }, []);

  if (err) return <><h1>Prospectus</h1><div className="ad-error">{err}</div></>;
  if (!p) return <><h1>Prospectus</h1><div className="ad-panel">Computing the pitch from live data…</div></>;

  const v = p.value || {};
  const book = p.book || {};
  const m = p.money || {};
  const mach = p.machine || {};
  const ttm = v.ttm_revenue_cents;

  return (
    <>
      <h1>The Prospectus</h1>
      <p className="ad-sub">
        If Dog Gone Clean were for sale today, this is the pitch. It is not for sale. Every number below is computed live from the operating database the moment you open this page; nothing is typed in by hand, and every claim shows its receipt.
      </p>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>The headline</Cap>
        <div style={{ fontSize: 26, fontWeight: 800, marginTop: 6 }}>
          {money(v.value_low_cents)} to {money(v.value_high_cents)}
        </div>
        <p style={{ fontSize: 14, marginTop: 6, marginBottom: 4 }}>
          A turnkey mobile dog grooming route in Ocala, Florida with over 20 years of operating history, a recurring client book that runs on standing appointments, and a complete software operating system a buyer gets with the keys.
        </p>
        <Receipt>
          {v.method === 'sde'
            ? `SDE method: trailing-12-month revenue minus recorded business costs, times ${v.low_multiple} to ${v.high_multiple} (owner-operated service multiples, adjusted for recurring share and growth). Computed by admin_business_value.`
            : `Revenue method: trailing-12-month revenue of ${money(ttm)} times ${v.low_multiple} to ${v.high_multiple}, multiples adjusted by the recurring share (${v.recurring_share_pct}%) and the growth trend we actually measure. Switches to the SDE method automatically once expense coverage reaches 5% of revenue. Computed by admin_business_value.`}
        </Receipt>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 16 }}>
        <Stat label="Revenue, last 12 months" value={money(ttm)}
          receipt="Sum of every visit's recorded take, visits table, trailing 365 days" />
        <Stat label="Recurring share" value={(v.recurring_share_pct ?? 0) + '%'}
          receipt="Share of trailing-12-month revenue from clients on a standing cadence" />
        <Stat label="Median visit" value={money(m.median_visit_cents)}
          receipt="Median collected amount across paid visits, trailing 365 days" />
        {m.earned_per_hour_cents ? <Stat label="Earned per hour on site" value={money(m.earned_per_hour_cents)}
          receipt="Collected dollars over recorded on-site minutes, trailing 365 days" /> : null}
      </div>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>The book a buyer inherits</Cap>
        <p style={{ fontSize: 14, marginTop: 8, marginBottom: 8 }}>
          {book.standing_clients} standing clients on fixed rotations and {book.active_recurring_plans} active recurring plans, with {book.repeat_clients} repeat households on record. The average repeat client has been on the books {book.avg_tenure_years} years within our digital records alone, the longest {book.max_tenure_years} years, and the paper trail goes back two decades before that. These are not leads; they are relationships with names, gate codes, dog temperaments, and standing time windows, all in the database.
        </p>
        <Receipt>
          {book.total_visits?.toLocaleString('en-US')} visits on record since {book.first_visit}; client and dog records carry per-dog grooming specs, access notes, and hard availability windows. Tenure measured from each repeat client's first to latest recorded visit (3+ visits), so it understates the true relationship length.
        </Receipt>
      </div>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>The operating system comes with it</Cap>
        <p style={{ fontSize: 14, marginTop: 8, marginBottom: 8 }}>
          The business runs on its own software, built for exactly this route: a booking funnel with card on file, a client portal, a live arrival tracker clients can watch, an operations console covering scheduling, finance, HR, compliance, and maintenance, and {mach.active_agents} AI department heads that brief the owner daily and log every dollar they cost. A buyer does not hire a back office; it is already here, documented, and it transfers.
        </p>
        <Receipt>
          {mach.client_records} client records, {mach.dog_records} dog records, {mach.briefings_on_record} agent briefings on file, {mach.riker_parses} voice-note captures parsed into structured records, {mach.wisdom_entries} entries in the operating knowledge base. Schedule adherence is instrumented live (plan vs actual arrival per stop), a metric most route businesses never measure.
        </Receipt>
      </div>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>Why the price holds up</Cap>
        <p style={{ fontSize: 14, marginTop: 8, marginBottom: 8 }}>
          Revenue is verifiable from the visit ledger, not a spreadsheet the seller typed. The client book is closed to new haircut work and pivoting to no-haircut full dog grooming, which is the faster, higher-revenue-per-hour half of the craft. The brand has two decades of reputation in Ocala and a second market (The Villages) opening under the same system. And the entire operation is documented well enough to run without the founder, which is the whole reason this page can exist.
        </p>
        <Receipt>
          Pivot economics: no-haircut visits run faster per dollar (favor_high_hourly_work in the operating rulebook). Growth vs prior year: {v.growth_pct === null || v.growth_pct === undefined ? 'measured but not yet meaningful (book in transition)' : v.growth_pct + '%'}. Saleability is a standing constraint (clean_stays_saleable): separate infrastructure, accounts, and data from day one.
        </Receipt>
      </div>

      <div style={{ fontSize: 12, opacity: 0.55 }}>
        Generated {new Date(p.generated_at).toLocaleString('en-US')} from dgc-prod. Refresh the page and every number recomputes.
      </div>
    </>
  );
}

function Stat({ label, value, receipt }) {
  return (
    <div className="ad-panel" style={{ padding: '14px 16px' }}>
      <div style={{ fontSize: 11, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.55 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
      <div style={{ fontSize: 11, marginTop: 4, opacity: 0.55 }}>{receipt}</div>
    </div>
  );
}
function Receipt({ children }) {
  return <div style={{ fontSize: 12, opacity: 0.6, borderLeft: '3px solid var(--ad-primary, #2563d8)', paddingLeft: 8 }}>Receipt: {children}</div>;
}
function Cap({ children }) {
  return <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>{children}</div>;
}
