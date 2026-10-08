// Curated collections from config/collections.yml, resolved against the
// catalog at build time. Read here rather than baked in by enrich.mjs: a
// collection is a site-level grouping, not a fact about any one app, and the
// pages that use it already have the full app list in hand.
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import YAML from 'yaml';
import { defaultLang } from '../i18n/config.mjs';

const collectionsFile =
  process.env.FLATPARK_COLLECTIONS_FILE || join('..', 'config', 'collections.yml');

/** A config text field: a plain string, or a per-locale map falling back to English. */
export function localized(value, lang) {
  if (value == null) return '';
  if (typeof value !== 'object') return String(value);
  return value[lang] ?? value[defaultLang] ?? '';
}

function readConfig() {
  try {
    if (!existsSync(collectionsFile)) return [];
    const list = YAML.parse(readFileSync(collectionsFile, 'utf8'))?.collections ?? [];
    return Array.isArray(list) ? list : [];
  } catch (e) {
    console.warn(`[collections] parse failed: ${e.message}`);
    return [];
  }
}

let cache = null;

/**
 * Every collection with at least one listed app, members resolved to their app
 * objects in config order. Unknown ids are dropped with a warning, so a
 * de-listed app never leaves a dead card behind.
 */
export function loadCollections(apps) {
  if (cache) return cache;
  const byId = new Map(apps.map((a) => [a.id, a]));
  cache = readConfig()
    .filter((c) => c?.slug && c?.name)
    .map((c) => {
      const groups = (c.groups ?? [])
        .map((g) => ({
          title: g.title,
          apps: (g.apps ?? []).map(String).flatMap((id) => {
            const app = byId.get(id);
            if (!app) console.warn(`[collections] ${c.slug} names unknown app ${id}`);
            return app ? [app] : [];
          }),
        }))
        .filter((g) => g.apps.length > 0);
      return {
        slug: String(c.slug),
        name: String(c.name),
        summary: c.summary,
        carousel: c.carousel === true,
        upstream: c.upstream || null,
        upcoming: (c.upcoming ?? []).filter((u) => u?.name),
        groups,
        apps: groups.flatMap((g) => g.apps),
      };
    })
    .filter((c) => c.apps.length > 0);
  return cache;
}

/** The collections an app belongs to, for its detail page backlink. */
export function collectionsOf(apps, id) {
  return loadCollections(apps).filter((c) => c.apps.some((a) => a.id === id));
}

/** One `flatpak install` line for the whole collection. */
export function installAllCmd(collection, remoteName) {
  return `flatpak install ${remoteName} ${collection.apps.map((a) => a.id).join(' ')}`;
}
