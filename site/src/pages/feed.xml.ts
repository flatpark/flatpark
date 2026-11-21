// Atom feed of newly listed apps, newest first. See lib/feed.mjs.
import type { APIContext } from 'astro';
import { isExtension, loadApps, loadCatalog } from '../lib/data.mjs';
import { atomResponse, newAppEntries, renderAtom, siteOrigin } from '../lib/feed.mjs';

export function GET({ site }: APIContext) {
  const { repo } = loadCatalog();
  const origin = siteOrigin(repo, site?.href);
  return atomResponse(
    renderAtom({
      title: `${repo.title || 'FlatPark'}: new apps`,
      subtitle: 'Apps newly listed on FlatPark, the signed Flatpak remote for vendor releases.',
      selfUrl: `${origin}/feed.xml`,
      altUrl: `${origin}/apps/`,
      origin,
      entries: newAppEntries(loadApps().filter((a) => !isExtension(a)), origin),
    }),
  );
}
