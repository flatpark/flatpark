// Upstream GitHub stars, the second "Popular" order next to install counts.
// Installs say how many people got the app here; stars say how well known the
// project is. The two disagree most for new listings, which have few installs
// yet, and for niche tools with a loyal FlatPark audience.
//
// Which repository counts:
//   catalog.stars_repo: owner/name  that repository (a third-party build's
//                                   source_url is its build repo, never upstream)
//   catalog.stars_repo: none        no stars (a closed app whose source_url is
//                                   someone else's packaging repo)
//   otherwise                       the github.com repo in source_url
// An extension (build.extends) never gets stars: its source_url is the parent
// project's repository, whose stars say nothing about the extension.

const REPO = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;

/** "owner/name" for an app, or '' when it has no stars to show. */
export function starsRepoOf(fy, sourceUrl) {
  if (fy?.build?.extends) return '';
  const declared = fy?.catalog?.stars_repo;
  if (declared !== undefined && declared !== null && declared !== '') {
    const v = String(declared).trim();
    if (v === 'none') return '';
    return REPO.test(v) ? v : '';
  }
  const m = /^https?:\/\/github\.com\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)/.exec(sourceUrl || '');
  return m ? `${m[1]}/${m[2].replace(/\.git$/, '')}` : '';
}

// One GraphQL request per 100 repositories: each aliased lookup costs next to
// nothing (the whole catalog is one rate-limit point), and 100 keeps a query
// well inside GitHub's node limits however far the catalog grows.
const BATCH = 100;

/**
 * Star counts for `repos` (owner/name strings), keyed by the lowercased
 * owner/name asked for. A repository GitHub cannot find is left out; a failed
 * request throws, and the caller decides what that means.
 */
export async function fetchStars(repos, token, { fetchImpl = fetch } = {}) {
  const unique = [...new Set(repos.map((r) => r.toLowerCase()))];
  const out = {};
  for (let i = 0; i < unique.length; i += BATCH) {
    const chunk = unique.slice(i, i + BATCH);
    const fields = chunk
      .map((r, n) => {
        const [owner, name] = r.split('/');
        return `r${n}: repository(owner: ${JSON.stringify(owner)}, name: ${JSON.stringify(name)}) { nameWithOwner stargazerCount }`;
      })
      .join('\n');
    const res = await fetchImpl('https://api.github.com/graphql', {
      method: 'POST',
      headers: {
        authorization: `bearer ${token}`,
        'content-type': 'application/json',
        'user-agent': 'flatpark-site-build',
      },
      body: JSON.stringify({ query: `query {\n${fields}\n}` }),
      signal: AbortSignal.timeout(30000),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const body = await res.json();
    // A missing repository comes back as a null field plus a NOT_FOUND error;
    // the rest of the batch is still good. Anything else with no data at all
    // (bad token, malformed query) fails the whole lookup.
    if (!body.data) throw new Error(body.errors?.[0]?.message || 'no data');
    chunk.forEach((r, n) => {
      const repo = body.data[`r${n}`];
      if (repo) out[r] = { repo: repo.nameWithOwner, count: repo.stargazerCount };
    });
  }
  return out;
}
