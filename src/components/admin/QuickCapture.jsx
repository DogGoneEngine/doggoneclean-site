// src/components/admin/QuickCapture.jsx
//
// The speed dial, now the one gateway (Paul 2026-06-10): the floating + on
// every Orbit floor sends whatever Paul says THROUGH RIKER, who routes it to
// its real home: a client's visit, a note, a roster change, a notify person,
// or (for ideas, rules, and business thoughts) the wisdom inbox for the
// Archivist. One button, one habit, everything filed. Nothing writes until
// the one-tap Confirm.

import { useEffect, useRef, useState } from 'react';
import { rikerParse, rikerApply } from './supabase.js';
import { RikerManual, describeApplied } from './RikerCapture.jsx';

export default function QuickCapture() {
  const [open, setOpen] = useState(false);
  const [body, setBody] = useState('');
  const [phase, setPhase] = useState('idle'); // idle | parsing | review | applying
  const [plan, setPlan] = useState(null);
  const [saved, setSaved] = useState(null); // describeApplied() output after a confirm
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

  async function send() {
    if (!body.trim()) return;
    setPhase('parsing'); setError(null); setSaved(null);
    try {
      setPlan(await rikerParse(body.trim(), null));
      setPhase('review');
    } catch (e) { setError(e.message || 'parse_failed'); setPhase('idle'); }
  }

  // After Confirm, say exactly what landed and stay open until Paul closes;
  // a silent auto-close read as "it went into the void".
  async function confirm() {
    setPhase('applying'); setError(null);
    try {
      const res = await rikerApply(plan);
      setPlan(null); setBody(''); setPhase('idle');
      setSaved(describeApplied(res));
    } catch (e) { setError(e.message || 'apply_failed'); setPhase('review'); }
  }

  const canApply = plan && plan.matched !== false && (plan.client_id || plan.wisdom || plan.reminder);

  return (
    <>
      <button onClick={() => setOpen(true)} title="Tell Clio (text or voice); she files it where it belongs"
        style={{
          position: 'fixed', right: 20, bottom: 20, zIndex: 50, width: 52, height: 52, borderRadius: '50%',
          border: 'none', cursor: 'pointer', fontSize: 22, color: '#fff',
          background: 'var(--ad-primary, #2563d8)', boxShadow: '0 4px 14px rgba(0,0,0,0.25)',
        }}>+</button>

      {open && (
        <div onClick={() => phase === 'idle' && setOpen(false)} style={{
          position: 'fixed', inset: 0, zIndex: 60, background: 'rgba(0,0,0,0.35)',
          display: 'flex', alignItems: 'flex-end', justifyContent: 'center', padding: 16,
        }}>
          <div onClick={(e) => e.stopPropagation()} className="ad-panel" style={{ width: '100%', maxWidth: 560, marginBottom: 60 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
              <strong style={{ fontSize: 15 }}>Tell Clio</strong>
              <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => setOpen(false)} disabled={phase === 'applying'}>Close</button>
            </div>

            {phase !== 'review' ? (
              <>
                <p style={{ fontSize: 12, opacity: 0.65, margin: '0 0 8px' }}>
                  Anything: a visit, a note, a roster change, who to text, or just an idea. Clio files it where it belongs. Say "because" so the reason rides along.
                </p>
                <textarea value={body} onChange={(e) => setBody(e.target.value)} disabled={phase === 'parsing'} rows={4} autoFocus
                  placeholder="e.g. Windsor moved away, archive him. Or: idea for the portal, because..."
                  style={{ width: '100%', fontSize: 14, padding: '8px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }} />
                <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 8, flexWrap: 'wrap' }}>
                  {speechOk && (
                    <button className={'ad-btn ad-btn--sm ' + (listening ? '' : 'ad-btn--ghost')} onClick={toggleVoice} disabled={phase === 'parsing'}>
                      {listening ? '\u25cf listening\u2026 tap to stop' : '\ud83c\udfa4 voice'}
                    </button>
                  )}
                  <div style={{ flex: 1 }} />
                  <button className="ad-btn ad-btn--sm" onClick={send} disabled={phase === 'parsing' || !body.trim()}>
                    {phase === 'parsing' ? 'Clio is listening\u2026' : 'Send to Clio'}
                  </button>
                </div>
                {saved && (
                  <div style={{ fontSize: 13, marginTop: 8, lineHeight: 1.45, color: 'var(--ad-good, #1f8a4b)' }}>
                    Understood. Recorded: {saved.bits.length ? saved.bits.join(', ') : 'nothing actionable'}.
                    {saved.missed && (
                      <div style={{ color: 'var(--ad-warn, #b9770a)' }}>
                        Could not find the visit you wanted corrected; open the sheet and check the visit history.
                      </div>
                    )}
                  </div>
                )}
                <RikerManual />
              </>
            ) : (
              <div style={{ fontSize: 14, lineHeight: 1.5 }}>
                <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>
                  Clio will record
                </div>
                {plan.matched === false && !plan.wisdom && !plan.reminder ? (
                  <div style={{ color: 'var(--ad-warn, #b9770a)' }}>
                    {plan.summary || 'Could not tell which client you meant.'}
                    {(plan.candidates || []).length > 0 && (
                      <div style={{ fontSize: 13, opacity: 0.75, marginTop: 4 }}>
                        Did you mean: {plan.candidates.map((c) => c.name).join(', ')}?
                      </div>
                    )}
                  </div>
                ) : (
                  <>
                    <div><strong>{plan.client_name || (plan.wisdom ? 'Business wisdom' : plan.reminder ? 'Reminder' : 'Client')}</strong></div>
                    {plan.summary && <div style={{ opacity: 0.8, margin: '2px 0 8px' }}>{plan.summary}</div>}
                  </>
                )}
                <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                  {canApply && (
                    <button className="ad-btn ad-btn--sm" onClick={confirm} disabled={phase === 'applying'}>
                      {phase === 'applying' ? 'Saving\u2026' : 'Confirm'}
                    </button>
                  )}
                  <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => { setPlan(null); setPhase('idle'); }} disabled={phase === 'applying'}>
                    {canApply ? 'Cancel' : 'Back'}
                  </button>
                </div>
              </div>
            )}
            {error && <div className="ad-error" style={{ marginTop: 6 }}>{error}</div>}
          </div>
        </div>
      )}
    </>
  );
}
