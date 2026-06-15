/**
 * Dog Gone Clean - Time is Money weekly backup producer (Laelaps is the system of record).
 *
 * The weekly sheet is generated FROM Laelaps, not copied from the master, so it always
 * reflects current work and grows on its own. The master sheet is retired after a one-time
 * seed of its history into Laelaps. Runs under Paul's Google identity (Google blocks
 * service-account keys on new projects). See time_is_money_weekly_backup in CLEAN_ORACLE.md.
 *
 * One-time setup, in order:
 *   1. Project Settings -> Script Properties: add CFO_CRON_SECRET with the value of
 *      app_secrets.cfo_cron_secret from the dgc-prod Supabase project.
 *   2. Run seedHistoryFromMaster ONCE. It reads the master and loads its full history into
 *      Laelaps. The log shows how many rows loaded (expect ~1231). Re-running is safe (it
 *      replaces the history, never doubles it).
 *   3. Run fileTimeIsMoneyBackup. Confirm the dated Sheet has all your rows and 12 columns.
 *   4. Run installWeeklyTrigger to schedule it every Sunday morning.
 *   5. (Optional) Deploy -> New deployment -> Web app (execute as you, access only you) to
 *      power the "Back up now" button in Laelaps Reports.
 */

const MASTER_ID = '1rxZ6WDOp2xJsb4dK4vBRFDqx2LQQiP3SAdjpwzdyDbU';
const FOLDER_ID = '115Q5cKvgZ0ic5RhPelzUbVK_o5gMUsWZ';
const EDGE_URL = 'https://urebdrosrxejhubpbxsa.supabase.co/functions/v1/time-is-money-backup';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVyZWJkcm9zcnhlamh1YnBieHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2NTE5NDMsImV4cCI6MjA5NTIyNzk0M30.CoxYUJ3GLQbLKtcvHMovYoXb76XFx8CGrnP6Sg3q94c';

function _headers_() {
  const secret = PropertiesService.getScriptProperties().getProperty('CFO_CRON_SECRET');
  if (!secret) throw new Error('Set the CFO_CRON_SECRET script property first.');
  return { 'x-cfo-secret': secret, 'apikey': SUPABASE_ANON, 'Authorization': 'Bearer ' + SUPABASE_ANON };
}

// The MAIN tab is the one with the real history (the largest sheet, never the practice tab).
function _mainTab_(ss) {
  return ss.getSheets().reduce(function (a, b) { return b.getLastRow() > a.getLastRow() ? b : a; });
}

// Normalize a master date string to ISO yyyy-mm-dd (also fixes a stray colon typo like 12:27/23).
function _iso_(s) {
  s = String(s || '').trim().replace(/:/g, '/');
  const m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$/);
  if (!m) return null;
  let yr = +m[3]; if (yr < 100) yr += 2000;
  return yr + '-' + ('0' + (+m[1])).slice(-2) + '-' + ('0' + (+m[2])).slice(-2);
}

// STEP 2: one-time seed of the master's history into Laelaps.
function seedHistoryFromMaster() {
  const sh = _mainTab_(SpreadsheetApp.openById(MASTER_ID));
  const data = sh.getDataRange().getDisplayValues();
  const rows = [];
  for (let i = 1; i < data.length; i++) {
    const r = data[i];
    const iso = _iso_(r[0]);
    if (!iso) continue;                       // skip blank/unparseable rows
    const p = iso.split('-');
    const cleanDate = (+p[1]) + '/' + (+p[2]) + '/' + p[0];   // M/D/YYYY, no leading zeros
    const out = [cleanDate];
    for (let c = 1; c < 12; c++) out.push(String(r[c] == null ? '' : r[c]).trim());
    out.push(iso);
    rows.push(out);
  }
  const res = UrlFetchApp.fetch(EDGE_URL, {
    method: 'post', contentType: 'application/json', headers: _headers_(),
    payload: JSON.stringify({ action: 'load_history', rows: rows }), muteHttpExceptions: true,
  });
  if (res.getResponseCode() !== 200) throw new Error('Seed failed: ' + res.getResponseCode() + ' ' + res.getContentText());
  Logger.log('Sent ' + rows.length + ' rows. Server loaded: ' + res.getContentText());
}

// STEP 3 / weekly / button: build the dated backup from the Laelaps ledger.
// stamped=false (weekly) -> one file per day, replacing the same day's file.
// stamped=true (manual button / editor run) -> a distinct date+time file every push.
function fileTimeIsMoneyBackup(stamped) {
  const useStamp = stamped !== false;
  const res = UrlFetchApp.fetch(EDGE_URL, { method: 'get', headers: _headers_(), muteHttpExceptions: true });
  if (res.getResponseCode() !== 200) throw new Error('Ledger fetch failed: ' + res.getResponseCode() + ' ' + res.getContentText());
  const values = Utilities.parseCsv(res.getContentText());
  if (!values || values.length < 2) throw new Error('Ledger came back empty. Run seedHistoryFromMaster first.');
  const rows = values.length, cols = values[0].length;

  const tz = 'America/New_York';
  const day = Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd');
  const name = 'Time is Money - full backup - ' + day + (useStamp ? ' ' + Utilities.formatDate(new Date(), tz, 'h:mm a') : '');
  const folder = DriveApp.getFolderById(FOLDER_ID);
  if (!useStamp) {
    const dups = folder.getFilesByName(name);
    while (dups.hasNext()) dups.next().setTrashed(true);
  }

  const backup = SpreadsheetApp.create(name, rows, cols);
  const sheet = backup.getSheets()[0];
  sheet.getRange(1, 1, rows, cols).setValues(values);
  sheet.setFrozenRows(1);
  DriveApp.getFileById(backup.getId()).moveTo(folder);

  _postCard_(name, backup.getUrl(), rows - 1, 'https://drive.google.com/drive/folders/' + FOLDER_ID);
  Logger.log('Filed ' + name + ' (' + (rows - 1) + ' rows) -> ' + backup.getUrl());
  return backup.getUrl();
}

function _postCard_(name, fileUrl, dataRows, folderUrl) {
  try {
    UrlFetchApp.fetch(EDGE_URL, {
      method: 'post', contentType: 'application/json', headers: _headers_(),
      payload: JSON.stringify({ file_name: name, file_url: fileUrl, rows: dataRows, folder_url: folderUrl }),
      muteHttpExceptions: true,
    });
  } catch (e) { Logger.log('Card post failed (backup still filed): ' + e); }
}

// Web-app entry point for the Reports "Back up now" button (deploy as web app, execute as
// you, access only you), then store the /exec URL in app_secrets.time_is_money_webapp_url.
function doGet() {
  try {
    const url = fileTimeIsMoneyBackup(true);   // manual push: distinct time-stamped file
    return HtmlService.createHtmlOutput('<p>Backup filed. <a href="' + url + '" target="_blank">Open it</a>. You can close this tab.</p>');
  } catch (e) {
    return HtmlService.createHtmlOutput('<p>Backup failed: ' + e + '</p>');
  }
}

function weeklyTrigger() { fileTimeIsMoneyBackup(false); }   // weekly: one clean file per Sunday

function installWeeklyTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'weeklyTrigger') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('weeklyTrigger').timeBased().onWeekDay(ScriptApp.WeekDay.SUNDAY).atHour(7).create();
  Logger.log('Weekly trigger installed: Sundays ~7am Eastern.');
}
