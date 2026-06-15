/**
 * Dog Gone Clean - Time is Money weekly backup producer.
 *
 * Makes a complete, frozen weekly snapshot of Paul's source-of-truth spreadsheet
 * "Time is Money!" (its MAIN tab, every row and column) into the backups folder,
 * then posts a Today card with a link. Runs under Paul's Google identity, mirroring
 * the calendar-sync script, because Google blocks service-account keys on new projects.
 *
 * This copies the master sheet DIRECTLY. It does not go through the app database,
 * so nothing can be dropped: what is on your main tab is what lands in the backup.
 * See time_is_money_weekly_backup in CLEAN_ORACLE.md.
 *
 * One-time setup:
 *   1. Project Settings -> Script Properties: add CFO_CRON_SECRET with the value of
 *      app_secrets.cfo_cron_secret from the dgc-prod Supabase project.
 *   2. Run fileTimeIsMoneyBackup once from the editor; authorize when Google prompts.
 *      Confirm the dated Sheet lands in the folder with all your rows and columns, and
 *      a card shows on the Today screen.
 *   3. Run installWeeklyTrigger once to schedule it every Sunday morning.
 */

// Paul's live source-of-truth spreadsheet "Time is Money!".
const MASTER_ID = '1rxZ6WDOp2xJsb4dK4vBRFDqx2LQQiP3SAdjpwzdyDbU';
const FOLDER_ID = '115Q5cKvgZ0ic5RhPelzUbVK_o5gMUsWZ';
// The Today card is posted through the app; these reach the same edge endpoint.
const EDGE_URL = 'https://urebdrosrxejhubpbxsa.supabase.co/functions/v1/time-is-money-backup';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyZWJkcm9zcnhlamh1YnBieHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2NTE5NDMsImV4cCI6MjA5NTIyNzk0M30.CoxYUJ3GLQbLKtcvHMovYoXb76XFx8CGrnP6Sg3q94c';

// The MAIN tab is the one with the real history. Pick the sheet with the most rows so
// the small practice tab is never the one we back up (Paul: never the practice tab).
function _mainTab_(ss) {
  return ss.getSheets().reduce(function (a, b) {
    return b.getLastRow() > a.getLastRow() ? b : a;
  });
}

function fileTimeIsMoneyBackup() {
  const master = SpreadsheetApp.openById(MASTER_ID);
  const main = _mainTab_(master);
  const rows = main.getLastRow();
  const cols = main.getLastColumn();
  if (rows < 2) throw new Error('Main tab looks empty (' + rows + ' rows).');

  // Frozen snapshot: copy exactly what the sheet displays (values, not formulas), so a
  // catastrophe backup can never recompute or break a cross-sheet reference.
  const values = main.getRange(1, 1, rows, cols).getDisplayValues();

  const tz = 'America/New_York';
  const name = 'Time is Money - full backup - ' + Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
  const folder = DriveApp.getFolderById(FOLDER_ID);
  // Idempotent: trash any earlier file with this exact name (e.g. a bad earlier run
  // the same day) so the folder never holds two same-named backups.
  const dups = folder.getFilesByName(name);
  while (dups.hasNext()) dups.next().setTrashed(true);

  const backup = SpreadsheetApp.create(name, rows, cols);
  const sheet = backup.getSheets()[0];
  sheet.getRange(1, 1, rows, cols).setValues(values);
  sheet.setFrozenRows(1);
  DriveApp.getFileById(backup.getId()).moveTo(folder);

  const fileUrl = backup.getUrl();
  const folderUrl = 'https://drive.google.com/drive/folders/' + FOLDER_ID;
  _postCard_(name, fileUrl, rows - 1, folderUrl);
  Logger.log('Filed ' + name + ' (' + (rows - 1) + ' rows, ' + cols + ' cols) -> ' + fileUrl);
  return fileUrl;
}

// Post the Today card via the app. Best-effort: a failed card never loses the backup.
function _postCard_(name, fileUrl, dataRows, folderUrl) {
  const secret = PropertiesService.getScriptProperties().getProperty('CFO_CRON_SECRET');
  if (!secret) { Logger.log('No CFO_CRON_SECRET set; skipped the Today card.'); return; }
  try {
    UrlFetchApp.fetch(EDGE_URL, {
      method: 'post', contentType: 'application/json',
      headers: { 'x-cfo-secret': secret, 'apikey': SUPABASE_ANON, 'Authorization': 'Bearer ' + SUPABASE_ANON },
      payload: JSON.stringify({ file_name: name, file_url: fileUrl, rows: dataRows, folder_url: folderUrl }),
      muteHttpExceptions: true,
    });
  } catch (e) {
    Logger.log('Card post failed (backup still filed): ' + e);
  }
}

// One-time fix for Saturday 2026-06-13 from the times and amounts logged in Laelaps.
// Corrects the three rows in place (matched by date + client), setting the time columns
// as times and Charged/Paid as numbers so the formula columns recompute correctly.
function fixSaturday() {
  const DATE = '6/13/2026';
  const fixes = [
    { client: 'Lisa Prater',    inbound: '12:06:40 PM', arrival: '12:28:48 PM', departure: '12:46:05 PM', charged: 30,  paid: 35  },
    { client: 'Nancy Franklin', inbound: '12:46:06 PM', arrival: '12:49:13 PM', departure: '12:58:59 PM', charged: 25,  paid: 25  },
    { client: 'Tonya Hunt',     inbound: '1:43:02 PM',  arrival: '2:15:57 PM',  departure: '4:41:13 PM',  charged: 100, paid: 200 },
  ];
  const sh = _mainTab_(SpreadsheetApp.openById(MASTER_ID));
  const data = sh.getDataRange().getDisplayValues();
  const report = [];
  fixes.forEach(function (fx) {
    let r = -1;
    for (let i = 1; i < data.length; i++) {
      if (String(data[i][0]).trim() === DATE && String(data[i][1]).trim() === fx.client) { r = i + 1; break; }
    }
    if (r < 0) { report.push('NOT FOUND, skipped: ' + fx.client); return; }
    sh.getRange(r, 3).setValue(fx.inbound);    // Inbound Time
    sh.getRange(r, 4).setValue(fx.arrival);    // Arrival Time
    sh.getRange(r, 5).setValue(fx.departure);  // Departure Time
    sh.getRange(r, 6).setValue(fx.charged);    // Charged
    sh.getRange(r, 7).setValue(fx.paid);       // Paid
    sh.getRange(r, 8).setValue('Cash');        // Payment Method
    report.push('fixed row ' + r + ': ' + fx.client);
  });
  Logger.log(report.join('\n'));
}

function weeklyTrigger() { fileTimeIsMoneyBackup(); }

function installWeeklyTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'weeklyTrigger') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('weeklyTrigger').timeBased().onWeekDay(ScriptApp.WeekDay.SUNDAY).atHour(7).create();
  Logger.log('Weekly trigger installed: Sundays ~7am Eastern.');
}
