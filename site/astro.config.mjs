// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';

// `site` is the canonical origin used for the sitemap and absolute URLs; it is
// overridable so the publish pipeline can pass REPO_HOMEPAGE, and defaults to
// the production host. `outDir` is likewise overridable so the publish pipeline
// (and tests) can target any location; defaults to the repo's shared out/site.
export default defineConfig({
  site: process.env.SITE_URL || 'https://flatpark.org',
  outDir: process.env.SITE_OUT_DIR || '../out/site',
  output: 'static',
  integrations: [sitemap()],
  vite: {
    plugins: [tailwindcss()],
  },
});
