// src/components/admin/KnowledgeView.jsx
//
// The Knowledge Base: the wisdom inbox. Everything Paul captured by the speed
// dial or by talking back to an agent lands here, scoped to a client or a
// department. From here it gets absorbed into the Oracle or a client record;
// "File" marks it handled. The reasons (the becauses) are the business's memory.

import { useCallback, useEffect, useState } from 'react';
import { listWisdom, setWisdomStatus, captureWisdom } from './supabase.js';

function fmt(ts) { try { return new Date(ts).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }); } catch { return ts; } }

export default function KnowledgeView() {
  const [items, setItems] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try { setItems(await listWisdom()); }
    catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  async function add() {
    if (!text.trim()) return;
    setBusy(true);
    try { await captureWisdom(text.trim()); setText(''); await load(); }
    catch (e) { setError(e.message || 'save_failed'); }
    finally { setBusy(false); }
  }
  async function file(id) {
    try { await setWisdomStatus(id, 'filed'); load(); }
    catch (e) { setError(e.message || 'file_failed'); }
  }

  const inbox = (items || []).filter((w) => w.status === 'inbox');
  const filed = (items || []).filter((w) => w.status === 'filed');

  return (
    <>
      <h1>Knowledge base</h1>
      <p className="ad-sub">The business's memory. Reasons you capture here, by the speed dial or by replying to an agent, get absorbed into the Oracle or a client's record.</p>

      <div className="ad-panel" style={{ marginBottom: 16, display: 'flex', gap: 8, alignItems: 'flex-start' }}>
        <textarea value={text} onChange={(e) => setText(e.target.value)} rows={2} placeholder="Capture a reason or rule (lead with the because)…"
          style={{ flex: 1, fontSize: 14, padding: '8px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }} />
        <button className="ad-btn ad-btn--sm" onClick={add} disabled={busy || !text.trim()}>Capture</button>
      </div>

      {error && <div className="ad-error">{error}</div>}
      {loading || !items ? (
        <div className="ad-panel">Loading…</div>
      ) : (
        <>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Inbox · {inbox.length}</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 20 }}>
            {inbox.length === 0 && <div className="ad-panel" style={{ opacity: 0.7 }}>Nothing waiting. Capture an idea above or with the + button.</div>}
            {inbox.map((w) => <Card key={w.id} w={w} onFile={() => file(w.id)} />)}
          </div>
          {filed.length > 0 && (
            <>
              <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Filed · {filed.length}</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {filed.map((w) => <Card key={w.id} w={w} filed />)}
              </div>
            </>
          )}
        </>
      )}
    </>
  );
}

const HOME_LABEL = {
  oracle_rule: 'Oracle rule', client_note: 'client note', parking_lot: 'parking lot',
  field_manual: 'field manual', drop: 'drop',
};

function Card({ w, onFile, filed }) {
  return (
    <div className="ad-panel" style={{ opacity: filed ? 0.65 : 1, padding: '10px 12px' }}>
      <div style={{ fontSize: 14, lineHeight: 1.45 }}>{w.body}</div>
      {w.proposed_home && !filed && (
        <div style={{ marginTop: 8, paddingLeft: 10, borderLeft: '3px solid var(--ad-primary, #2563d8)' }}>
          <div className="ad-mono" style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.5 }}>
            Archivist proposes · {HOME_LABEL[w.proposed_home] || w.proposed_home}
          </div>
          {w.proposed_text && <div style={{ fontSize: 13, opacity: 0.85, marginTop: 2 }}>{w.proposed_text}</div>}
        </div>
      )}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 6 }}>
        <span className="ad-mono" style={{ fontSize: 11, opacity: 0.55 }}>
          {w.scope}{w.client ? ` · ${w.client}` : ''} · {w.source === 'briefing' ? 'from a reply' : 'captured'} · {fmt(w.created_at)}
        </span>
        {!filed && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={onFile}>File</button>}
      </div>
    </div>
  );
}
