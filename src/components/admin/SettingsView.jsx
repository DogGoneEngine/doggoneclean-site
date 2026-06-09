// src/components/admin/SettingsView.jsx
//
// The Settings department: the god-mode system view. What is connected, which
// department heads are online and on what schedule, the scheduled jobs, and who
// has the keys. Read-only; the actual config lives in Supabase and the edge
// secrets, never in the page.

import { useCallback, useEffect, useState } from 'react';
import { systemStatus } from './supabase.js';

// Friendly labels for the known secrets (names only are ever read, never values).
const SECRET_LABELS = {
  maps_server_key: 'Google Maps',
  resend_api_key: 'Resend (email)',
  notifications_secret: 'Notifications dispatch',
  notifications_live: 'Notifications live switch',
  edge_base_url: 'Edge base URL',
  cfo_cron_secret: 'CFO cron secret',
};
function fmt(ts) { if (!ts) return 'never'; try { return new Date(ts).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); } catch { return ts; } }

export default function SettingsView() {
  const [d, setD] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setD(await systemStatus()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  if (error) return <><h1>Settings</h1><div className="ad-error">{error}</div></>;
  if (loading || !d) return <><h1>Settings</h1><div className="ad-panel">Loading…</div></>;

  return (
    <>
      <h1>Settings</h1>
      <p className="ad-sub">The system at a glance: what is connected, who is watching, and who holds the keys.</p>

      <div className="ad-panel" style={{ marginBottom: 14 }}>
        <Cap>You</Cap>
        <div style={{ marginTop: 6, fontSize: 14 }}>{d.me?.name || 'Admin'} · <span className="ad-mono" style={{ opacity: 0.7 }}>{d.me?.email}</span></div>
        <div style={{ fontSize: 12, opacity: 0.6, marginTop: 2 }}>God mode. Single active admin; adding more is a roles decision for later.</div>
      </div>

      <div className="ad-panel" style={{ marginBottom: 14 }}>
        <Cap>Integrations configured</Cap>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 8 }}>
          {(d.secrets || []).map((s) => (
            <span key={s} className="ad-mono" style={{ fontSize: 12, padding: '3px 9px', borderRadius: 8, background: 'var(--ad-primary-container, #e6edfc)' }}>
              {SECRET_LABELS[s] || s}
            </span>
          ))}
          <span className="ad-mono" style={{ fontSize: 12, padding: '3px 9px', borderRadius: 8, background: 'var(--ad-primary-container, #e6edfc)' }}>Anthropic key (edge secret, verified)</span>
        </div>
      </div>

      <div className="ad-panel" style={{ marginBottom: 14 }}>
        <Cap>Department heads</Cap>
        <table className="ad-table" style={{ marginTop: 6 }}>
          <tbody>
            {(d.agents || []).map((a) => (
              <tr key={a.label}>
                <td><strong>{a.label}</strong> <span style={{ opacity: 0.5, fontSize: 12 }}>{a.department}</span></td>
                <td style={{ textAlign: 'center' }}>
                  <span style={{ fontSize: 12, color: a.is_active ? 'var(--ad-good, #1f8a4b)' : 'var(--ad-text-faint, #8b8f9e)' }}>{a.is_active ? 'online' : 'dormant'}</span>
                </td>
                <td className="ad-mono" style={{ textAlign: 'right', fontSize: 12, opacity: 0.6 }}>{a.schedule_cron || '—'}</td>
                <td className="ad-mono" style={{ textAlign: 'right', fontSize: 12, opacity: 0.6 }}>last: {fmt(a.last_run)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="ad-panel" style={{ marginBottom: 14 }}>
        <Cap>Scheduled jobs</Cap>
        <table className="ad-table" style={{ marginTop: 6 }}>
          <tbody>
            {(d.crons || []).map((c) => (
              <tr key={c.job}>
                <td>{c.job}</td>
                <td className="ad-mono" style={{ textAlign: 'right', fontSize: 12, opacity: 0.7 }}>{c.schedule}</td>
                <td style={{ textAlign: 'right', fontSize: 12, color: c.active ? 'var(--ad-good, #1f8a4b)' : 'var(--ad-text-faint, #8b8f9e)' }}>{c.active ? 'on' : 'off'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="ad-panel">
        <Cap>The book</Cap>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, marginTop: 8, fontSize: 14 }}>
          {Object.entries(d.counts || {}).map(([k, v]) => (
            <span key={k}><strong>{v}</strong> <span style={{ opacity: 0.6 }}>{k.replace(/_/g, ' ')}</span></span>
          ))}
        </div>
      </div>
    </>
  );
}
function Cap({ children }) { return <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>{children}</div>; }
