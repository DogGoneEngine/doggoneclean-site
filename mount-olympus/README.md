# Mount Olympus

The one doorway into every business. A single private page that opens into Dog
Gone Clean, Dog Gone Nails, and any project added later, plus the back-of-house
tools (Supabase, GitHub, deploys, Stripe, DNS) for each.

It is a plain static site on purpose: one HTML file, one stylesheet, one script,
and one config file. No build step, no framework, nothing to break in a redesign.

## Files

| File | What it is |
|---|---|
| `index.html` | the page |
| `styles.css` | the night-sky + gold styling |
| `app.js` | behavior: clock, command palette, health dots, scratchpad |
| `projects.js` | **the only file you edit day to day** (businesses + tools) |
| `manifest.webmanifest`, `icon-*.png`, `favicon.svg` | makes it installable on the Pixel home screen |
| `deploy/Caddyfile.snippet` | the droplet web-server block (with the gate options) |
| `deploy/deploy.yml.template` | a GitHub Actions deploy, for when this has its own repo |

## Add a project

Open `projects.js`, copy the commented template block at the bottom of
`OLYMPUS.buildings`, fill in the name, tagline, accent color, website, and door
links, and redeploy. The page rebuilds itself from that file. That is the whole
process.

## What it does today

- Doors into every business surface (site, booking, portal, operator, Orbit) and
  its engine room (Supabase, GitHub, deploys).
- Command palette: press `/` and type to jump to any door across all businesses.
- Best-effort "reachable" dot on each public site.
- Eastern-time clock and a local scratchpad (saved in the browser).
- Installable as an app on the Pixel.

## What is parked for Phase 2

Live tiles (today's appointment count, week count, run rate) per business. These
read each business's own Supabase with its own keys, so nothing merges. They are
parked because they need one decision (which numbers, and whether they sit behind
the page's basic auth or behind a per-business login) and because `dgn-prod` is
paused until Dog Gone Nails goes live. See the chore list in the build report.

## Privacy

The page is private and not crawlable: a `noindex` meta tag, an `X-Robots-Tag`
header, a `robots.txt` disallow, and (the real protection) an auth gate in front
so nothing renders to the public. Recommended gate is Google login via Cloudflare
Access, restricted to one email. See `deploy/Caddyfile.snippet`.

## Deploy (summary)

1. Put these files in `/srv/mountolympus` on the droplet.
2. Replace the `mountolympusops.com` Caddy block (currently proxying n8n) with
   `deploy/Caddyfile.snippet`, pick a gate (Google via Cloudflare Access, or a
   password), reload Caddy.
3. Stop the now-unused n8n container.

Full steps live in the build report.
