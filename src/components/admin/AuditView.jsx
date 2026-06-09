// src/components/admin/AuditView.jsx
//
// The Audit department: the append-only record. Every AI department-head run and
// every recommendation it made, on the books. The trust-and-saleability layer:
// a buyer (or you) can see exactly what the system has done.

import { useCallback, useEffect, useState } from 'react';
import { auditFeed } from './supabase.js';

function fmt(ts) { if (!ts) return ''; try { return new Date(ts).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); } catch { return ts; } }

export default function AuditView() {
  const [d, setD] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setD(await auditFeed(80)); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  if (error) return <><h1>Audit log</h1><div className="ad-error">{error}</div></>;
  if (loading || !d) return <><h1>Audit log</h1><div className="ad-panel">Loading…</div></>;

  return (
    <>
      <h1>Audit log</h1>
      <p className="ad-sub">Every department-head run and every recommendation, on the record.</p>

      <div className="ad-panel" style={{ marginBottom: 14 }}>
        <Cap>Admins</Cap>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 6 }}>
          {(d.admins || []).map((a) => (
            <span key={a.email} className="ad-mono" style={{ fontSize: 12 }}>{a.email}{a.active ? '' : ' (inactive)'}</span>
          ))}
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 16 }}>
        <div className="ad-panel">
          <Cap>Recommendations · {(d.briefings || []).length}</Cap>
          <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 6, maxHeight: '60vh', overflow: 'auto' }}>
            {(d.briefings || []).map((b, i) => (
              <div key={i} style={{ fontSize: 13, borderBottom: '1px solid var(--ad-outline, #ececf1)', paddingBottom: 4 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
                  <span>{b.title}</span>
                  <span className="ad-mono" style={{ fontSize: 11, opacity: 0.55, whiteSpace: 'nowrap' }}>{b.agent_key.toUpperCase()} · {b.status}</span>
                </div>
                <div className="ad-mono" style={{ fontSize: 11, opacity: 0.5 }}>{fmt(b.created_at)}</div>
              </div>
            ))}
            {(d.briefings || []).length === 0 && <div style={{ opacity: 0.6 }}>No recommendations yet.</div>}
          </div>
        </div>

        <div className="ad-panel">
          <Cap>Agent runs · {(d.runs || []).length}</Cap>
          <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 4, maxHeight: '60vh', overflow: 'auto' }}>
            {(d.runs || []).map((r, i) => (
              <div key={i} style={{ display: 'flex', justifyContent: 'space-between', gap: 8, fontSize: 12, borderBottom: '1px solid var(--ad-outline, #ececf1)', padding: '2px 0' }}>
                <span><strong>{r.agent_key.toUpperCase()}</strong> <span style={{ opacity: 0.6 }}>{r.model || ''}</span></span>
                <span className="ad-mono" style={{ opacity: 0.6, whiteSpace: 'nowrap' }}>
                  {r.status}{r.tokens ? ` · ${r.tokens}t` : ''} · {fmt(r.started_at)}
                </span>
              </div>
            ))}
            {(d.runs || []).length === 0 && <div style={{ opacity: 0.6 }}>No runs yet.</div>}
          </div>
        </div>
      </div>
    </>
  );
}
function Cap({ children }) { return <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>{children}</div>; }
