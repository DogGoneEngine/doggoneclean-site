// src/components/admin/AdminApp.jsx
//
// Orbit: the Dog Gone Clean admin console shell. Google OAuth gate, a
// department rail, and section routing. Every department is navigable from day
// one: the ones not yet built render a panel that states what lives there, so
// the structure itself is the roadmap. Clients is live; the rest fill in over
// the build sequence. Mirrors the Dog Gone Nails Orbit shell but talks only to
// Clean's own project (dgc-prod).

import { useCallback, useEffect, useState } from 'react';
import { sb, signInWithGoogle, signOut, getSession, adminSelf } from './supabase.js';
import ClientsView from './ClientsView.jsx';
import ScheduleView from './ScheduleView.jsx';
import TodayView from './TodayView.jsx';
import FinanceView from './FinanceView.jsx';
import ReportsView from './ReportsView.jsx';
import ComplianceView from './ComplianceView.jsx';
import SettingsView from './SettingsView.jsx';
import AuditView from './AuditView.jsx';
import PricingView from './PricingView.jsx';
import OperationsView from './OperationsView.jsx';
import KnowledgeView from './KnowledgeView.jsx';
import VendorsView from './VendorsView.jsx';
import GrowthView from './GrowthView.jsx';
import CalendarView from './CalendarView.jsx';
import HRView from './HRView.jsx';
import GeographyView from './GeographyView.jsx';
import QuickCapture from './QuickCapture.jsx';
import './admin.css';

// The department taxonomy. `what` is the one-line definition shown in the shell
// until the department is built; it is the to-do list in plain sight.
const SECTIONS = [
  { key: 'today',     label: 'Today',          ready: true,
    what: 'The crystal ball. Today’s route and next stop, money in motion, and the briefing feed from your AI department heads.' },
  { key: 'calendar',  label: 'Calendar',       ready: true,
    what: 'Every appointment across the bath book and the legacy book, month and week, with a Google Calendar import overlay.' },
  { key: 'schedule',  label: 'Schedule',       ready: true,
    what: 'Set your work days and work hours, block a date, open a Saturday. Your real availability per city.' },
  { key: 'clients',   label: 'Clients',        ready: true,
    what: 'The contact-sheet database. Each client’s semi-permanent header over a growing visit history.' },
  { key: 'geography', label: 'Geography',      ready: true,
    what: 'Service polygons, plus-code zones, and the drive-time perimeter that gates new signups.' },
  { key: 'operations', label: 'Operations',    ready: true,
    what: 'The trailer, wash system, generators, climate, and maintenance intervals. Pre-trip checklist and maintenance-due alerts.' },
  { key: 'finance',   label: 'Finance',        ready: true,
    what: 'Revenue per visit and per hour, who owes you, the Square and Stripe split, and the expense ledger. Home of the CFO.' },
  { key: 'pricing',   label: 'Pricing',        ready: true,
    what: 'The locked price grid per city and coat tier, and the founders-spot counter.' },
  { key: 'hr',        label: 'HR',             ready: true,
    what: 'You today, your specialists later. Roles, hours, pay, commission tiers, and onboarding.' },
  { key: 'growth',    label: 'Growth',         ready: true,
    what: 'The lead funnel, the waitlist, referrals, retention, and a churn watch.' },
  { key: 'compliance', label: 'Compliance',    ready: true,
    what: 'Insurance and license renewals, A2P registration, payment-processor verification, and tax dates.' },
  { key: 'vendors',   label: 'Vendors',        ready: true,
    what: 'Suppliers, reorder points, and the running-low tracker for shampoo, water, and parts.' },
  { key: 'knowledge', label: 'Knowledge base', ready: true,
    what: 'The wisdom inbox: reasons captured by the speed dial or by replying to an agent, on their way into the Oracle or a client record.' },
  { key: 'reports',   label: 'Reports',        ready: true,
    what: 'Cross-department rollups: the weekly business review, the revenue-per-hour trend, and the briefing archive.' },
  { key: 'audit',     label: 'Audit log',      ready: true,
    what: 'Every owner action and every AI recommendation, append-only.' },
  { key: 'settings',  label: 'Settings',       ready: true,
    what: 'Owner identity, the Google, Stripe, Square, and Claude integrations, and notification killswitches.' },
];

const READY = SECTIONS.filter((s) => s.ready).map((s) => s.key);

// A Hurricane Bath Operator sees the floors the route needs and nothing
// else; the data inside them is masked server-side (admin_get_client and
// admin_today_appointments strip contact and money for the operator role),
// so this list is navigation, not the security boundary.
const OPERATOR_FLOORS = ['today', 'calendar', 'clients'];

export default function AdminApp() {
  const [session, setSession] = useState(null);
  const [authReady, setAuthReady] = useState(false);
  const [me, setMe] = useState(null);
  const [error, setError] = useState(null);
  const [section, setSection] = useState(() => {
    if (typeof window === 'undefined') return 'today';
    const params = new URLSearchParams(window.location.search);
    const s = params.get('section');
    if (s && SECTIONS.some((x) => x.key === s)) return s;
    return 'today';
  });
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [clientFocus, setClientFocus] = useState({ id: null, n: 0 });
  const closeDrawer = () => setDrawerOpen(false);
  const pickSection = (key) => { setSection(key); setDrawerOpen(false); };
  // Open a client's contact sheet from anywhere (e.g. a Today stop): jump to the
  // Clients floor and focus that record. The bumping nonce lets the same client
  // be re-opened on a later click.
  const openClient = (id) => { if (!id) return; setClientFocus((f) => ({ id, n: f.n + 1 })); setSection('clients'); setDrawerOpen(false); };

  useEffect(() => {
    let mounted = true;
    getSession().then((s) => { if (mounted) { setSession(s); setAuthReady(true); } });
    const { data: sub } = sb().auth.onAuthStateChange((_e, s) => {
      if (mounted) setSession(s);
    });
    return () => { mounted = false; sub?.subscription?.unsubscribe?.(); };
  }, []);

  const loadMe = useCallback(async () => {
    if (!session) return;
    setError(null);
    try {
      const a = await adminSelf();
      setMe(a || null);
    } catch (e) {
      setError(e.message || 'load_failed');
    }
  }, [session]);
  useEffect(() => { loadMe(); }, [loadMe]);

  if (!authReady) return <div className="ad-center"><div>Loading…</div></div>;

  if (!session) {
    return (
      <div className="ad-center">
        <div className="ad-gate">
          <h1>Orbit sign-in</h1>
          <p>Sign in with the Google account on file for your admin profile.</p>
          <button className="ad-btn ad-btn--full" onClick={signInWithGoogle}>
            Continue with Google
          </button>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="ad-center">
        <div className="ad-gate">
          <h1>Could not load Orbit</h1>
          <p>{error}</p>
          <button className="ad-btn ad-btn--ghost ad-btn--full" onClick={() => signOut().then(loadMe)}>
            Sign out
          </button>
        </div>
      </div>
    );
  }

  if (!me) {
    const email = session.user?.email || 'your Google account';
    return (
      <div className="ad-center">
        <div className="ad-gate">
          <h1>Not authorized</h1>
          <p>{email} is not an active admin. An existing admin must add you to the <span className="ad-mono">admins</span> table first.</p>
          <button className="ad-btn ad-btn--ghost ad-btn--full" onClick={() => signOut().then(loadMe)}>
            Sign out
          </button>
        </div>
      </div>
    );
  }

  const isOperator = me.role === 'operator';
  const visibleSections = isOperator ? SECTIONS.filter((s) => OPERATOR_FLOORS.includes(s.key)) : SECTIONS;
  const effectiveSection = isOperator && !OPERATOR_FLOORS.includes(section) ? 'today' : section;
  const active = SECTIONS.find((s) => s.key === effectiveSection);
  const activeLabel = active?.label || 'Orbit';

  return (
    <div className={'ad-app ' + (drawerOpen ? 'ad-app--drawer-open' : '')}>
      <div className="ad-mobilebar">
        <button
          type="button"
          className="ad-hamburger"
          aria-label="Open navigation"
          aria-expanded={drawerOpen}
          onClick={() => setDrawerOpen(true)}
        >
          <span /><span /><span />
        </button>
        <span className="ad-mobilebar__title">{activeLabel}</span>
      </div>

      <div
        className={'ad-scrim ' + (drawerOpen ? 'ad-scrim--on' : '')}
        onClick={closeDrawer}
        aria-hidden="true"
      />

      <aside className={'ad-side ' + (drawerOpen ? 'ad-side--open' : '')}>
        <div className="ad-side__brand">
          Dog Gone Clean<br />
          <small>Orbit</small>
          <button
            type="button"
            className="ad-side__close"
            aria-label="Close navigation"
            onClick={closeDrawer}
          >
            ×
          </button>
        </div>
        <nav className="ad-side__nav">
          {visibleSections.map((s) => (
            <button
              key={s.key}
              className={
                'ad-side__item ' +
                (effectiveSection === s.key ? 'ad-side__item--on ' : '') +
                (s.ready ? '' : 'ad-side__item--disabled')
              }
              onClick={() => pickSection(s.key)}
              title={s.ready ? '' : 'In the roadmap'}
            >
              <span>{s.label}</span>
              {!s.ready && <span className="ad-side__badge">soon</span>}
            </button>
          ))}
        </nav>
        <div className="ad-side__foot">
          Signed in as {me.first_name || me.email}<br />
          <button
            className="ad-btn ad-btn--ghost ad-btn--sm"
            style={{ marginTop: 6 }}
            onClick={() => signOut()}
          >
            Sign out
          </button>
        </div>
      </aside>

      <main className="ad-main">
        {effectiveSection === 'today' && <TodayView onOpenClient={openClient} />}
        {effectiveSection === 'clients' && <ClientsView focus={clientFocus} />}
        {effectiveSection === 'schedule' && <ScheduleView />}
        {effectiveSection === 'finance' && <FinanceView />}
        {effectiveSection === 'reports' && <ReportsView />}
        {effectiveSection === 'compliance' && <ComplianceView />}
        {effectiveSection === 'settings' && <SettingsView />}
        {effectiveSection === 'audit' && <AuditView />}
        {effectiveSection === 'pricing' && <PricingView />}
        {effectiveSection === 'operations' && <OperationsView />}
        {effectiveSection === 'knowledge' && <KnowledgeView />}
        {effectiveSection === 'vendors' && <VendorsView />}
        {effectiveSection === 'growth' && <GrowthView />}
        {effectiveSection === 'calendar' && <CalendarView />}
        {effectiveSection === 'hr' && <HRView />}
        {effectiveSection === 'geography' && <GeographyView />}
        {!READY.includes(effectiveSection) && <RoadmapPanel section={active} />}
      </main>

      <QuickCapture />
    </div>
  );
}

// Until a department is built it shows what will live there. This is the
// roadmap in plain sight, not a dead end: every door opens.
function RoadmapPanel({ section }) {
  if (!section) return null;
  return (
    <>
      <h1>{section.label}</h1>
      <p className="ad-sub">In the build roadmap.</p>
      <div className="ad-panel">
        <p>{section.what}</p>
      </div>
    </>
  );
}
