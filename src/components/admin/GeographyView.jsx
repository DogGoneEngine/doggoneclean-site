// src/components/admin/GeographyView.jsx
//
// The Geography floor. The service cities and where the clients actually are, by
// zone. A data view today; the interactive Google Map (JS API + service-area
// polygon overlay) is the enhancement that sits on top of this same data.

import { useCallback, useEffect, useState } from 'react';
import { geographySummary } from './supabase.js';

export default function GeographyView() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setData(await geographySummary()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  if (error) return <><h1>Geography</h1><div className="ad-error">{error}</div></>;
  if (loading || !data) return <><h1>Geography</h1><div className="ad-panel">Loading…</div></>;

  const zones = data.zones || [];
  const maxZone = Math.max(1, ...zones.map((z) => z.count));

  return (
    <>
      <h1>Geography</h1>
      <p className="ad-sub">Where you serve and where the clients are. {data.geocoded} of {data.total_clients} clients are geocoded for the map.</p>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8 }}>Service cities</div>
        <table className="ad-table">
          <tbody>
            {(data.cities || []).map((c) => (
              <tr key={c.name}>
                <td><strong>{c.name}</strong> <span style={{ opacity: 0.5 }}>{c.state}</span></td>
                <td style={{ textAlign: 'center', fontSize: 12, color: c.active ? 'var(--ad-good,#1f8a4b)' : 'var(--ad-text-faint,#8b8f9e)' }}>{c.active ? 'live' : 'not live'}</td>
                <td style={{ textAlign: 'right', fontSize: 12, opacity: 0.6 }}>{c.has_perimeter ? 'service area set' : 'no perimeter'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="ad-panel">
        <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8 }}>Clients by zone</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
          {zones.map((z) => (
            <div key={z.zone}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, marginBottom: 2 }}>
                <span>{z.zone}</span>
                <span className="ad-mono">{z.count}</span>
              </div>
              <div style={{ height: 6, background: 'var(--ad-surface-container,#f0f0f3)', borderRadius: 4 }}>
                <div style={{ height: 6, width: `${(z.count / maxZone) * 100}%`, background: 'var(--ad-primary,#2563d8)', borderRadius: 4 }} />
              </div>
            </div>
          ))}
          {zones.length === 0 && <div style={{ opacity: 0.6 }}>No zones recorded yet.</div>}
        </div>
      </div>

      <div style={{ fontSize: 12, opacity: 0.55, marginTop: 12 }}>
        Next on this floor: the interactive Google map (JS API) with the service-area polygons and a pin per client, drawn from the same cities and geocodes.
      </div>
    </>
  );
}
