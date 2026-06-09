// src/components/admin/TodayView.jsx
//
// Today: the crystal ball. The standing feed of briefings from the AI department
// heads, newest first. Each card is a two-way conversation: read it, reply to the
// agent with context, approve its action, or mark it intentional so the agent
// stands down on that exact thing for good. The AI proposes; you decide and can
// talk back.

import { useCallback, useEffect, useState } from 'react';
import { listBriefings, setBriefingStatus, replyBriefing, resolveBriefing, listAgents, todayAppointments } from './supabase.js';
import RikerCapture from './RikerCapture.jsx';

const SERVICE_LABEL = { full_groom: 'Full groom', bath: 'Bath', nails: 'Nails' };
const STATUS_TINT = { confirmed: '#1f8a4b', tentative: '#2563d8', requested: '#b9770a', on_the_way: '#2563d8', on_site: '#2563d8', in_service: '#2563d8', completed: '#565b6c' };
function apptTime(ts) { try { return new Date(ts).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }); } catch { return ''; } }

const SEV = {
  alert:  { color: '#dc2626', label: 'Alert' },
  signal: { color: '#2563d8', label: 'Signal' },
  info:   { color: '#1f8a4b', label: 'Info' },
};
function money(c) { return c == null ? null : '$' + (c / 100).toFixed(2).replace(/\.00$/, ''); }

export default function TodayView({ onOpenClient }) {
  const [briefings, setBriefings] = useState([]);
  const [agents, setAgents] = useState([]);
  const [appts, setAppts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const [b, a, t] = await Promise.all([listBriefings(), listAgents(), todayAppointments()]);
      setBriefings(b.filter((x) => x.status === 'new' || x.status === 'read'));
      setAgents(a);
      setAppts(t);
    } catch (e) { setError(e.message || 'load_failed'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { load(); }, [load]);

  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
  const activeHeads = agents.filter((a) => a.is_active).map((a) => a.label);

  return (
    <>
      <h1>Today</h1>
      <p className="ad-sub">{today}. Your stops for the day, then the feed from your AI department heads. Talk back to any of them.</p>

      <div className="ad-panel" style={{ marginBottom: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6, marginBottom: 6 }}>Today's stops</div>
          <span style={{ fontSize: 12, opacity: 0.6 }}>{appts.length} {appts.length === 1 ? 'stop' : 'stops'}</span>
        </div>
        {appts.length === 0 ? (
          <div style={{ opacity: 0.65, fontSize: 14 }}>Nothing on the calendar for today.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            {appts.map((a) => {
              const clickable = !!a.client_id;
              return (
                <div
                  key={a.id}
                  onClick={clickable ? () => onOpenClient?.(a.client_id) : undefined}
                  style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 14, padding: '7px 6px', borderBottom: '1px solid var(--ad-outline, #ececf1)', cursor: clickable ? 'pointer' : 'default', borderRadius: 8 }}
                  title={clickable ? 'Open contact sheet' : 'Unmatched import'}
                >
                  <span className="ad-mono" style={{ width: 72, opacity: 0.75 }}>{apptTime(a.scheduled_start)}</span>
                  <span style={{ flex: 1, minWidth: 0 }}>
                    {a.client
                      ? <strong>{a.client}</strong>
                      : <strong style={{ color: 'var(--ad-warn,#b9770a)' }}>{a.fallback ? `${a.fallback} (unmatched)` : 'Unmatched import'}</strong>}
                    <span style={{ opacity: 0.6, fontSize: 12 }}> · {SERVICE_LABEL[a.service_type] || a.service_type || ''}{a.dog_count ? ` · ${a.dog_count} dog${a.dog_count === 1 ? '' : 's'}` : ''}{a.status === 'tentative' ? ' · pencilled' : ''}</span>
                  </span>
                  {a.amount_cents != null && a.amount_cents > 0 && <span className="ad-mono" style={{ fontSize: 12, opacity: 0.7 }}>{money(a.amount_cents)}</span>}
                  <span className="ad-mono" style={{ fontSize: 11, color: STATUS_TINT[a.status] || 'var(--ad-text-dim,#565b6c)' }}>{clickable ? '›' : ''}</span>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <RikerCapture onApplied={load} />

      {error && <div className="ad-error">{error}</div>}

      {loading ? (
        <div className="ad-panel">Loading the feed…</div>
      ) : briefings.length === 0 ? (
        <div className="ad-panel" style={{ opacity: 0.7 }}>
          No open briefings. {activeHeads.length ? `${activeHeads.join(', ')} ${activeHeads.length === 1 ? 'is' : 'are'} watching.` : 'Bring a department head online to start the feed.'}
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {briefings.map((b) => <BriefingCard key={b.id} b={b} onChanged={load} onError={setError} />)}
        </div>
      )}
    </>
  );
}

function BriefingCard({ b, onChanged, onError }) {
  const sev = SEV[b.severity] || SEV.info;
  const ev = b.evidence || {};
  const notes = b.notes || [];
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);

  async function run(fn) {
    setBusy(true);
    try { await fn(); onChanged(); }
    catch (e) { onError(e.message || 'action_failed'); setBusy(false); }
  }
  const doReply = () => reply.trim() && run(() => replyBriefing(b.id, reply.trim()));
  const doIntentional = () => run(() => resolveBriefing(b.id, 'intentional', reply.trim() || null));
  const doDismiss = () => run(() => resolveBriefing(b.id, 'dismissed', reply.trim() || null));

  return (
    <div className="ad-panel" style={{ borderLeft: `4px solid ${sev.color}` }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
        <strong style={{ fontSize: 16 }}>{b.title}</strong>
        <span className="ad-mono" style={{ fontSize: 11, color: sev.color }}>{sev.label} · {b.agent_key.toUpperCase()}</span>
      </div>
      {b.body && <p style={{ margin: '8px 0', fontSize: 14, lineHeight: 1.5 }}>{b.body}</p>}
      {Object.keys(ev).length > 0 && (
        <div className="ad-mono" style={{ fontSize: 11, opacity: 0.65, display: 'flex', flexWrap: 'wrap', gap: 10 }}>
          {ev.visits != null && <span>visits {ev.visits}</span>}
          {ev.revenue_per_hour != null && <span>rev/hr ${ev.revenue_per_hour}</span>}
          {ev.business_rate != null && <span>rate ${ev.business_rate}</span>}
          {ev.days_since != null && <span>{ev.days_since}d since visit</span>}
          {ev.revenue_cents != null && <span>collected {money(ev.revenue_cents)}</span>}
          {ev.ar_count != null && ev.ar_count > 0 && <span>A/R {ev.ar_count}</span>}
        </div>
      )}

      {/* conversation thread */}
      {notes.length > 0 && (
        <div style={{ margin: '10px 0', display: 'flex', flexDirection: 'column', gap: 6 }}>
          {notes.map((n, i) => (
            <div key={i} style={{ alignSelf: n.author === 'paul' ? 'flex-end' : 'flex-start', maxWidth: '85%' }}>
              <div style={{
                fontSize: 13, padding: '6px 10px', borderRadius: 10, lineHeight: 1.4,
                background: n.author === 'paul' ? 'var(--ad-primary-container, #e6edfc)' : 'var(--ad-surface-container, #f1f1f4)',
              }}>{n.body}</div>
              <div className="ad-mono" style={{ fontSize: 10, opacity: 0.4, textAlign: n.author === 'paul' ? 'right' : 'left', marginTop: 1 }}>
                {n.author === 'paul' ? 'you' : b.agent_key}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* reply box */}
      <textarea
        value={reply} onChange={(e) => setReply(e.target.value)} disabled={busy}
        placeholder="Tell the agent what's up (e.g. she's on a fixed income, leave her price alone)…"
        rows={2}
        style={{ width: '100%', marginTop: 8, fontSize: 13, padding: '6px 8px', borderRadius: 8, border: '1px solid var(--ad-outline, #d8d8de)', resize: 'vertical', boxSizing: 'border-box', fontFamily: 'inherit' }}
      />
      <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
        <button className="ad-btn ad-btn--sm" onClick={doReply} disabled={busy || !reply.trim()}>Reply</button>
        {b.recommended_action && <button className="ad-btn ad-btn--sm" onClick={() => run(() => setBriefingStatus(b.id, 'approved'))} disabled={busy}>Approve</button>}
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={doIntentional} disabled={busy} title="This is on purpose; stop flagging it">This is intentional</button>
        <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={doDismiss} disabled={busy}>Dismiss</button>
        {b.status === 'new' && <button className="ad-btn ad-btn--ghost ad-btn--sm" onClick={() => run(() => setBriefingStatus(b.id, 'read'))} disabled={busy}>Mark read</button>}
      </div>
    </div>
  );
}
