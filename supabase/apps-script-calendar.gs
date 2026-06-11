/**
 * Dog Gone Clean - Google Calendar -> app sync.
 *
 * Runs inside Paul's own Google account (no service-account key, which Google
 * blocks by default on new projects). Reads his primary calendar AND, if it
 * exists, a calendar named "Dog Gone Clean", so the cutover can run in
 * parallel: Paul can start booking new appointments straight into the Dog
 * Gone Clean calendar while old ones live on the default calendar, and the
 * app sees both. The final flip (calendar_flip_order) then just removes the
 * default calendar from this list and moves the stragglers. Pushes events to
 * the calendar-ingest edge function, which matches each to an existing
 * client and mirrors it into the app. Set a time-driven trigger on
 * syncCalendar() to run every 15 minutes.
 */

const INGEST_URL = 'https://urebdrosrxejhubpbxsa.supabase.co/functions/v1/calendar-ingest';
const SECRET = 'd382120e23ba4ecfb70f4ba1f947ccd4a87fb1b7ee5c40388650c5c83ead870e';
const BUSINESS_CALENDAR_NAME = 'Dog Gone Clean';
// Banana is Paul's private pencil color: year-ahead placeholders the client
// has never been told about. They sync as tentative, never as confirmed.
const BANANA_COLOR = '5';

function syncCalendar() {
  const calendars = [CalendarApp.getDefaultCalendar()];
  const named = CalendarApp.getCalendarsByName(BUSINESS_CALENDAR_NAME);
  for (const c of named) calendars.push(c);

  const now = new Date();
  const from = new Date(now.getTime() - 2 * 86400000);    // 2 days back
  // A full year forward: Paul pencils next visits up to a year ahead (banana
  // color). They sync as tentative so the app can plan around them, the
  // capacity watcher counts them, and clients never see them.
  const to = new Date(now.getTime() + 366 * 86400000);
  const rows = [];
  const seen = {};
  for (const cal of calendars) {
    const events = cal.getEvents(from, to);
    for (const e of events) {
      if (e.isAllDayEvent()) continue;
      const key = e.getId() + '|' + e.getStartTime().toISOString();
      if (seen[key]) continue;  // same event visible via both calendars
      seen[key] = true;
      const title = (e.getTitle() || '').trim();
      if (!title || /^reserve\b/i.test(title) || /^(block|busy|hold|lunch|off)\b/i.test(title)) continue;
      const name = title.split(':')[0].trim();
      if (!name) continue;
      const desc = e.getDescription() || '';
      const email = (desc.match(/Email:\s*([^\s\n]+@[^\s\n]+)/i) || [])[1] || null;
      const dogs = (title.match(/(\d+)\s*Dogs?\b/i) || desc.match(/Groom\s+(\d+)\s+Dog/i) || [])[1];
      const price = (desc.match(/Price:\s*\$?([\d.]+)/i) || [])[1];
      rows.push({
        external_id: key,
        starts: e.getStartTime().toISOString(),
        ends: e.getEndTime().toISOString(),
        client_name: name,
        client_email: email,
        dog_count: dogs ? parseInt(dogs, 10) : null,
        service_type: /nail/i.test(title) ? 'nails' : 'full_groom',
        amount_cents: price ? Math.round(parseFloat(price) * 100) : null,
        notes: e.getLocation() || null,
        tentative: e.getColor() === BANANA_COLOR
      });
    }
  }
  UrlFetchApp.fetch(INGEST_URL, {
    method: 'post',
    contentType: 'application/json',
    headers: { 'x-cfo-secret': SECRET },
    payload: JSON.stringify({ events: rows, from: from.toISOString(), to: to.toISOString() }),
    muteHttpExceptions: true
  });
}
