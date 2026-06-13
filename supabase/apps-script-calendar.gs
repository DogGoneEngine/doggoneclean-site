/**
 * Dog Gone Clean - Google Calendar <-> app sync, both directions.
 *
 * Runs inside Paul's own Google account (no service-account key, which Google
 * blocks by default on new projects). One 15-minute trigger on syncCalendar()
 * does two things:
 *
 *  1. INBOUND (calendar -> app): reads his primary calendar AND, if it exists,
 *     a calendar named "Dog Gone Clean", and pushes events to the
 *     calendar-ingest edge function, which matches each to an existing client
 *     and mirrors it into bath_appointments. This is how appointments Paul
 *     books on his calendar reach the app. Events the mirror itself wrote
 *     (carrying the dgc_appt_id tag or the [dgc-mirror] marker) are skipped so
 *     the calendar -> app -> calendar loop never closes; a new appointment Paul
 *     types straight into the Dog Gone Clean calendar has neither and still
 *     flows in, so the parallel-booking cutover path survives.
 *
 *  2. OUTBOUND (app -> calendar): pulls the app's current appointments from the
 *     calendar-export edge function and reconciles them into the Dog Gone Clean
 *     calendar (creating, updating, and deleting events to match). This is the
 *     mirror Paul watches in parallel with his old system before the cutover:
 *     every appointment the app knows about appears on a calendar next to his
 *     existing one. The mirror owns only the events it tags; anything Paul adds
 *     by hand is left alone.
 *
 * The final flip (calendar_flip_order) then just drops the default calendar
 * from the inbound list and moves any stragglers. Set a time-driven trigger on
 * syncCalendar() to run every 15 minutes.
 */

const INGEST_URL = 'https://urebdrosrxejhubpbxsa.supabase.co/functions/v1/calendar-ingest';
const EXPORT_URL = 'https://urebdrosrxejhubpbxsa.supabase.co/functions/v1/calendar-export';
const SECRET = 'd382120e23ba4ecfb70f4ba1f947ccd4a87fb1b7ee5c40388650c5c83ead870e';
const BUSINESS_CALENDAR_NAME = 'Dog Gone Clean';
// Banana is Paul's private pencil color: year-ahead placeholders the client
// has never been told about. They sync as tentative, never as confirmed.
const BANANA_COLOR = '5';
// Tag key and description marker the mirror stamps on every event it writes,
// so the inbound read can recognize and skip its own output.
const MIRROR_TAG = 'dgc_appt_id';
const MIRROR_MARKER = '[dgc-mirror]';

function syncCalendar() {
  const now = new Date();
  const from = new Date(now.getTime() - 2 * 86400000);    // 2 days back
  // A full year forward: Paul pencils next visits up to a year ahead (banana
  // color). They sync as tentative so the app can plan around them, the
  // capacity watcher counts them, and clients never see them.
  const to = new Date(now.getTime() + 366 * 86400000);

  importFromCalendars_(from, to);
  exportToBusinessCalendar_(from, to);
}

// 1. INBOUND: calendar -> app.
function importFromCalendars_(from, to) {
  const calendars = [CalendarApp.getDefaultCalendar()];
  const named = CalendarApp.getCalendarsByName(BUSINESS_CALENDAR_NAME);
  for (const c of named) calendars.push(c);

  const rows = [];
  const seen = {};
  for (const cal of calendars) {
    const events = cal.getEvents(from, to);
    for (const e of events) {
      if (e.isAllDayEvent()) continue;
      // Skip the mirror's own events so the app never re-ingests what it wrote.
      if (e.getTag(MIRROR_TAG)) continue;
      if ((e.getDescription() || '').indexOf(MIRROR_MARKER) !== -1) continue;
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

// 2. OUTBOUND: app -> Dog Gone Clean calendar.
function exportToBusinessCalendar_(from, to) {
  const named = CalendarApp.getCalendarsByName(BUSINESS_CALENDAR_NAME);
  if (!named.length) {
    Logger.log('No "%s" calendar found; skipping export.', BUSINESS_CALENDAR_NAME);
    return;
  }
  const cal = named[0];

  const res = UrlFetchApp.fetch(EXPORT_URL, {
    method: 'post',
    contentType: 'application/json',
    headers: { 'x-cfo-secret': SECRET },
    payload: JSON.stringify({ from: from.toISOString(), to: to.toISOString() }),
    muteHttpExceptions: true
  });
  if (res.getResponseCode() !== 200) {
    Logger.log('calendar-export %s: %s', res.getResponseCode(), res.getContentText());
    return;
  }
  const wanted = (JSON.parse(res.getContentText()).events) || [];

  // Index the events the mirror already owns (tagged), so we update in place
  // and delete only our own leftovers, never anything Paul added by hand.
  const owned = {};
  for (const e of cal.getEvents(from, to)) {
    const id = e.getTag(MIRROR_TAG);
    if (id) owned[id] = e;
  }

  for (const w of wanted) {
    try {
      const start = new Date(w.start);
      const end = new Date(w.end);
      const existing = owned[w.appt_id];
      if (existing) {
        if (existing.getTitle() !== w.title) existing.setTitle(w.title);
        if (existing.getStartTime().getTime() !== start.getTime() ||
            existing.getEndTime().getTime() !== end.getTime()) {
          existing.setTime(start, end);
        }
        if (existing.getDescription() !== w.description) existing.setDescription(w.description);
        if ((existing.getLocation() || '') !== (w.location || '')) existing.setLocation(w.location || '');
        delete owned[w.appt_id];
      } else {
        const ev = cal.createEvent(w.title, start, end, {
          description: w.description,
          location: w.location || ''
        });
        ev.setTag(MIRROR_TAG, w.appt_id);
      }
    } catch (err) {
      Logger.log('export row %s failed: %s', w.appt_id, err);
    }
  }

  // Anything still owned was removed/cancelled in the app: drop it.
  for (const id in owned) {
    try { owned[id].deleteEvent(); } catch (err) { Logger.log('delete %s failed: %s', id, err); }
  }
}
