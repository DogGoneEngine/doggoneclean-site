// src/components/admin/QuickCapture.jsx
//
// The speed dial. A floating button on every Orbit floor: hit it the moment an
// idea lands and dump it by typing or by voice. It goes straight to the wisdom
// inbox (Knowledge Base) to be absorbed into the Oracle or a client record. The
// whole point is zero friction between having a thought and capturing it.

import { useEffect, useRef, useState } from 'react';
import { captureWisdom } from './supabase.js';

const SCOPES = ['business', 'pricing', 'operations', 'growth', 'finance', 'compliance', 'client', 'other'];

export default function QuickCapture() {
  const [open, setOpen] = useState(false);
  const [body, setBody] = useState('');
  const [scope, setScope] = useState('business');
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState(null);
  const [listening, setListening] = useState(false);
  const recRef = useRef(null);

  const speechOk = typeof window !== 'undefined' && (window.SpeechRecognition || window.webkitSpeechRecognition);

  useEffect(() => () => { try { recRef.current?.stop(); } catch { /* noop */ } }, []);

  function toggleVoice() {
    if (!speechOk) return;
    if (listening) { try { recRef.current?.stop(); } catch { /* noop */ } setListening(false); return; }
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    const rec = new SR();
    rec.continuous = true; rec.interimResults = false; rec.lang = 'en-US';
    rec.onresult = (e) => {
      let t = '';
      for (let i = e.resultIndex; i < e.results.length; i++) t += e.results[i][0].transcript;
      setBody((prev) => (prev ? prev + ' ' : '') + t.trim());
    };
    rec.onerror = () => setListening(false);
    rec.onend = () => setListening(false);
    recRef.current = rec;
    try { rec.start(); setListening(true); } catch { setListening(false); }
  }

  async function save() {
    if (!body.trim()) return;
    setBusy(true); setError(null);
    try {
      await captureWisdom(body.trim(), scope);
      setBody(''); setSaved(true); setTimeout(() => { setSaved(false); setOpen(false); }, 900);
    } catch (e) { setError(e.message || 'save_failed'); }
    finally { setBusy(false); }
  }

  return (
    <>
      <button onClick={() => setOpen(true)} title="Capture an idea (text or voice)"
        style={{
          position: 'fixed', right: 20, bottom: 20, zIndex: 50, width: 52, height: 52, borderRadius: '50%',
          border: 'none', cursor: 'pointer', fontSize: 22, color: '#fff',
          background: 'var(--ad-primary, #2563d8)', boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
        }}>+</button>

      {open && (
        <div onClick={() => !busy && setOpen(false)} style={{
          position: 'fixed', inset: 0, zIndex: 60, background: 'rgba(0,0,0,0.35)',
          display: 'flex', alignItems: 'flex-end', justifyContent: 'center', padding: 16,
        }}>
          <div onClick={(e) => e.stopPropagation()} className="ad-panel" style={{ width: '100%', maxWidth: 560, marginBottom: 60 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
              <strong style={{ fontSize: 15 }}>Capture an idea</strong>
              <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(false)} disabled={busy}>Close</button>
            </div>
            <p style={{ fontSize: 12, opacity: 0.65, margin: '0 0 8px' }}>Lead with the reason. Try to say "because" so it lands as wisdom, not just a note.</p>
            <textarea value={body} onChange={(e) => setBody(e.target.value)} disabled={busy} rows={4} autoFocus
              placeholder="The idea, and the because behind it…"
              style={{ width: '100%', fontSize: 14, padding: '8px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }} />
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 8, flexWrap: 'wrap' }}>
              {speechOk && (
                <button className={'ad-btn ad-btn--sm ' + (listening ? '' : 'ad-btn--ghost')} onClick={toggleVoice} disabled={busy}>
                  {listening ? '● listening… tap to stop' : '🎤 voice'}
                </button>
              )}
              <select className="ad-select" value={scope} onChange={(e) => setScope(e.target.value)} disabled={busy}>
                {SCOPES.map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
              <div style={{ flex: 1 }} />
              <button className="ad-btn ad-btn--sm" onClick={save} disabled={busy || !body.trim()}>{saved ? 'Saved' : 'Capture'}</button>
            </div>
            {error && <div className="ad-error" style={{ marginTop: 6 }}>{error}</div>}
          </div>
        </div>
      )}
    </>
  );
}
