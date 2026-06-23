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
  const fleet = p.fleet || {};
  const agents = p.agents_list || [];
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
          A turnkey mobile dog grooming route in Ocala, Florida with over 20 years of operating history, a recurring client book that runs on a set cadence, and a complete software operating system a buyer gets with the keys.
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
          {book.recurring_clients} recurring clients on a set cadence and {book.on_demand_clients} on-demand clients who book when they want, all in the database. The longest-running client goes back {book.max_tenure_years} years within our digital records alone, the average {book.avg_tenure_years} years, and the paper trail goes back two decades before that. These are not leads; they are relationships with names, gate codes, dog temperaments, and hard time windows.
        </p>
        <Receipt>
          {book.total_visits?.toLocaleString('en-US')} visits on record since {book.first_visit}; client and dog records carry per-dog grooming specs, access notes, and hard availability windows. Tenure measured from each client's first to latest recorded visit, so it understates the true relationship length.
        </Receipt>
      </div>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>The Hurricane Bath</Cap>
        <p style={{ fontSize: 14, marginTop: 8, marginBottom: 8 }}>
          The product is not a bath; it is a complete dog grooming visit delivered in the client's driveway in a climate-controlled trailer: the Hurricane Bath wash system with dual submersible pumps and a recirculating freshwater supply, high-velocity climate-controlled drying, deshedding, foot-pad hair, and nail care included, every visit, no add-on menu to upsell. The dog never leaves home, never sits in a cage, and never waits at a salon. Clients do not compare it to other dog groomers because nobody else around offers the thing itself.
        </p>
        <Receipt>
          Average {m.avg_on_site_min} minutes on site per visit (recorded visit minutes, trailing 365 days). The full craft SOP, water, power, and climate systems are documented in the field manual (CLEAN_FIELD_MANUAL.md), which transfers with the business.
        </Receipt>
      </div>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>String of Pearls scheduling and the Dog Gone Tracker</Cap>
        <p style={{ fontSize: 14, marginTop: 8, marginBottom: 8 }}>
          Routing is the whole economics of a mobile business, and this one treats it as a product. The String of Pearls scheduler is a backend service, not a human with a calendar: booking runs through edge functions that gate every new client by real drive time from the route's perimeter, and day plans string stops like pearls so the trailer earns instead of drives. On the client side, the Dog Gone Tracker is the pizza tracker for dog grooming: a live page showing who is coming (name, face, bio), where the visit stands step by step, and when the truck is on the way. Clients watch it instead of calling to ask.
        </p>
        <Receipt>
          Scheduler-as-a-service is a standing engineering rule (string_of_pearls_is_a_service): get-available-slots, create-booking, reschedule, skip, and stop all run as CORS-locked edge functions; the ocala-service-area function enforces the drive-time perimeter. The tracker stamps arrival and departure on every visit ({mach.tracked_visits} stamped so far; live since June 9) and feeds the schedule-adherence gauge, a metric most route businesses never measure.
        </Receipt>
      </div>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>The operating system comes with it</Cap>
        <p style={{ fontSize: 14, marginTop: 8, marginBottom: 8 }}>
          The business runs on its own software, built for exactly this route: a booking funnel with card on file, a client portal, a live arrival tracker clients can watch, an operations console covering scheduling, finance, HR, compliance, and maintenance, and {mach.active_agents} AI department heads that brief the owner daily and log every dollar they cost. A buyer does not hire a back office; it is already here, documented, and it transfers.
        </p>
        <Receipt>
          {mach.client_records} client records, {mach.dog_records} dog records, {mach.briefings_on_record} agent briefings on file, {mach.riker_parses} voice-note captures parsed into structured records, {mach.notifications_sent} automated client notifications sent. All of it in the business's own database, none of it in anyone's head.
        </Receipt>
      </div>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>The AI department heads, by name</Cap>
        <p style={{ fontSize: 14, marginTop: 8, marginBottom: 8 }}>
          These are not chatbots; they are watchers wired to the live data, each owning one asymmetric risk, and they work for whoever owns the business. The deepest moat is the proprietary context they run on: years of this route's own clients, dogs, prices, and timings, which no competitor can prompt their way into.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: 8, marginBottom: 8 }}>
          {agents.map((a) => (
            <div key={a.label} style={{ fontSize: 12, padding: '8px 10px', borderRadius: 8, background: 'var(--ad-surface-container, #f5f4f1)' }}>
              <strong>{a.label}</strong> <span style={{ opacity: 0.5 }}>{a.department}</span>
              <div style={{ opacity: 0.75, marginTop: 2 }}>{a.description}</div>
            </div>
          ))}
        </div>
        <Receipt>
          The agents table, live: {agents.length} active heads. Every Anthropic call each one makes is logged to agent_costs with tokens and model, priced on the HR floor; the whole staff costs less per month than one tank of gas.
        </Receipt>
      </div>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>The rolling plant</Cap>
        <p style={{ fontSize: 14, marginTop: 8, marginBottom: 8 }}>
          The trailer is a self-contained dog grooming facility: {fleet.equipment_items} tracked pieces of equipment including the climate-controlled trailer itself, the Hurricane Bath water system, dual generators with per-unit hour meters, dryer, and climate gear. Maintenance is not a memory; it is a program: {fleet.maintenance_tasks} recurring tasks (oil, spark plugs, filters, service intervals) tracked by engine hours and calendar days, with a Maintenance watcher agent that flags anything overdue before it fails on a route. A buyer inherits machines with a service discipline attached, not a mystery in a trailer.
        </p>
        <Receipt>
          equipment and maintenance_tasks tables, live counts: {fleet.equipment_items} items, {fleet.generators} generators ({fleet.hour_tracked} hour-metered), {fleet.maintenance_tasks} active maintenance tasks with defined intervals. The hands-on SOPs live in the field manual. Equipment book value is a data gap until receipts are loaded; the discipline, not the depreciation schedule, is the claim here.
        </Receipt>
      </div>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <Cap>The knowledge base: twenty years you cannot google</Cap>
        <p style={{ fontSize: 14, marginTop: 8, marginBottom: 8 }}>
          The hardest thing to buy in a service business is the operator's head, and this one has been written down. The field manual holds the craft: how to wash, dry, and handle real dogs, run the water and power systems, and keep the trailer alive. The Oracle holds the rules: every operating decision recorded with its reason, so a new owner inherits the why, not just the what. The wisdom inbox keeps absorbing more on every route. This is polish a buyer cannot get from any franchise manual, because it was learned one driveway at a time.
        </p>
        <Receipt>
          CLEAN_FIELD_MANUAL.md (craft, equipment, power, climate SOPs) and CLEAN_ORACLE.md (every rule in because-form) ship in the repo; {mach.wisdom_entries} wisdom entries captured in the database and growing. Per-client knowledge (gate codes, dog temperaments, hard availability windows) lives on the client records themselves.
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
