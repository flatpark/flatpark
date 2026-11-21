// Atom feed of upstream releases of listed apps, newest first. See lib/feed.mjs.
import type { APIContext } from 'astro';
import { isExtension, loadApps, loadCatalog } from '../lib/data.mjs';
import { atomResponse, releaseEntries, renderAtom, siteOrigin } from '../lib/feed.mjs';

export function GET({ site }: APIContext) {
  const { repo } = loadCatalog();
  const origin = siteOrigin(repo, site?.href);
  return atomResponse(
    renderAtom({
      title: `${repo.title || 'FlatPark'}: app updates`,
      subtitle: 'New releases of the apps on FlatPark, from each app’s AppStream release list.',
      selfUrl: `${origin}/updates.xml`,
      altUrl: `${origin}/apps/`,
      origin,
      entries: releaseEntries(loadApps().filter((a) => !isExtension(a)), origin),
    }),
  );
}
