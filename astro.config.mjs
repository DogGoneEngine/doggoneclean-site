import { defineConfig } from 'astro/config';

// hurricanebath.com is the Dog Gone Clean v2.0 surface today. Legacy
// doggoneclean.us serves the Squarespace site until its own rebuild.
// `build.format: 'directory'` gives clean URLs: /privacy.astro builds
// to /privacy/index.html so Caddy serves it at /privacy (no .html).
export default defineConfig({
  site: 'https://hurricanebath.com',
  build: {
    format: 'directory',
  },
});
