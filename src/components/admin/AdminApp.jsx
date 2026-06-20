// src/components/admin/AdminApp.jsx
//
// Laelaps: the Dog Gone Clean admin console shell. Google OAuth gate, a
// department rail, and section routing. Every department is navigable from day
// one: the ones not yet built render a panel that states what lives there, so
// the structure itself is the roadmap. Clients is live; the rest fill in over
// the build sequence. Mirrors the Dog Gone Nails admin shell but talks only to
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
import EarningsView from './EarningsView.jsx';
import GeographyView from './GeographyView.jsx';
import QuickCapture from './QuickCapture.jsx';
import FamilyView from './FamilyView.jsx';
import LibraryView from './LibraryView.jsx';
import ProspectusView from './ProspectusView.jsx';
import AccessView from './AccessView.jsx';
import { SECTIONS, READY, floorsFor, ROLE_MODE } from './roles.js';
import './admin.css';

// SECTIONS, the floor lists, and the role definitions live in roles.js so the
// access map and this nav read one source of truth and cannot drift apart.

// A preview build is served under /preview, so its bundle bakes BASE_URL as
// '/preview/'. That is how the app knows to wear the preview banner. It is baked
// in at build time, so it cannot be turned off by mistake and it is impossible to
// confuse the preview with the live site, today or in four years (preview_before_live).
const IS_PREVIEW = (import.meta.env?.BASE_URL || '/').includes('preview');
function PreviewBanner() {
  return (
    <div style={{
      position: 'sticky', top: 0, zIndex: 70, background: '#b9170a', color: '#fff',
      textAlign: 'center', padding: '7px 12px', fontSize: 13, fontWeight: 600, lineHeight: 1.35,
    }}>
      PREVIEW BUILD, not the live site. It runs on the REAL live database, so anything you change here really saves.
    </div>
  );
}

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
  // Preview as: an owner can walk another role's menu. Owner-only, menu-only.
  const [previewRole, setPreviewRole] = useState(null);
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
      <>
      {IS_PREVIEW && <PreviewBanner />}
      <div className="ad-center">
        <div className="ad-gate">
          <h1>Laelaps sign-in</h1>
          <p>Sign in with the Google account on file for your admin profile.</p>
          <button className="ad-btn ad-btn--full" onClick={signInWithGoogle}>
            Continue with Google
          </button>
        </div>
      </div>
      </>
    );
  }

  if (error) {
    return (
      <div className="ad-center">
        <div className="ad-gate">
          <h1>Could not load Laelaps</h1>
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

  const isOwner = me.role === 'owner';
  // When the owner previews another role, only the menu changes; data stays the
  // owner's. The banner says so, and the Access page lists what is masked inside.
  const navRole = (isOwner && previewRole) ? previewRole : me.role;
  const floors = floorsFor(navRole);
  // Owners skip the Family floor in their own nav (it is for stakeholders);
  // it stays reachable by role, not by menu clutter.
  const visibleSections = floors
    ? SECTIONS.filter((s) => floors.includes(s.key))
    : SECTIONS.filter((s) => s.key !== 'family' && s.key !== 'pay');
  const effectiveSection = floors && !floors.includes(section)
    ? floors[0]
    : (!floors && section === 'family' ? 'today' : section);
  const active = SECTIONS.find((s) => s.key === effectiveSection);
  const activeLabel = active?.label || 'Laelaps';

  return (
    <div className={'ad-app ' + (drawerOpen ? 'ad-app--drawer-open' : '')}>
      {IS_PREVIEW && <PreviewBanner />}
      {isOwner && previewRole && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, zIndex: 60,
          background: 'var(--ad-primary, #2563d8)', color: '#fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12,
          padding: '8px 14px', fontSize: 13, flexWrap: 'wrap',
        }}>
          <span>Previewing the <strong>{ROLE_MODE[previewRole] || previewRole}</strong> menu. This is what they see; what is hidden inside is on the Access page.</span>
          <button className="ad-btn ad-btn--sm" style={{ background: '#fff', color: 'var(--ad-primary,#2563d8)' }}
            onClick={() => { setPreviewRole(null); setSection('access'); }}>
            Exit preview
          </button>
        </div>
      )}
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
        <span className="ad-laelaps ad-laelaps--bar" aria-label="Laelaps">
          <span className="ad-laelaps__mark">Laelaps</span>
          <span className="ad-laelaps__tag">The inescapable hound</span>
        </span>
      </div>

      <div
        className={'ad-scrim ' + (drawerOpen ? 'ad-scrim--on' : '')}
        onClick={closeDrawer}
        aria-hidden="true"
      />

      <aside className={'ad-side ' + (drawerOpen ? 'ad-side--open' : '')}>
        <div className="ad-side__brand">
          <img className="ad-side__logo" src="/logo.png?v=2" alt="Dog Gone Clean" />
          <span className="ad-laelaps ad-laelaps--side" aria-label="Laelaps">
            <span className="ad-laelaps__mark">Laelaps</span>
            <span className="ad-laelaps__tag">The inescapable hound</span>
          </span>
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
        {effectiveSection === 'family' && <FamilyView />}
        {effectiveSection === 'today' && <TodayView onOpenClient={openClient} />}
        {effectiveSection === 'pay' && <EarningsView />}
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
        {effectiveSection === 'library' && <LibraryView />}
        {effectiveSection === 'prospectus' && <ProspectusView />}
        {effectiveSection === 'access' && <AccessView onPreview={setPreviewRole} />}
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
