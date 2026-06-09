/**
 * Dog Gone Clean - Google Calendar -> app sync.
 *
 * Runs inside Paul's own Google account (no service-account key, which Google
 * blocks by default on new projects). Reads his primary calendar and pushes
 * grooming appointments to the calendar-ingest edge function, which matches each
 * to an existing client and mirrors it into the app. Set a time-driven trigger
 * on syncCalendar() to run every 15 minutes.
 */

const INGEST_URL = 'https://urebdrosrxejhubpbxsa.supabase.co/functions/v1/calendar-ingest';
const SECRET = 'd382120e23ba4ecfb70f4ba1f947ccd4a87fb1b7ee5c40388650c5c83ead870e';

function syncCalendar() {
  const cal = CalendarApp.getDefaultCalendar();
  const now = new Date();
  const from = new Date(now.getTime() - 2 * 86400000);   // 2 days back
  const to = new Date(now.getTime() + 45 * 86400000);    // 45 days forward
  const events = cal.getEvents(from, to);
  const rows = [];
  for (const e of events) {
    if (e.isAllDayEvent()) continue;
    const title = (e.getTitle() || '').trim();
    if (!title || /^reserve\b/i.test(title) || /^(block|busy|hold|lunch|off)\b/i.test(title)) continue;
    const name = title.split(':')[0].trim();
    if (!name) continue;
    const desc = e.getDescription() || '';
    const email = (desc.match(/Email:\s*([^\s\n]+@[^\s\n]+)/i) || [])[1] || null;
    const dogs = (title.match(/(\d+)\s*Dogs?\b/i) || desc.match(/Groom\s+(\d+)\s+Dog/i) || [])[1];
    const price = (desc.match(/Price:\s*\$?([\d.]+)/i) || [])[1];
    rows.push({
      external_id: e.getId() + '|' + e.getStartTime().toISOString(),
      starts: e.getStartTime().toISOString(),
      ends: e.getEndTime().toISOString(),
      client_name: name,
      client_email: email,
      dog_count: dogs ? parseInt(dogs, 10) : null,
      service_type: /nail/i.test(title) ? 'nails' : 'full_groom',
      amount_cents: price ? Math.round(parseFloat(price) * 100) : null,
      notes: e.getLocation() || null
    });
  }
  UrlFetchApp.fetch(INGEST_URL, {
    method: 'post',
    contentType: 'application/json',
    headers: { 'x-cfo-secret': SECRET },
    payload: JSON.stringify({ events: rows, from: from.toISOString(), to: to.toISOString() }),
    muteHttpExceptions: true
  });
}
