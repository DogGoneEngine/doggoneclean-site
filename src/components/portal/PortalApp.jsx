// src/components/portal/PortalApp.jsx
//
// Top-level orchestrator for the Dog Gone Clean client portal.
// Phase 1 scope: real sign-in (Google OAuth + phone OTP + email magic link),
// real auth-state tracking, and two honest authenticated landings:
//   - subscriber === null (signed in but no bath_subscribers row yet) ->
//       "Book your first visit to get started" empty state.
//   - subscriber exists -> a placeholder dashboard noting that the data
//     views (Pack, Plan, Payments, Reschedule, Skip, Cancel) ship in
//     Phase 2/3 sessions.
//
// The deep views from DGN's PortalViews port in subsequent slices.

import { useState, useEffect, useRef, useCallback } from 'react';
import './portal.css';
import { sb, getPortalData, signOut, withTimeout } from './supabase.js';
import AuthScreen from './AuthScreen.jsx';
import { PortalHome } from './PortalViews.jsx';

export default function PortalApp() {
  // 'checking' = evaluating session; 'anonymous' = no session;
  // 'authenticated' = signed in (data may still be loading).
  const [authState, setAuthState] = useState('checking');
  const [data, setData] = useState(null);
  const [dataError, setDataError] = useState(null);
  const [dataLoading, setDataLoading] = useState(false);
  // True when the auth check has hung past the timeout (paused or
  // unreachable backend). Lets us show a retry card instead of spinning
  // forever on the "checking" state.
  const [bootStuck, setBootStuck] = useState(false);

  const loadingInProgress = useRef(false);
  const [toastState, setToastState] = useState(null);
  const toastTimer = useRef(null);

  const toast = useCallback((msg, isError = false) => {
    clearTimeout(toastTimer.current);
    setToastState({ msg, error: isError });
    toastTimer.current = setTimeout(() => setToastState(null), 3200);
  }, []);

  const loadPortalData = useCallback(async () => {
    if (loadingInProgress.current) return;
    loadingInProgress.current = true;
    setDataLoading(true);
    setDataError(null);
    try {
      const payload = await withTimeout(getPortalData(), 8000, 'portal data');
      if (payload.error === 'not_authenticated') {
        setDataLoading(false);
        loadingInProgress.current = false;
        return;
      }
      if (payload.error) {
        setDataError(payload.error);
        setDataLoading(false);
        loadingInProgress.current = false;
        return;
      }
      setData(payload);
    } catch (err) {
      console.error('loadPortalData:', err);
      setDataError('unknown');
    } finally {
      loadingInProgress.current = false;
      setDataLoading(false);
    }
  }, []);

  // Auth listener: only set state. Network calls happen in a separate
  // effect (per the engineering rule auth_listener_sets_state_only).
  useEffect(() => {
    const client = sb();
    if (!client) return;
    const { data: { subscription: authSub } } = client.auth.onAuthStateChange(
      (event, session) => {
        if (event === 'INITIAL_SESSION') {
          setAuthState(session ? 'authenticated' : 'anonymous');
        } else if (event === 'SIGNED_IN') {
          setAuthState('authenticated');
        } else if (event === 'SIGNED_OUT') {
          setAuthState('anonymous');
          setData(null);
          setDataError(null);
        }
      }
    );
    return () => authSub.unsubscribe();
  }, []);

  // Watchdog: if the auth check is still running after the timeout, the
  // backend is unreachable (paused project, dead network). Flip to a retry
  // card instead of spinning on "checking" forever. The first auth event
  // (INITIAL_SESSION) normally lands in well under a second.
  useEffect(() => {
    if (authState !== 'checking') return;
    const t = setTimeout(() => setBootStuck(true), 8000);
    return () => clearTimeout(t);
  }, [authState]);

  // Load portal data when auth becomes authenticated and we have nothing yet.
  useEffect(() => {
    if (authState === 'authenticated' && !data && !dataLoading) {
      loadPortalData();
    }
  }, [authState, data, dataLoading, loadPortalData]);

  // Re-fetch portal data in place (no spinner flash) after a client action
  // changes server state (cancel, pause, restart, and the actions to come).
  const refresh = useCallback(async () => {
    try {
      const payload = await withTimeout(getPortalData(), 8000, 'portal data');
      if (!payload.error) setData(payload);
    } catch (err) {
      console.error('refresh:', err);
    }
  }, []);

  async function handleLogout() {
    await signOut();
    // SIGNED_OUT handler above clears the rest.
  }

  return (
    <div className="pt-shell">
      {authState === 'checking' && !bootStuck && (
        <div className="pt-center-fill">
          <div className="pt-spinner" />
        </div>
      )}

      {authState === 'checking' && bootStuck && (
        <div className="pt-center-fill">
          <div className="pt-auth-card" style={{ textAlign: 'center' }}>
            <h2 style={{ fontSize: 'var(--text-xl)', marginBottom: 'var(--space-md)' }}>
              We could not reach the server
            </h2>
            <p style={{ fontSize: 'var(--text-sm)', color: 'var(--soft)', marginBottom: 'var(--space-xl)' }}>
              The portal is not responding right now. Check your connection and try again in a moment.
            </p>
            <button
              className="pt-btn pt-btn-primary"
              onClick={() => window.location.reload()}
            >
              Try again
            </button>
          </div>
        </div>
      )}

      {authState === 'anonymous' && <AuthScreen />}

      {authState === 'authenticated' && (
        <>
          {dataLoading && (
            <div className="pt-center-fill">
              <div style={{ textAlign: 'center' }}>
                <div className="pt-spinner" />
                <p style={{ marginTop: 'var(--space-md)', fontSize: 'var(--text-sm)', color: 'var(--soft)' }}>
                  Loading your account...
                </p>
              </div>
            </div>
          )}

          {!dataLoading && dataError && (
            <div className="pt-center-fill">
              <div className="pt-auth-card" style={{ textAlign: 'center' }}>
                <h2 style={{ fontSize: 'var(--text-xl)', marginBottom: 'var(--space-md)' }}>
                  Something went wrong
                </h2>
                <p style={{ fontSize: 'var(--text-sm)', color: 'var(--soft)', marginBottom: 'var(--space-xl)' }}>
                  We could not load your account. Check your connection and try again.
                </p>
                <button
                  className="pt-btn pt-btn-primary"
                  onClick={() => { loadingInProgress.current = false; loadPortalData(); }}
                >
                  Try again
                </button>
                <div className="pt-empty__signout">
                  <button onClick={handleLogout}>Sign out</button>
                </div>
              </div>
            </div>
          )}

          {!dataLoading && !dataError && data && data.subscriber === null && (
            <EmptyStateNoSubscriber authUser={data.authUser} onLogout={handleLogout} />
          )}

          {!dataLoading && !dataError && data && data.subscriber && (
            <PortalHome data={data} onLogout={handleLogout} onChanged={refresh} toast={toast} />
          )}
        </>
      )}

      {toastState && (
        <div className={`pt-toast${toastState.error ? ' pt-toast-error' : ''}`}>
          {toastState.msg}
        </div>
      )}
    </div>
  );
}

// ── Empty state: signed in, no bath_subscribers row yet ───────────────
function EmptyStateNoSubscriber({ authUser, onLogout }) {
  const firstName = pickFirstName(authUser);
  return (
    <div className="pt-content">
      <div className="pt-empty">
        <div className="pt-empty__eyebrow">Welcome</div>
        <h1>
          You are signed in{firstName ? `, ${firstName}` : ''}.
        </h1>
        <p>
          You do not have a Hurricane Bath subscription yet. Book your
          first visit to lock in the founders rate.
        </p>

        <div className="pt-empty__panel">
          <h2>What happens at booking</h2>
          <ul>
            <li>Check your address (Villages, FL service area)</li>
            <li>Quick coat eligibility check (smoothcoat or doublecoat)</li>
            <li>Pick your cadence: every 4 weeks, every 2 weeks, or single visit</li>
            <li>Card on file, charged the day before each visit (never sooner)</li>
            <li>Cancel any time in two taps from this portal</li>
          </ul>
        </div>

        <div className="pt-empty__cta">
          <a className="pt-btn pt-btn-primary" href="/the-villages">See the founders offer</a>
          <a className="pt-btn pt-btn-ghost" href="/process">How a bath works</a>
        </div>

        <div className="pt-empty__signout">
          <button onClick={onLogout}>Sign out</button>
        </div>
      </div>
    </div>
  );
}

function pickFirstName(authUser) {
  if (!authUser) return '';
  const md = authUser.user_metadata || {};
  if (md.first_name) return md.first_name;
  if (md.given_name) return md.given_name;
  if (md.full_name) return String(md.full_name).split(' ')[0];
  if (md.name) return String(md.name).split(' ')[0];
  if (authUser.email) return authUser.email.split('@')[0];
  return '';
}
