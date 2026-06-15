/**
 * Dog Gone Clean - Time is Money weekly backup producer.
 *
 * Files the ENTIRE visit history as a dated Google Sheet into the backups folder, then
 * posts a Today card with a link. Runs under Paul's Google identity, mirroring the
 * calendar-sync script, because Google blocks service-account keys on new projects.
 * The teeth live in the database (see time_is_money_weekly_backup in CLEAN_ORACLE.md);
 * this script is just the deterministic producer, no LLM in the loop.
 *
 * One-time setup:
 *   1. Project Settings -> Script Properties: add CFO_CRON_SECRET with the value of
 *      app_secrets.cfo_cron_secret from the dgc-prod Supabase project.
 *   2. Run fileTimeIsMoneyBackup once from the editor; authorize when Google prompts.
 *      Confirm the dated Sheet lands in the folder and a card shows on the Today screen.
 *   3. Run installWeeklyTrigger once to schedule it every Sunday morning.
 */

const EDGE_URL = 'https://urebdrosrxejhubpbxsa.supabase.co/functions/v1/time-is-money-backup';
// Publishable anon key (safe to embed): the Supabase functions gateway wants it present.
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyZWJkcm9zcnhlamh1YnBieHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2NTE5NDMsImV4cCI6MjA5NTIyNzk0M30.CoxYUJ3GLQbLKtcvHMovYoXb76XFx8CGrnP6Sg3q94c';
const FOLDER_ID = '115Q5cKvgZ0ic5RhPelzUbVK_o5gMUsWZ';

function _headers_() {
  const secret = PropertiesService.getScriptProperties().getProperty('CFO_CRON_SECRET');
  if (!secret) throw new Error('Set the CFO_CRON_SECRET script property first.');
  return { 'x-cfo-secret': secret, 'apikey': SUPABASE_ANON, 'Authorization': 'Bearer ' + SUPABASE_ANON };
}

function fileTimeIsMoneyBackup() {
  const headers = _headers_();

  const res = UrlFetchApp.fetch(EDGE_URL, { method: 'get', headers: headers, muteHttpExceptions: true });
  if (res.getResponseCode() !== 200) {
    throw new Error('Ledger fetch failed: ' + res.getResponseCode() + ' ' + res.getContentText());
  }
  const rows = Utilities.parseCsv(res.getContentText());
  if (!rows || rows.length < 2) throw new Error('Ledger came back empty.');

  const tz = 'America/New_York';
  const name = 'Time is Money - full backup - ' + Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
  const ss = SpreadsheetApp.create(name, rows.length, rows[0].length);
  const sheet = ss.getSheets()[0];
  sheet.getRange(1, 1, rows.length, rows[0].length).setValues(rows);
  sheet.setFrozenRows(1);

  // Move the new Sheet out of My Drive root and into the backups folder.
  DriveApp.getFileById(ss.getId()).moveTo(DriveApp.getFolderById(FOLDER_ID));

  const fileUrl = ss.getUrl();
  const folderUrl = 'https://drive.google.com/drive/folders/' + FOLDER_ID;
  UrlFetchApp.fetch(EDGE_URL, {
    method: 'post', contentType: 'application/json', headers: headers,
    payload: JSON.stringify({ file_name: name, file_url: fileUrl, rows: rows.length - 1, folder_url: folderUrl }),
    muteHttpExceptions: true,
  });
  Logger.log('Filed ' + name + ' -> ' + fileUrl);
  return fileUrl;
}

function weeklyTrigger() { fileTimeIsMoneyBackup(); }

function installWeeklyTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'weeklyTrigger') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('weeklyTrigger').timeBased().onWeekDay(ScriptApp.WeekDay.SUNDAY).atHour(7).create();
  Logger.log('Weekly trigger installed: Sundays ~7am Eastern.');
}
