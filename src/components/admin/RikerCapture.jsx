// src/components/admin/RikerCapture.jsx
//
// Clio (the persona's display name; the plumbing key stays `riker`, the generic
// role layer): say it, it gets entered. Paul dictates a short note (his phone's
// voice-to-text fills the box) and Clio parses it into a plan of record updates.
// Nothing is written until Paul taps Confirm (one-tap confirm). Used two ways: on
// a client sheet (clientId fixed) and on Today (no client, Riker resolves the name
// Paul says). The AI proposes; the tap writes. See riker_capture_agent.

import { useState } from 'react';
import { rikerParse, rikerApply, addAlias } from './supabase.js';

const SERVICE = { full_groom: 'Full groom', bath: 'Bath', nails: 'Nails' };
const PAY = { square_in_person: 'Square', stripe_card: 'Stripe', cash: 'Cash', wallet: 'Wallet' };
function money(c) { return c == null ? null : '$' + (c / 100).toFixed(2).replace(/\.00$/, ''); }
// Format a YYYY-MM-DD birthday for the confirm line without a timezone shift
// (new Date('2015-05-20') would render the day before in US time zones).
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
function birthday(s) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s || '');
  return m ? `${MONTHS[+m[2] - 1]} ${+m[3]}, ${m[1]}` : null;
}

// Turn the apply result into the plain acknowledgment Paul asked for: after
// Confirm he hears exactly what landed, never a silent void.
export function describeApplied(res) {
  const n = (x) => Number(x || 0);
  const bits = [];
  if (res.visit_merged) bits.push("added to today's visit record (no duplicate)");
  else if (res.visit_id) bits.push('visit logged');
  if (res.visit_corrected) bits.push('the existing visit record corrected');
  if (n(res.scores_applied) > 0) bits.push(`${n(res.scores_applied)} vibe score${n(res.scores_applied) === 1 ? '' : 's'} saved`);
  if (n(res.dogs_added) > 0) bits.push(`${n(res.dogs_added)} dog card${n(res.dogs_added) === 1 ? '' : 's'} created`);
  if (n(res.dogs_updated) > 0) bits.push(`${n(res.dogs_updated)} dog card${n(res.dogs_updated) === 1 ? '' : 's'} changed`);
  if (res.client_updated) bits.push('contact sheet facts updated');
  if (res.onsite_appended) bits.push("added to who's on site");
  if (res.client_note_appended) bits.push('household note added');
  if (n(res.dog_notes_appended) > 0) bits.push(`${n(res.dog_notes_appended)} dog note${n(res.dog_notes_appended) === 1 ? '' : 's'} added`);
  if (n(res.dog_status_changes) > 0) bits.push('dog roster updated');
  if (res.notify_person_id) bits.push('notify person saved');
  if (res.reminder_id) bits.push('reminder set, it will surface on Today when due');
  if (res.wisdom_saved) bits.push('filed to the wisdom inbox');
  return { bits, missed: !!res.visit_update_missed, noNotifyContact: !!res.notify_person_missing_contact };
}

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
      // Household names go through the tested admin_add_alias RPC, not the big
      // apply RPC. Paul already saw them listed before tapping Confirm.
      const aliases = (plan.client_id && Array.isArray(plan.alias_add)) ? plan.alias_add.filter(Boolean) : [];
      let aliasCount = 0;
      for (const a of aliases) { try { await addAlias(plan.client_id, a); aliasCount++; } catch { /* one bad alias never blocks the rest */ } }
      const d = describeApplied(res);
      if (aliasCount > 0) d.bits.push(`${aliasCount} household name${aliasCount === 1 ? '' : 's'} added`);
      setDone(d);
      setPlan(null); setText(''); setPhase('idle');
      onApplied?.();
    } catch (e) { setError(e.message || 'apply_failed'); setPhase('review'); }
  }

  function cancel() { setPlan(null); setPhase('idle'); setError(null); }

  const v = plan?.visit;
  const canApply = plan && plan.matched !== false && (plan.client_id || plan.wisdom || plan.reminder);

  return (
    <div className="ad-panel" style={{ marginBottom: 16, borderLeft: '4px solid var(--ad-primary, #2563d8)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
        <strong style={{ fontSize: 14 }}>Tell Clio</strong>
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
              {phase === 'parsing' ? 'Clio is listening…' : 'Send to Clio'}
            </button>
          </div>
          {done && (
            <div style={{ fontSize: 13, marginTop: 8, lineHeight: 1.45, color: 'var(--ad-good, #1f8a4b)' }}>
              Understood. Recorded: {done.bits.length ? done.bits.join(', ') : 'nothing actionable'}.
              {done.missed && (
                <div style={{ color: 'var(--ad-warn, #b9770a)' }}>
                  Could not find the visit you wanted corrected; open the sheet and check the visit history.
                </div>
              )}
              {done.noNotifyContact && (
                <div style={{ color: 'var(--ad-warn, #b9770a)' }}>
                  Did not add the notify person: no phone or email was given, so they cannot be messaged. Say the name again with a phone number to add them.
                </div>
              )}
            </div>
          )}
          <RikerManual />
        </>
      )}

      {error && <div className="ad-error" style={{ marginTop: 8 }}>{error}</div>}

      {phase === 'review' && plan && (
        <div style={{ marginTop: 4 }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>
            Clio will write exactly this
          </div>
          {plan.matched === false ? (
            <div>
              <div style={{ fontSize: 14, color: 'var(--ad-warn, #b9770a)' }}>
                {plan.summary || 'Could not tell which client you meant.'}
              </div>
              {(plan.candidates || []).length > 0 && (
                <div style={{ fontSize: 13, opacity: 0.75, marginTop: 4 }}>
                  Did you mean: {plan.candidates.map((c) => c.name).join(', ')}? Open the sheet and tell Clio there, or say the full name.
                </div>
              )}
            </div>
          ) : (
            <div style={{ fontSize: 14, lineHeight: 1.5 }}>
              {/* Show the exact fields and values she will write, not a prose
                  summary of what Paul said. A wrong drawer or an invented value is
                  then obvious before the one-tap Confirm (clio_confirm_shows_fields). */}
              <div style={{ marginBottom: 6 }}>
                <span style={{ opacity: 0.55 }}>Record: </span>
                <strong>{plan.client_name || (plan.wisdom ? 'Business wisdom' : 'Client')}</strong>
              </div>
              <ul style={{ margin: '6px 0', paddingLeft: 18, fontSize: 13 }}>
                {v && (
                  <li>
                    Visit logged{v.visited_at ? ` for ${v.visited_at}` : ''}{v.service_type ? ` (${SERVICE[v.service_type] || v.service_type})` : ''}
                    {v.actual_minutes ? `, ${v.actual_minutes} min` : ''}
                    {v.amount_cents != null ? `, ${money(v.amount_cents)}` : ''}
                    {v.payment_method ? ` ${PAY[v.payment_method] || v.payment_method}` : ''}
                  </li>
                )}
                {(plan.dog_add || []).map((d, i) => (
                  <li key={`add${i}`}>
                    New dog card: <strong>{d.name}</strong>
                    {d.breed ? `, ${d.breed}` : ''}{d.price_cents != null ? `, ${money(d.price_cents)}` : ''}
                    {d.notes ? ` (${d.notes})` : ''}
                  </li>
                ))}
                {(plan.dog_update || []).map((d, i) => {
                  // Show every field the apply RPC will write (price, breed,
                  // birthday), so a birthday-only change is never a blank line
                  // (clio_confirm_shows_fields). The apply path writes the
                  // birthday too, per migration 0185.
                  const parts = [];
                  if (d.price_cents != null) parts.push(`price to ${money(d.price_cents)}`);
                  if (d.breed) parts.push(`breed to ${d.breed}`);
                  if (birthday(d.birthday)) parts.push(`birthday to ${birthday(d.birthday)}${d.dob_approximate ? ' (approximate)' : ''}`);
                  return (
                    <li key={`upd${i}`}>
                      Card change for <strong>{d.dog_name || 'dog'}</strong>{parts.length ? `: ${parts.join(', ')}` : ''}
                    </li>
                  );
                })}
                {(v?.dog_scores || []).map((s) => (
                  <li key={s.dog_id}>Vibe score for {s.dog_name || 'dog'}: <strong>{s.score}</strong></li>
                ))}
                {v?.work_done && <li>What was done: {v.work_done}</li>}
                {v?.visit_notes && <li>Visit note: {v.visit_notes}</li>}
                {plan.client_update && (
                  <li>
                    Contact sheet facts:
                    {plan.client_update.phone ? ` phone ${plan.client_update.phone}` : ''}
                    {plan.client_update.email ? ` email ${plan.client_update.email}` : ''}
                    {plan.client_update.address ? ` address ${plan.client_update.address}` : ''}
                    {plan.client_update.status ? ` status ${plan.client_update.status.replace('_', ' ')}` : ''}
                    {plan.client_update.suppress_winback ? ' no win-back outreach' : ''}
                  </li>
                )}
                {plan.visit_update && (
                  <li>
                    Correct the {plan.visit_update.date} visit:
                    {plan.visit_update.service_type ? ` service to ${SERVICE[plan.visit_update.service_type] || plan.visit_update.service_type}` : ''}
                    {plan.visit_update.amount_cents != null ? ` amount to ${money(plan.visit_update.amount_cents)}` : ''}
                    {plan.visit_update.actual_minutes ? ` minutes to ${plan.visit_update.actual_minutes}` : ''}
                  </li>
                )}
                {plan.onsite_update && <li>Who's on site: {plan.onsite_update}</li>}
                {(plan.alias_add || []).map((a, i) => (
                  <li key={`al${i}`}>Household name (also known as): <strong>{a}</strong></li>
                ))}
                {plan.client_note && <li>Add to the contact sheet: {plan.client_note}</li>}
                {(plan.dog_notes || []).map((d, i) => (
                  <li key={i}>Note on {d.dog_name || 'dog'}: {d.text}</li>
                ))}
                {(plan.dog_status || []).map((s, i) => (
                  <li key={`st${i}`}>
                    Roster: <strong>{s.dog_name || 'dog'}</strong> marked {s.status === 'moved' ? 'moved away' : s.status === 'former' ? 'no longer groomed' : s.status}
                    {s.note ? ` (${s.note})` : ''}
                  </li>
                ))}
                {plan.wisdom && (
                  <li>To the wisdom inbox (the Archivist files it): {plan.wisdom}</li>
                )}
                {plan.reminder && (
                  <li>On your plate {plan.reminder.due ? `for ${plan.reminder.due}` : ''}: {plan.reminder.body}</li>
                )}
                {plan.notify_person && (
                  <li>
                    {plan.notify_person.mode === 'instead' ? 'Send the appointment messages to ' : 'Also send the appointment messages to '}
                    <strong>{plan.notify_person.name}</strong>
                    {plan.notify_person.phone ? ` (${plan.notify_person.phone})` : plan.notify_person.email ? ` (${plan.notify_person.email})` : ''}
                    {plan.notify_person.mode === 'instead' ? ' instead of the client' : ''}
                    {plan.notify_person.until ? `, until ${plan.notify_person.until}` : ''}
                    {!plan.notify_person.phone && !plan.notify_person.email && (
                      <span style={{ color: 'var(--ad-warn, #b9770a)' }}> (no phone or email yet, so this person will be skipped until you add one)</span>
                    )}
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


// The living instruction manual: what Riker can hear and file today. One
// list, shown everywhere Riker takes input, updated in the same commit as
// each new power so it can never drift from reality.
export function RikerManual() {
  return (
    <details style={{ fontSize: 12, opacity: 0.75, marginTop: 6 }}>
      <summary style={{ cursor: 'pointer' }}>What can I tell Clio?</summary>
      <ul style={{ margin: '6px 0 0', paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 3 }}>
        <li><strong>Log a visit:</strong> "Bella was a five today, full groom, 90 minutes, collected 120 cash." Service, minutes, money, payment method, what was done. Past visits work too: "at the previous appointment, Sammy was a four."</li>
        <li><strong>Vibe scores:</strong> per dog, 1 to 5, only when you actually give one.</li>
        <li><strong>New dogs:</strong> "Add Maverick, French Bulldog, 75 dollars, and Sammy, mini Aussie, 105." Real dog cards with breed and price.</li>
        <li><strong>Price and breed changes:</strong> "Change the price to 50 dollars each." Lands on the dog cards, not as a note.</li>
        <li><strong>Who is at the house:</strong> "Alan answers the door." Lands in the Who's-on-site field.</li>
        <li><strong>Household names:</strong> "Add her husband Zach as a household name." Lands in the Also-known-as field, so a search for that name opens the household.</li>
        <li><strong>Contact facts:</strong> "Her phone number is 352-875-4172" or a new email or address. Lands in the contact fields, not as a note.</li>
        <li><strong>Corrections:</strong> "That last visit should have been nails, not a full groom." Fixes the existing visit record instead of creating a new one.</li>
        <li><strong>Moved away or paused:</strong> "She moved away, may or may not be back, no need to chase her." Marks the client moved away and turns off win-back outreach.</li>
        <li><strong>Notes:</strong> household notes ("gate code is now 4411") and per-dog notes ("Bruno hates the dryer").</li>
        <li><strong>Dog roster:</strong> "Windsor moved away, archive him." Moved, passed away, no longer groomed, sometimes, or back on the roster. Reversible, never deleted.</li>
        <li><strong>People to notify:</strong> "Jane wants her husband Tom texted too, 352-555-0101" or "text the dog sitter Maria instead of Jane until July 10."</li>
        <li><strong>Reminders:</strong> "If I have not booked her by then, contact Mary in 2 weeks." It surfaces on Today when it comes due.</li>
        <li><strong>Anything else:</strong> ideas, rules, decisions, business thoughts. If it is not about one client's record, it lands in the wisdom inbox and the Archivist files it. Say "because" so the reason rides along.</li>
      </ul>
      <div style={{ marginTop: 4, opacity: 0.8 }}>Nothing is written until you tap Confirm. Clio cannot book or move appointments or change business rules; booking lives on the contact sheet, rules go through Claude.</div>
    </details>
  );
}
