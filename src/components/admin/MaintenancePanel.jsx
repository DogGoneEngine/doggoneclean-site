// src/components/admin/MaintenancePanel.jsx
//
// The full maintenance schedule: every service task across the generators (by
// hours) and the appliances (filter cleanings, by days), with its status and a
// Done button. Marking a task done timestamps it (and snapshots the generator
// hours), which resets its cycle. The watcher posts the same items to Today.

import { useCallback, useEffect, useState } from 'react';
import { listMaintenanceTasks, markTaskDone } from './supabase.js';

const STATUS = {
  due: { label: 'due', color: 'var(--ad-bad, #dc2626)' },
  soon: { label: 'soon', color: 'var(--ad-warn, #b9770a)' },
  ok: { label: 'ok', color: 'var(--ad-good, #1f8a4b)' },
  'enter hours': { label: 'enter hours', color: 'var(--ad-warn, #b9770a)' },
  'log last done': { label: 'log last done', color: 'var(--ad-warn, #b9770a)' },
};

export default function MaintenancePanel() {
  const [tasks, setTasks] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [busyId, setBusyId] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setTasks(await listMaintenanceTasks()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function done(id) {
    setBusyId(id);
    try { await markTaskDone(id); await load(); }
    catch (e) { setError(e.message || 'mark_failed'); }
    finally { setBusyId(null); }
  }

  if (error) return <div className="ad-error">{error}</div>;
  if (loading || !tasks) return <div className="ad-panel">Loading schedule…</div>;
  if (tasks.length === 0) return null;

  return (
    <div className="ad-panel">
      <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 8 }}>Maintenance schedule</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        {tasks.map((t) => {
          const s = STATUS[t.status] || STATUS.ok;
          const cadence = t.interval_hours ? `every ${t.interval_hours}h` : `every ${t.interval_days}d`;
          return (
            <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, padding: '4px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)' }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <strong>{t.task}</strong> <span style={{ opacity: 0.6 }}>· {t.equipment}</span>
                <span style={{ opacity: 0.45, fontSize: 11 }}> · {cadence}</span>
              </div>
              <span style={{ fontSize: 12, color: s.color, width: 78, textAlign: 'right' }}>{s.label}</span>
              <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => done(t.id)} disabled={busyId === t.id} title="mark done now">Done</button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
