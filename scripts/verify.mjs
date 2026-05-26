#!/usr/bin/env node
// scripts/verify.mjs - end-to-end verify gate for "done."
//
// The rule: a UI task is not done until this script returns green AND the screenshots
// in artifacts/ have been eyeballed. Run via `npm run verify`. Same script runs in CI.
//
// What it does, in order:
//   1. Build the site (astro build).
//   2. Start a static preview server on localhost.
//   3. Launch headless Chromium via Playwright.
//   4. For each page on the route list, at each viewport:
//        - navigate, wait for network idle.
//        - assert HTTP status 200.
//        - assert no console errors and no unhandled JS exceptions.
//        - assert no failed asset requests (any 4xx/5xx fails the run).
//        - screenshot to artifacts/<page>-<viewport>.png.
//   5. Report PASS or FAIL with exact line of evidence.
//
// No external network. The Playwright Chromium runs against localhost only, so the
// harness egress allowlist is irrelevant.

import { spawn } from "node:child_process";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import { chromium } from "playwright";

const REPO = resolve(import.meta.dirname, "..");
const ARTIFACTS = resolve(REPO, "artifacts");
const PORT = 4322; // avoid conflict with astro dev's 4321
const BASE = `http://localhost:${PORT}`;

// Routes to verify. Add a row here when a new page or critical flow lands.
const ROUTES = [
  { path: "/", name: "home" },
];

// Viewports. Pixel 8 Pro is Paul's primary device per device_profile.
const VIEWPORTS = [
  { name: "desktop", width: 1280, height: 800 },
  { name: "pixel8pro", width: 412, height: 915 },
];

const failures = [];

function fail(msg) {
  failures.push(msg);
  console.error(`  FAIL: ${msg}`);
}

async function buildSite() {
  console.log("[1/4] astro build");
  await run("npx", ["astro", "build"]);
}

let server;
async function startServer() {
  console.log(`[2/4] starting preview server on :${PORT}`);
  server = spawn("npx", ["astro", "preview", "--port", String(PORT), "--host", "127.0.0.1"], {
    cwd: REPO,
    stdio: ["ignore", "pipe", "pipe"],
  });
  // wait for the server to be reachable
  for (let i = 0; i < 50; i++) {
    try {
      const r = await fetch(BASE + "/");
      if (r.ok) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error("preview server did not come up");
}

async function stopServer() {
  if (server) {
    server.kill("SIGTERM");
    await new Promise((r) => setTimeout(r, 200));
  }
}

async function run(cmd, args) {
  return new Promise((res, rej) => {
    const p = spawn(cmd, args, { cwd: REPO, stdio: "inherit" });
    p.on("close", (code) => (code === 0 ? res() : rej(new Error(`${cmd} exited ${code}`))));
  });
}

async function verifyRoutes() {
  console.log("[3/4] launching headless chromium");
  let browser;
  try {
    browser = await chromium.launch();
  } catch (e) {
    if (String(e.message).includes("Executable doesn't exist")) {
      throw new Error(
        "Playwright Chromium is not installed in this environment. Run " +
          "`npx playwright install chromium` from a network that can reach " +
          "Playwright's CDN. The harness's egress allowlist blocks that CDN, so " +
          "this step must run in CI (GitHub Actions) or on a local machine."
      );
    }
    throw e;
  }
  try {
    for (const vp of VIEWPORTS) {
      const context = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
      const page = await context.newPage();

      const consoleErrors = [];
      const pageErrors = [];
      const failedRequests = [];
      page.on("console", (m) => {
        if (m.type() === "error") consoleErrors.push(m.text());
      });
      page.on("pageerror", (e) => pageErrors.push(String(e)));
      page.on("requestfailed", (r) => failedRequests.push(`${r.method()} ${r.url()} - ${r.failure()?.errorText}`));
      page.on("response", (r) => {
        if (r.status() >= 400) failedRequests.push(`${r.status()} ${r.request().method()} ${r.url()}`);
      });

      for (const route of ROUTES) {
        const url = BASE + route.path;
        console.log(`  visit ${url} @ ${vp.name}`);
        const resp = await page.goto(url, { waitUntil: "networkidle", timeout: 10_000 });
        if (!resp || resp.status() !== 200) {
          fail(`${route.path} returned ${resp?.status() ?? "no response"} at ${vp.name}`);
        }
        const shot = resolve(ARTIFACTS, `${route.name}-${vp.name}.png`);
        await page.screenshot({ path: shot, fullPage: true });
      }

      if (consoleErrors.length) fail(`${vp.name}: console errors: ${consoleErrors.join(" | ")}`);
      if (pageErrors.length) fail(`${vp.name}: JS exceptions: ${pageErrors.join(" | ")}`);
      if (failedRequests.length) fail(`${vp.name}: failed requests: ${failedRequests.join(" | ")}`);

      await context.close();
    }
  } finally {
    await browser.close();
  }
}

async function main() {
  if (existsSync(ARTIFACTS)) rmSync(ARTIFACTS, { recursive: true, force: true });
  mkdirSync(ARTIFACTS, { recursive: true });

  try {
    await buildSite();
    await startServer();
    await verifyRoutes();
  } catch (e) {
    fail(`verify run aborted: ${e.message}`);
  } finally {
    await stopServer();
  }

  console.log("[4/4] summary");
  if (failures.length) {
    console.error(`\nVERIFY FAIL (${failures.length} issue(s)):`);
    for (const f of failures) console.error(`  - ${f}`);
    process.exit(1);
  }
  console.log(`\nVERIFY PASS: ${ROUTES.length} route(s) x ${VIEWPORTS.length} viewport(s), screenshots in artifacts/`);
}

main();
