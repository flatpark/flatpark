#!/usr/bin/env node
// Flag apps whose resolver succeeded but picked an old release.
//
// A resolver that fails lands in the resolver-failure alert. One that matches
// too tightly fails differently: upstream renames its tag prefix or its Linux
// asset, the filter skips every new release, the newest release that still
// matches is the one already pinned, and update-pins reports "up to date"
// forever. Nothing goes red.
//
// This check doesn't use the resolver's filters. For every app whose resolved
// sources are GitHub release assets, it reads the tag the resolver picked out
// of the download URL (`/releases/download/<tag>/`) and asks GitHub which
// releases in that repository are newer. A newer release counts against the
// app when:
//   - it is not a draft, and not a prerelease unless the picked one is one,
//   - it has been out for more than GRACE_HOURS, default 3 (upstreams that
//     upload the Linux build, or the second arch, after publishing usually
//     finish within about two hours; a release with no Linux asset yet is
//     never counted, so this only has to cover a half-uploaded one),
//   - it carries an asset that looks like a Linux build (see linuxAsset), and
//   - its tag is not numbered lower than the picked one, and
//   - neither its tag nor its release name matches the app's
//     `update.stale_ignore` regex, which is how a monorepo says "the other
//     tags here are other products" and a channel repo says "Nightly".
// Apps whose sources are not on GitHub releases are not checked.
//
//   node scripts/check-stale.mjs <resolved.tsv> [--releases-file FILE]
//
// resolved.tsv holds `<id>\t<resolver json on one line>`, as check-updates.sh
// writes it with RESOLVED_OUT set. Prints one `<id>\t<picked>\t<newer,...>` per
// stale app and exits 0; exit 1 only when the check itself could not run.
// --releases-file replaces the GraphQL calls with a JSON file
// `{ "<owner>/<repo>": { "picked": {publishedAt,isPrerelease} | null,
//    "releases": [ {tagName,name,isDraft,isPrerelease,publishedAt,assets:[name]} ] } }`
// for the tests.
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const REGISTRY = process.env.FLATPARK_REGISTRY_DIR || join(ROOT, 'registry');
const GRACE_HOURS = Number(process.env.STALE_GRACE_HOURS || 3);
const RECENT = 15;      // newest releases looked at per repository
const BATCH = 25;       // repositories per GraphQL query

const args = process.argv.slice(2);
const resolvedFile = args.find((a) => !a.startsWith('--'));
const ri = args.indexOf('--releases-file');
const releasesFile = ri >= 0 ? args[ri + 1] : '';
if (!resolvedFile) { console.error('usage: check-stale.mjs <resolved.tsv> [--releases-file FILE]'); process.exit(1); }

// Linux-looking: names a Linux format or arch, and no other platform. Loose on
// purpose — a false hit costs one `stale_ignore` line, a miss costs releases.
const OTHER = /(win(dows|32|64)?[-_. ]|[-_.]win\b|mac(os)?|darwin|osx|android|ios\b|\.exe$|\.msi$|\.dmg$|\.pkg$|\.apk$|\.ipa$|\.(sig|asc|sha\d*|sha\d*sum|md5|blockmap|zsync|ya?ml|json|txt)$)/i;
const LINUX = /(linux|\.deb$|\.rpm$|\.appimage$|\.flatpak$|amd64|x86[_-]64|x64|aarch64|arm64)/i;
function linuxAsset(name) { return LINUX.test(name) && !OTHER.test(name); }

function unquote(v) {
  v = v.trim();
  const c = v[0];
  if ((c === '"' || c === "'") && v[v.length - 1] === c) return v.slice(1, -1);
  return v;
}

// update.stale_ignore from flatpark.yml, or ''.
function staleIgnore(id) {
  const f = join(REGISTRY, id, 'flatpark.yml');
  if (!existsSync(f)) return '';
  let section = '';
  for (const line of readFileSync(f, 'utf8').split('\n')) {
    const top = line.match(/^([A-Za-z_]+):/);
    if (top) { section = top[1]; continue; }
    const m = line.match(/^\s+stale_ignore:\s*(.+?)\s*$/);
    if (section === 'update' && m) return unquote(m[1]);
  }
  return '';
}

const GH = /^https:\/\/github\.com\/([^/]+)\/([^/]+)\/releases\/download\/([^/]+)\//;

const apps = [];
for (const line of readFileSync(resolvedFile, 'utf8').split('\n')) {
  if (!line.trim()) continue;
  const tab = line.indexOf('\t');
  const id = line.slice(0, tab);
  let r;
  try { r = JSON.parse(line.slice(tab + 1)); } catch { continue; }
  const m = (r.sources || []).map((s) => GH.exec(s.url || '')).find(Boolean);
  if (!m) continue;
  apps.push({ id, repo: `${m[1]}/${m[2]}`, tag: decodeURIComponent(m[3]), ignore: staleIgnore(id) });
}

async function graphql(query) {
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
  if (!token) throw new Error('GITHUB_TOKEN is not set');
  // GitHub's GraphQL endpoint now and then answers a big batch with a 5xx or
  // a truncated body ("Unexpected end of JSON input"); retry before giving up.
  let j;
  for (let attempt = 1; ; attempt++) {
    try {
      const res = await fetch('https://api.github.com/graphql', {
        method: 'POST',
        headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({ query }),
      });
      if (!res.ok) throw new Error(`GraphQL HTTP ${res.status}`);
      j = JSON.parse(await res.text());
      break;
    } catch (e) {
      if (attempt >= 3) throw e;
      await new Promise((r) => setTimeout(r, 2000 * attempt));
    }
  }
  // A renamed or deleted repository comes back as a per-alias error with the
  // rest of the batch intact; that app is just not checked.
  return j.data || {};
}

async function lookup(batch) {
  if (releasesFile) {
    const all = JSON.parse(readFileSync(releasesFile, 'utf8'));
    return batch.map((a) => all[a.repo] || null);
  }
  const q = batch.map((a, i) => {
    const [owner, name] = a.repo.split('/');
    return `r${i}: repository(owner: ${JSON.stringify(owner)}, name: ${JSON.stringify(name)}) {
      picked: release(tagName: ${JSON.stringify(a.tag)}) { publishedAt isPrerelease }
      releases(first: ${RECENT}, orderBy: {field: CREATED_AT, direction: DESC}) {
        nodes { tagName name isDraft isPrerelease publishedAt releaseAssets(first: 100) { nodes { name } } }
      }
    }`;
  }).join('\n');
  const data = await graphql(`query {\n${q}\n}`);
  return batch.map((_, i) => {
    const r = data[`r${i}`];
    if (!r) return null;
    return {
      picked: r.picked,
      releases: r.releases.nodes.map((n) => ({ ...n, assets: n.releaseAssets.nodes.map((x) => x.name) })),
    };
  });
}

// The numbers in a tag, for "is this a lower version": v1.7.0 -> [1,7,0].
function nums(tag) { return (tag.match(/[0-9]+/g) || []).map(Number); }
function lower(a, b) {
  const x = nums(a), y = nums(b);
  if (!x.length || !y.length) return false;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    const d = (x[i] ?? 0) - (y[i] ?? 0);
    if (d) return d < 0;
  }
  return false;
}

function newerReleases(app, info, now = Date.now()) {
  // No release under the picked tag (the URL points at another repository's
  // asset, or upstream deleted it): nothing to compare against, so no verdict.
  const picked = info && info.picked;
  if (!picked || !picked.publishedAt) return [];
  const ignore = app.ignore ? new RegExp(app.ignore) : null;
  const cutoff = now - GRACE_HOURS * 3600e3;
  return info.releases.filter((r) =>
    r.tagName !== app.tag && !r.isDraft && r.publishedAt &&
    (!r.isPrerelease || picked.isPrerelease) &&
    r.publishedAt > picked.publishedAt &&
    Date.parse(r.publishedAt) < cutoff &&
    r.assets.some(linuxAsset) &&
    // Published later but numbered lower: a backport or a re-cut of an older
    // line (valhalla re-published v1.7.0 after v1.7.1), not something missed.
    !lower(r.tagName, app.tag) &&
    !(ignore && (ignore.test(r.tagName) || ignore.test(r.name || '')))
  ).map((r) => r.tagName);
}

try {
  for (let i = 0; i < apps.length; i += BATCH) {
    const batch = apps.slice(i, i + BATCH);
    const infos = await lookup(batch);
    batch.forEach((a, k) => {
      const newer = newerReleases(a, infos[k]);
      if (newer.length) process.stdout.write(`${a.id}\t${a.tag}\t${newer.join(',')}\n`);
    });
  }
} catch (e) {
  console.error(`check-stale: ${e.message}`);
  process.exit(1);
}
