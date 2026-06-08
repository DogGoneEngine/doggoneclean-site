import { defineConfig } from 'astro/config';
import react from '@astrojs/react';

// hurricanebath.com is the Dog Gone Clean v2.0 surface today. Legacy
// doggoneclean.us serves the Squarespace site until its own rebuild.
// `build.format: 'directory'` gives clean URLs: /privacy.astro builds
// to /privacy/index.html so Caddy serves it at /privacy (no .html).
//
// React integration powers the client portal island at /portal and
// (later) the booking flow island at /book.
export default defineConfig({
  site: 'https://hurricanebath.com',
  build: {
    format: 'directory',
  },
  // The /process page was renamed to /hurricane-bath; keep the old URL
  // alive so any existing link or bookmark still lands.
  redirects: {
    '/process': '/hurricane-bath',
  },
  integrations: [react()],
});
