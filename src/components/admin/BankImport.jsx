// src/components/admin/BankImport.jsx
//
// Monthly bank-statement upload. Parses the CSV IN THE BROWSER and pulls out
// what was paid (outflows) with amount and billing day. The statement file is
// never uploaded or stored - only the costs Paul chooses to keep are written,
// via upsertRecurringCost. This keeps the full bank statement (and any personal
// transactions) out of the database, which honors clean_stays_saleable.

import { useEffect, useState } from 'react';
import { listRecurringCosts, upsertRecurringCost } from './supabase.js';

// --- tiny CSV parser (handles quoted fields, commas, escaped quotes) ---------
function parseCsv(text) {
  const rows = [];
  let row = [], field = '', inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else inQuotes = false; }
      else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field); field = '';
      if (row.some((x) => x.trim() !== '')) rows.push(row);
      row = [];
    } else field += c;
  }
  if (field !== '' || row.length) { row.push(field); if (row.some((x) => x.trim() !== '')) rows.push(row); }
  return rows;
}

function parseAmount(s) {
  if (s == null) return null;
  let t = String(s).trim();
  if (t === '') return null;
  const neg = /^\(.*\)$/.test(t) || t.includes('-');
  t = t.replace(/[()$,\s]/g, '').replace(/-/g, '');
  const n = parseFloat(t);
  if (isNaN(n)) return null;
  return neg ? -n : n;
}
function looksLikeDate(s) {
  if (!s) return false;
  return /\d{1,4}[\/\-.]\d{1,2}[\/\-.]\d{1,4}/.test(String(s)) || !isNaN(Date.parse(s));
}
function dayOfMonth(s) {
  const d = new Date(s);
  if (!isNaN(d.getTime())) return d.getDate();
  const m = String(s).match(/\d{1,4}[\/\-.](\d{1,2})[\/\-.]\d{1,4}/); // mm/dd
  return m ? parseInt(m[1], 10) : null;
}
function cleanDesc(s) {
  return String(s || '').replace(/\s+/g, ' ').replace(/\b\d{2,}\b/g, '').replace(/[*#]/g, '').trim().slice(0, 60) || 'Unnamed charge';
}
function guessCategory(name) {
  const n = name.toLowerCase();
  if (/supabase|digitalocean|aws|vercel|cloudflare|droplet|server/.test(n)) return 'infrastructure';
  if (/anthropic|openai|claude/.test(n)) return 'ai';
  if (/stripe|square|paypal/.test(n)) return 'payments';
  if (/google|resend|twilio|zapier|notion|github|software|app/.test(n)) return 'software';
  if (/domain|namecheap|godaddy|squarespace/.test(n)) return 'domains';
  if (/insur/.test(n)) return 'insurance';
  return 'other';
}

export default function BankImport({ onImported }) {
  const [existing, setExisting] = useState([]);
  const [rows, setRows] = useState(null);
  const [fileName, setFileName] = useState('');
  const [error, setError] = useState(null);
  const [savedIds, setSavedIds] = useState({});

  useEffect(() => {
    listRecurringCosts().then((d) => setExisting(d.items || [])).catch(() => {});
  }, []);

  function matchExisting(name) {
    const first = name.toLowerCase().split(' ')[0];
    if (!first || first.length < 3) return null;
    return existing.find((e) => {
      const en = (e.name || '').toLowerCase();
      return en.includes(first) || name.toLowerCase().includes((e.name || '').toLowerCase().split(' ')[0]);
    }) || null;
  }

  async function onFile(e) {
    setError(null); setRows(null); setSavedIds({});
    const file = e.target.files?.[0];
    if (!file) return;
    setFileName(file.name);
    try {
      const text = await file.text();
      const grid = parseCsv(text);
      if (grid.length < 2) throw new Error('That file has no rows I can read.');
      const header = grid[0].map((h) => h.trim().toLowerCase());
      const body = grid.slice(1);

      const findCol = (re) => header.findIndex((h) => re.test(h));
      let dateI = findCol(/date|posted/);
      let descI = findCol(/desc|name|memo|payee|detail|transaction|merchant/);
      let debitI = findCol(/debit|withdraw/);
      let creditI = findCol(/credit|deposit/);
      let amountI = findCol(/amount/);

      // Fallbacks by sniffing values if headers were unhelpful.
      if (dateI < 0) dateI = header.findIndex((_, i) => body.slice(0, 8).filter((r) => looksLikeDate(r[i])).length >= 4);
      if (descI < 0) {
        let best = -1, bestLen = 0;
        header.forEach((_, i) => { if (i === dateI) return; const len = body.slice(0, 10).reduce((a, r) => a + String(r[i] || '').length, 0); if (len > bestLen) { bestLen = len; best = i; } });
        descI = best;
      }
      if (amountI < 0 && debitI < 0) amountI = header.findIndex((_, i) => i !== dateI && i !== descI && body.slice(0, 8).filter((r) => parseAmount(r[i]) != null).length >= 4);

      const out = [];
      for (const r of body) {
        let outflow = null;
        if (debitI >= 0) { const d = parseAmount(r[debitI]); if (d && d > 0) outflow = d; }
        if (outflow == null && amountI >= 0) { const a = parseAmount(r[amountI]); if (a != null && a < 0) outflow = -a; }
        // a credit column with a value means money in -> skip
        if (creditI >= 0 && parseAmount(r[creditI])) continue;
        if (outflow == null || outflow <= 0) continue;
        const name = cleanDesc(descI >= 0 ? r[descI] : '');
        out.push({ key: out.length, name, amount: outflow, day: dateI >= 0 ? dayOfMonth(r[dateI]) : null, raw: descI >= 0 ? r[descI] : '' });
      }
      out.sort((a, b) => b.amount - a.amount);
      if (out.length === 0) throw new Error('I could not find any outflows. Check that this is a transactions export with a description and amount.');
      setRows(out);
    } catch (err) {
      setError(err.message || 'Could not read that file.');
    }
  }

  async function add(item) {
    const match = matchExisting(item.name);
    try {
      const id = await upsertRecurringCost({
        id: match?.id ?? null,
        name: match?.name ?? item.name,
        category: match?.category ?? guessCategory(item.name),
        amountCents: Math.round(item.amount * 100),
        cadence: match?.cadence ?? 'monthly',
        billingDay: item.day ?? match?.billing_day ?? null,
        active: true,
      });
      setSavedIds((s) => ({ ...s, [item.key]: match ? `updated ${match.name}` : 'added' }));
      const fresh = await listRecurringCosts();
      setExisting(fresh.items || []);
      onImported?.();
      return id;
    } catch (e) {
      setError(e.message || 'save_failed');
    }
  }

  return (
    <div className="ad-panel" style={{ marginTop: 12 }}>
      <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Import from a bank statement</div>
      <p style={{ fontSize: 13, opacity: 0.75, margin: '6px 0 10px' }}>
        Export your statement as CSV and choose it here. It is read in your browser to pull out what you paid; the file itself is never uploaded or stored. Pick the charges that are real business costs and they fill the tracker above with the amount and billing day.
      </p>
      <input type="file" accept=".csv,text/csv" onChange={onFile} />
      {fileName && <span style={{ fontSize: 12, opacity: 0.6, marginLeft: 8 }}>{fileName}</span>}
      {error && <div className="ad-error" style={{ marginTop: 8 }}>{error}</div>}

      {rows && (
        <div style={{ marginTop: 12 }}>
          <div style={{ fontSize: 12, opacity: 0.7, marginBottom: 6 }}>{rows.length} outflow(s) found. Add the recurring business costs:</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, maxHeight: '50vh', overflow: 'auto' }}>
            {rows.map((it) => {
              const match = matchExisting(it.name);
              const saved = savedIds[it.key];
              return (
                <div key={it.key} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 14, padding: '3px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)' }}>
                  <span style={{ width: 70, textAlign: 'right' }} className="ad-mono">${it.amount.toFixed(2)}</span>
                  <span style={{ flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {it.name}{it.day ? <span style={{ opacity: 0.5 }}> · day {it.day}</span> : null}
                    {match ? <span style={{ opacity: 0.55, fontSize: 12 }}> · matches {match.name}</span> : null}
                  </span>
                  {saved
                    ? <span style={{ fontSize: 12, color: 'var(--ad-good, #1f8a4b)' }}>{saved}</span>
                    : <button className="ad-btn ad-btn--sm" onClick={() => add(it)}>{match ? 'Update' : 'Add'}</button>}
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
