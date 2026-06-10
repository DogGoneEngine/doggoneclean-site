// src/components/admin/RikerCapture.jsx
//
// Riker: say it, it gets entered. Paul dictates a short note (his phone's
// voice-to-text fills the box) and Riker parses it into a plan of record updates.
// Nothing is written until Paul taps Confirm (one-tap confirm). Used two ways: on
// a client sheet (clientId fixed) and on Today (no client, Riker resolves the name
// Paul says). The AI proposes; the tap writes. See riker_capture_agent.

import { useState } from 'react';
import { rikerParse, rikerApply } from './supabase.js';

const SERVICE = { full_groom: 'Full groom', bath: 'Bath', nails: 'Nails' };
const PAY = { square_in_person: 'Square', stripe_card: 'Stripe', cash: 'Cash', wallet: 'Wallet' };
function money(c) { return c == null ? null : '$' + (c / 100).toFixed(2).replace(/\.00$/, ''); }

export default function RikerCapture({ clientId = null, clientName = null, onApplied }) {
  const [text, setText] = useState('');
  const [phase, setPhase] = useState('idle'); // idle | parsing | review | applying
  const [plan, setPlan] = useState(null);
  const [error, setError] = useState(null);
  const [done, setDone] = useState(null);

  async function send() {
    if (!text.trim()) return;
    setPhase('parsing'); setError(null); setDone(null);
    try {
      setPlan(await rikerParse(text.trim(), clientId));
      setPhase('review');
    } catch (e) { setError(e.message || 'parse_failed'); setPhase('idle'); }
  }

  async function confirm() {
    setPhase('applying'); setError(null);
    try {
      const res = await rikerApply(plan);
      setDone(res);
      setPlan(null); setText(''); setPhase('idle');
      onApplied?.();
    } catch (e) { setError(e.message || 'apply_failed'); setPhase('review'); }
  }

  function cancel() { setPlan(null); setPhase('idle'); setError(null); }

  const v = plan?.visit;
  const canApply = plan && plan.matched !== false && plan.client_id;

  return (
    <div className="ad-panel" style={{ marginBottom: 16, borderLeft: '4px solid var(--ad-primary, #2563d8)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
        <strong style={{ fontSize: 14 }}>Tell Riker</strong>
        <span style={{ fontSize: 12, opacity: 0.6 }}>
          {clientName ? `about ${clientName}` : 'say the client, then what happened'}
        </span>
      </div>

      {phase !== 'review' && (
        <>
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            disabled={phase === 'parsing'}
            rows={2}
            placeholder={clientName
              ? 'e.g. Bella was a five today, took 45 minutes, 60 in cash. Wants the sanitary trim shorter from now on.'
              : 'e.g. Mary Jane Hunt, both dogs were fours, paid 90 by card.'}
            style={{ width: '100%', fontSize: 14, padding: '8px 10px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }}
          />
          <div style={{ display: 'flex', gap: 8, marginTop: 8, alignItems: 'center' }}>
            <button className="ad-btn ad-btn--sm" onClick={send} disabled={phase === 'parsing' || !text.trim()}>
              {phase === 'parsing' ? 'Riker is listening…' : 'Send to Riker'}
            </button>
            {done && <span style={{ fontSize: 12, color: 'var(--ad-good, #1f8a4b)' }}>Recorded.</span>}
          </div>
        </>
      )}

      {error && <div className="ad-error" style={{ marginTop: 8 }}>{error}</div>}

      {phase === 'review' && plan && (
        <div style={{ marginTop: 4 }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>
            Riker will record
          </div>
          {plan.matched === false ? (
            <div>
              <div style={{ fontSize: 14, color: 'var(--ad-warn, #b9770a)' }}>
                {plan.summary || 'Could not tell which client you meant.'}
              </div>
              {(plan.candidates || []).length > 0 && (
                <div style={{ fontSize: 13, opacity: 0.75, marginTop: 4 }}>
                  Did you mean: {plan.candidates.map((c) => c.name).join(', ')}? Open the sheet and tell Riker there, or say the full name.
                </div>
              )}
            </div>
          ) : (
            <div style={{ fontSize: 14, lineHeight: 1.5 }}>
              <div><strong>{plan.client_name || 'Client'}</strong></div>
              {plan.summary && <div style={{ opacity: 0.8, margin: '2px 0 8px' }}>{plan.summary}</div>}
              <ul style={{ margin: '6px 0', paddingLeft: 18, fontSize: 13 }}>
                {v && (
                  <li>
                    Visit logged{v.service_type ? ` (${SERVICE[v.service_type] || v.service_type})` : ''}
                    {v.actual_minutes ? `, ${v.actual_minutes} min` : ''}
                    {v.amount_cents != null ? `, ${money(v.amount_cents)}` : ''}
                    {v.payment_method ? ` ${PAY[v.payment_method] || v.payment_method}` : ''}
                  </li>
                )}
                {(v?.dog_scores || []).map((s) => (
                  <li key={s.dog_id}>Vibe score for {s.dog_name || 'dog'}: <strong>{s.score}</strong></li>
                ))}
                {v?.work_done && <li>What was done: {v.work_done}</li>}
                {v?.visit_notes && <li>Visit note: {v.visit_notes}</li>}
                {plan.client_note && <li>Add to the contact sheet: {plan.client_note}</li>}
                {(plan.dog_notes || []).map((d, i) => (
                  <li key={i}>Note on {d.dog_name || 'dog'}: {d.text}</li>
                ))}
                {plan.notify_person && (
                  <li>
                    {plan.notify_person.mode === 'instead' ? 'Send the appointment messages to ' : 'Also send the appointment messages to '}
                    <strong>{plan.notify_person.name}</strong>
                    {plan.notify_person.phone ? ` (${plan.notify_person.phone})` : plan.notify_person.email ? ` (${plan.notify_person.email})` : ''}
                    {plan.notify_person.mode === 'instead' ? ' instead of the client' : ''}
                    {plan.notify_person.until ? `, until ${plan.notify_person.until}` : ''}
                  </li>
                )}
              </ul>
            </div>
          )}
          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            {canApply && (
              <button className="ad-btn ad-btn--sm" onClick={confirm} disabled={phase === 'applying'}>
                {phase === 'applying' ? 'Saving…' : 'Confirm'}
              </button>
            )}
            <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={cancel} disabled={phase === 'applying'}>
              {canApply ? 'Cancel' : 'Back'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
