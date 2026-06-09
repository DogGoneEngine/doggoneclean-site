// src/components/admin/BankImport.jsx
//
// Monthly bank-statement upload. Parses the CSV in the browser, pulls out every
// outflow, and imports them ALL as business expenses by default (it is the
// business account, so everything out of it is a business expense). Re-imports
// are idempotent (deduped on the server by date + amount + description). The
// only per-row action is the rare exception: untick a charge that is not a
// business expense before importing.

import { useState } from 'react';
import { importExpenses } from './supabase.js';

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
function looksLikeDate(s) { return s ? (/\d{1,4}[\/\-.]\d{1,2}[\/\-.]\d{1,4}/.test(String(s)) || !isNaN(Date.parse(s))) : false; }
function isoDate(s) {
  const d = new Date(s);
  if (!isNaN(d.getTime())) return d.toISOString().slice(0, 10);
  const m = String(s).match(/(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})/); // mm/dd/yyyy
  if (m) { let [_, a, b, y] = m; if (y.length === 2) y = '20' + y; return `${y}-${a.padStart(2, '0')}-${b.padStart(2, '0')}`; }
  return null;
}
function cleanDesc(s) { return String(s || '').replace(/\s+/g, ' ').replace(/[*#]/g, '').trim().slice(0, 80) || 'Unnamed charge'; }
function guessCategory(name) {
  const n = name.toLowerCase();
  if (/supabase|digitalocean|aws|vercel|cloudflare|server/.test(n)) return 'infrastructure';
  if (/anthropic|openai|claude/.test(n)) return 'ai';
  if (/stripe|square|paypal|fee/.test(n)) return 'payments';
  if (/google|resend|twilio|zapier|notion|github|adobe|microsoft|software/.test(n)) return 'software';
  if (/domain|namecheap|godaddy|squarespace/.test(n)) return 'domains';
  if (/insur/.test(n)) return 'insurance';
  if (/shell|chevron|exxon|bp|fuel|gas|wawa|circle k|racetrac/.test(n)) return 'fuel';
  if (/petco|petsmart|chewy|tractor supply|shampoo|supply/.test(n)) return 'supplies';
  if (/facebook|meta|instagram|google ads|yelp|advertis/.test(n)) return 'marketing';
  return 'other';
}

export default function BankImport({ onImported }) {
  const [rows, setRows] = useState(null);
  const [fileName, setFileName] = useState('');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState(null);

  async function onFile(e) {
    setError(null); setRows(null); setResult(null);
    const file = e.target.files?.[0];
    if (!file) return;
    setFileName(file.name);
    try {
      const grid = parseCsv(await file.text());
      if (grid.length < 2) throw new Error('That file has no rows I can read.');
      const header = grid[0].map((h) => h.trim().toLowerCase());
      const body = grid.slice(1);
      const findCol = (re) => header.findIndex((h) => re.test(h));
      let dateI = findCol(/date|posted/);
      let descI = findCol(/desc|name|memo|payee|detail|transaction|merchant/);
      const debitI = findCol(/debit|withdraw/);
      const creditI = findCol(/credit|deposit/);
      let amountI = findCol(/amount/);
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
        if (creditI >= 0 && parseAmount(r[creditI])) continue;
        if (outflow == null || outflow <= 0) continue;
        const date = dateI >= 0 ? isoDate(r[dateI]) : null;
        if (!date) continue;
        const name = cleanDesc(descI >= 0 ? r[descI] : '');
        out.push({ key: out.length, date, name, amount: outflow, category: guessCategory(name), business: true });
      }
      out.sort((a, b) => (a.date < b.date ? 1 : -1));
      if (out.length === 0) throw new Error('I could not find any outflows. Check that this is a transactions export with a date, description, and amount.');
      setRows(out);
    } catch (err) { setError(err.message || 'Could not read that file.'); }
  }

  const total = rows ? rows.filter((r) => r.business).reduce((a, r) => a + r.amount, 0) : 0;

  async function doImport() {
    setBusy(true); setError(null);
    try {
      const payload = rows.map((r) => ({ txn_date: r.date, description: r.name, amount_cents: Math.round(r.amount * 100), category: r.category, is_business: r.business }));
      const res = await importExpenses(payload);
      setResult(res); setRows(null); setFileName('');
      onImported?.();
    } catch (e) { setError(e.message || 'import_failed'); }
    finally { setBusy(false); }
  }

  return (
    <div className="ad-panel" style={{ marginTop: 12 }}>
      <div style={{ fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.4, opacity: 0.6 }}>Import a bank statement</div>
      <p style={{ fontSize: 13, opacity: 0.75, margin: '6px 0 10px' }}>
        Export your business-account statement as CSV and choose it here. It is read in your browser and every outflow imports as a business expense. Re-uploading is safe, charges already imported are skipped. Untick anything that is not a business expense before importing.
      </p>
      <input type="file" accept=".csv,text/csv" onChange={onFile} disabled={busy} />
      {fileName && <span style={{ fontSize: 12, opacity: 0.6, marginLeft: 8 }}>{fileName}</span>}
      {error && <div className="ad-error" style={{ marginTop: 8 }}>{error}</div>}
      {result && <div className="ad-success" style={{ marginTop: 8 }}>Imported {result.inserted} expense(s){result.skipped ? `, ${result.skipped} already on file` : ''}.</div>}

      {rows && (
        <div style={{ marginTop: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 8 }}>
            <span style={{ fontSize: 13, opacity: 0.75 }}>{rows.filter((r) => r.business).length} of {rows.length} outflows · <strong>${total.toFixed(2)}</strong></span>
            <button className="ad-btn ad-btn--sm" onClick={doImport} disabled={busy}>{busy ? 'Importing…' : `Import ${rows.filter((r) => r.business).length} as business expenses`}</button>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 2, maxHeight: '50vh', overflow: 'auto' }}>
            {rows.map((it) => (
              <div key={it.key} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, padding: '3px 0', borderBottom: '1px solid var(--ad-outline, #ececf1)', opacity: it.business ? 1 : 0.45 }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: 4 }} title="business expense?">
                  <input type="checkbox" checked={it.business} onChange={(e) => setRows((rs) => rs.map((x) => x.key === it.key ? { ...x, business: e.target.checked } : x))} />
                </label>
                <span className="ad-mono" style={{ width: 78, textAlign: 'right' }}>${it.amount.toFixed(2)}</span>
                <span style={{ width: 78, opacity: 0.6, fontSize: 12 }}>{it.date.slice(5)}</span>
                <span style={{ flex: 1, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{it.name}</span>
                <span className="ad-mono" style={{ fontSize: 11, opacity: 0.5 }}>{it.category}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
