#!/usr/bin/env node
// Apply an update resolver's output to an app: refresh the manifest's
// "MANAGED EXTRA-DATA" pins and the metainfo <releases>.
//
//   <resolver JSON on stdin> | update-pins.mjs <manifest> [metainfo]
//
// Resolver JSON: { version, releaseDate, sources: [ { filename, url, arch?, size?, sha256? } ],
//                  releaseUrl?, releaseNotes?, upstreamMetainfo?, distributionDescription? }
// upstreamMetainfo opts in to summary/description/branding/screenshots and news
// from the exact packaged version. Other registry fields stay distributor-owned.
// distributionDescription optionally appends persistent distributor prose.
//
// `arch` scopes a source to one architecture (it becomes the pin's only-arches).
// An app published for several arches gives each payload the same filename and
// an arch, so apply_extra unpacks one name whichever arch it runs on. Without
// `arch` a source keeps the only-arches it already has (x86_64 when it is new).
//
// releaseUrl and releaseNotes are optional per-app opt-ins. releaseUrl becomes
// the release's <url type="details">, i.e. a link to upstream's own notes.
// releaseNotes is an AppStream <description> body (<p>/<ul>/<li>/...) written
// through VERBATIM — FlatPark never reformats or trims upstream's prose. An app
// wires it up in its own resolver or leaves it out; without it the release gets
// an empty <description></description> for a human to fill in later, which is
// also what Flathub's external-data-checker writes.
//
// `size` is an optional per-source opt-in for upstreams that re-upload a build
// under the same versioned URL: the resolver reports the payload's current
// Content-Length (a cheap HEAD), and a source whose size or URL no longer
// matches its pin is re-pinned even though the version did not move. No
// <release> is added for such a re-pin — it is the same version.
//
// `sha256` is the stronger form of the same opt-in, for upstreams that publish
// a digest: a re-cut can keep the exact byte count, which `size` alone misses.
// A source whose reported sha256 differs from its pin is re-pinned. With both
// sha256 and size reported the pin is taken as is, with no download; with only
// sha256 the payload is downloaded and must hash to it.
//
// GitHub release assets need no resolver opt-in: their sha256 (`digest`) and
// size are in the releases API, so a source whose URL is a release asset
// (…/releases/download/<tag>/<name>, where a tag may hold a slash, or
// …/releases/latest/download/<name>) is
// looked up there, one call per release, with GITHUB_TOKEN when set. That is
// both the drift signal (flatpark#977: v2026.44 of Open CAD Studio was replaced
// under its tag with the same size) and the pin itself, so a GitHub-hosted
// payload is never downloaded here. An asset without a digest (uploaded before
// GitHub computed them) or a failed lookup falls back to the behaviour above.
//
// The comparison anchor is the VERSION: the latest <release version="..."> in
// the metainfo is "what we have". If the resolver's version equals it and no
// source reports drift, nothing changed (exit 10, no download). On a new
// version we download every source, recompute the extra-data sha256/size
// FlatPark-side, rewrite the MANAGED block, and prepend a <release> to the
// metainfo. With no version anchor (resolver
// emits no version), we fall back to per-source URL comparison.
//
// Exit 0  = changed (manifest and/or metainfo rewritten); prints the version.
// Exit 10 = nothing changed.
// Exit 1  = error.
import { readFileSync, writeFileSync, existsSync, createReadStream, mkdtempSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const BEGIN = '# BEGIN MANAGED EXTRA-DATA';
const END = '# END MANAGED EXTRA-DATA';
const die = (m) => { process.stderr.write(`update-pins: ${m}\n`); process.exit(1); };

const manifestPath = process.argv[2];
const metainfoPath = process.argv[3];
if (!manifestPath) die('usage: update-pins.mjs <manifest> [metainfo]');

let resolver;
try { resolver = JSON.parse(readFileSync(0, 'utf8')); }
catch (e) { die(`bad resolver JSON: ${e.message}`); }
if (!resolver || !Array.isArray(resolver.sources)) die('resolver JSON missing sources[]');

const text = readFileSync(manifestPath, 'utf8');
const lines = text.split('\n');
const bi = lines.findIndex((l) => l.includes(BEGIN));
const ei = lines.findIndex((l) => l.includes(END));
if (bi < 0 || ei < 0 || ei < bi) die('manifest has no MANAGED EXTRA-DATA block');
const baseIndent = (lines[bi].match(/^(\s*)/)[1]) || '      ';
const oldBlock = lines.slice(bi + 1, ei);

// Parse the current block into { filename, url, sha256, size, arches } records.
const current = [];
let cur = null;
for (const l of oldBlock) {
  const t = l.trim();
  if (t === '- type: extra-data') { cur = { arches: [] }; current.push(cur); continue; }
  if (!cur) continue;
  let m;
  if ((m = t.match(/^filename:\s*(.+)$/))) cur.filename = m[1].trim();
  else if ((m = t.match(/^url:\s*(.+)$/))) cur.url = m[1].trim();
  else if ((m = t.match(/^sha256:\s*(.+)$/))) cur.sha256 = m[1].trim();
  else if ((m = t.match(/^size:\s*(.+)$/))) cur.size = m[1].trim();
  else if ((m = t.match(/^-\s*(\S+)$/)) && !/:/.test(t)) cur.arches.push(m[1].trim());
}

const metainfo = metainfoPath && existsSync(metainfoPath) ? readFileSync(metainfoPath, 'utf8') : null;
const firstReleaseVersion = (xml) => {
  const m = xml && xml.match(/<release\b[^>]*\bversion="([^"]*)"/);
  return m ? m[1] : '';
};
const knownVersion = firstReleaseVersion(metainfo);

async function pin(url) {
  const hash = createHash('sha256');
  let size = 0;
  if (url.startsWith('file://')) {
    await new Promise((res, rej) => {
      const s = createReadStream(fileURLToPath(url));
      s.on('data', (c) => { hash.update(c); size += c.length; });
      s.on('end', res); s.on('error', rej);
    });
  } else {
    const r = await fetch(url, { redirect: 'follow' });
    if (!r.ok) throw new Error(`HTTP ${r.status} for ${url}`);
    for await (const chunk of r.body) { hash.update(chunk); size += chunk.length; }
  }
  return { sha256: hash.digest('hex'), size: String(size) };
}

const fields = `${baseIndent}  `;
const archItem = `${baseIndent}    `;
const out = [];
// The pin a resolver source refreshes: same filename and, when the source names
// an arch, the record scoped to it. A filename shared across arches with no arch
// to tell them apart is ambiguous, and guessing would cross-pin the payloads.
function previous(src) {
  const named = current.filter((c) => c.filename === src.filename);
  if (src.arch) return named.find((c) => c.arches.includes(src.arch));
  if (named.length > 1) die(`${src.filename} is pinned for several arches; the resolver must give each source an arch`);
  return named[0];
}

const GH_API = (process.env.FLATPARK_GITHUB_API || 'https://api.github.com').replace(/\/$/, '');
const GH_ASSET = /^https:\/\/github\.com\/([^/]+)\/([^/]+)\/releases\/(?:download\/(.+)|latest\/download)\/([^/?#]+)$/;
const ghReleases = new Map();
async function ghAsset(url) {
  const m = url.match(GH_ASSET);
  if (!m) return null;
  const [, owner, repo, tag, name] = m;
  const api = `${GH_API}/repos/${owner}/${repo}/releases/${tag ? `tags/${encodeURIComponent(decodeURIComponent(tag))}` : 'latest'}`;
  if (!ghReleases.has(api)) {
    const headers = { accept: 'application/vnd.github+json' };
    if (process.env.GITHUB_TOKEN) headers.authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
    ghReleases.set(api, fetch(api, { headers })
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .catch((e) => { process.stderr.write(`update-pins: ${api}: ${e.message}, no digest\n`); return null; }));
  }
  const rel = await ghReleases.get(api);
  const a = rel?.assets?.find((x) => x.name === decodeURIComponent(name));
  const sha = /^sha256:[0-9a-f]{64}$/.test(a?.digest || '') ? a.digest.slice(7) : null;
  return sha && a.size ? { sha256: sha, size: String(a.size) } : null;
}

// What upstream says the payload is now: the resolver's own size/sha256, else
// the GitHub asset metadata. Either field may be null.
const reportedSha = (src) => (src.sha256 == null ? null : String(src.sha256).replace(/^sha256:/, '').toLowerCase());
async function published(src) {
  const sha256 = reportedSha(src);
  const gh = sha256 ? null : await ghAsset(src.url);
  return { sha256: sha256 ?? gh?.sha256 ?? null, size: src.size != null ? String(src.size) : gh?.size ?? null };
}

// A source with a published size or sha256 has drifted when that value (or its
// URL) no longer matches the pin: upstream replaced the bytes in place.
function drifted(src) {
  const pub = src.published;
  if (pub.size == null && pub.sha256 == null) return false;
  const prev = previous(src);
  if (!prev || prev.url !== src.url) return true;
  return (pub.size != null && prev.size !== pub.size) || (pub.sha256 != null && prev.sha256 !== pub.sha256);
}

for (const src of resolver.sources) {
  if (!src.filename || !src.url) die('each source needs filename + url');
  src.published = await published(src);
}

// Version gate: cheap short-circuit when upstream hasn't moved (no downloads).
const sameVersion = !!resolver.version && !!knownVersion && resolver.version === knownVersion;
if (sameVersion && !resolver.sources.some(drifted) && !resolver.upstreamMetainfo) process.exit(10);

// A version present here means a real bump (or no anchor yet) -> re-pin fresh.
// Otherwise (no version, or same version with drift) only moved sources are
// fetched: a changed URL, or a size that no longer matches the pin.
const versionBump = !!resolver.version && !sameVersion;

for (const src of resolver.sources) {
  const prev = previous(src);
  const pub = src.published;
  const arches = src.arch ? [src.arch] : prev && prev.arches.length ? prev.arches : ['x86_64'];
  let sha256, size;
  if (!versionBump && prev && prev.url === src.url && prev.sha256 && prev.size && !drifted(src)) {
    ({ sha256, size } = prev); // URL and size unchanged, no version bump -> keep the pin
  } else if (pub.sha256 && pub.size) {
    ({ sha256, size } = pub); // upstream publishes both -> pin without downloading
  } else {
    try { ({ sha256, size } = await pin(src.url)); }
    catch (e) { die(e.message); }
    if (pub.sha256 && pub.sha256 !== sha256) die(`${src.url}: downloaded sha256 ${sha256} != published ${pub.sha256}`);
  }
  out.push(`${baseIndent}- type: extra-data`);
  out.push(`${fields}filename: ${src.filename}`);
  out.push(`${fields}only-arches:`);
  for (const a of arches) out.push(`${archItem}- ${a}`);
  out.push(`${fields}url: ${src.url}`);
  out.push(`${fields}sha256: ${sha256}`);
  out.push(`${fields}size: ${size}`);
}

const manifestChanged = out.join('\n') !== oldBlock.join('\n');

const escAttr = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
const escText = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

// Re-indent a verbatim XML fragment under `pad`, keeping its own relative
// nesting (a <li> stays indented under its <ul>) but discarding whatever base
// indentation upstream happened to emit it with.
function reindent(fragment, pad) {
  const src = fragment.replace(/\r/g, '').split('\n').filter((l) => l.trim());
  const base = Math.min(...src.map((l) => l.match(/^ */)[0].length));
  return src.map((l) => pad + l.slice(base)).join('\n');
}

// Build the <release> element. `withNotes` says whether upstream's prose passed
// the guard below; when it did not, the element still carries the version, the
// date and the details link, so bad notes can never hold up an update.
function releaseElement(withNotes) {
  const I = '    ';
  const date = resolver.releaseDate ? ` date="${escAttr(resolver.releaseDate)}"` : '';
  const el = [`${I}<release version="${escAttr(resolver.version)}"${date}>`];
  if (resolver.releaseUrl) el.push(`${I}  <url type="details">${escText(resolver.releaseUrl)}</url>`);
  if (withNotes && String(resolver.releaseNotes || '').trim()) {
    el.push(`${I}  <description>`);
    el.push(reindent(resolver.releaseNotes, `${I}    `));
    el.push(`${I}  </description>`);
  } else {
    // An empty element, not a self-closing one: it reads as a slot someone can
    // still fill in by hand rather than as a field that does not exist.
    el.push(`${I}  <description></description>`);
  }
  el.push(`${I}</release>`);
  return el.join('\n');
}

const insertRelease = (rel) => {
  if (/<releases\b[^>]*>/.test(metainfo)) {
    return metainfo.replace(/(<releases\b[^>]*>)/, `$1\n${rel}`);
  }
  if (metainfo.includes('</component>')) {
    return metainfo.replace('</component>', `  <releases>\n${rel}\n  </releases>\n</component>`);
  }
  return metainfo;
};

// Guard for the one part we do not control: upstream's notes. The fragment is
// validated inside a synthetic component that is otherwise clean, NOT inside
// the app's own metainfo — an app carrying an unrelated pre-existing warning
// must not silently switch this check off. Best-effort: appstreamcli is not a
// hard dependency of the update run, and a missing validator just means the
// notes go in unchecked, exactly as they did before this guard existed.
function notesAreValid(notes) {
  const probe = spawnSync('appstreamcli', ['--version'], { stdio: 'ignore' });
  if (probe.error || probe.status !== 0) return true;
  const dir = mkdtempSync(join(tmpdir(), 'flatpark-pins-'));
  try {
    const p = join(dir, 'org.flatpark.notesprobe.metainfo.xml');
    writeFileSync(p, [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<component type="desktop-application">',
      '  <id>org.flatpark.notesprobe</id>',
      '  <name>Notes Probe</name>',
      '  <summary>Probe used to validate a release description fragment</summary>',
      '  <metadata_license>CC0-1.0</metadata_license>',
      '  <project_license>MIT</project_license>',
      '  <description><p>Probe component whose only variable content is the release description fragment under test.</p></description>',
      '  <url type="homepage">https://flatpark.org</url>',
      '  <launchable type="desktop-id">org.flatpark.notesprobe.desktop</launchable>',
      '  <releases>',
      '    <release version="1.0" date="2026-01-01">',
      '      <description>',
      reindent(notes, '        '),
      '      </description>',
      '    </release>',
      '  </releases>',
      '</component>',
    ].join('\n'));
    return spawnSync('appstreamcli', ['validate', '--no-net', p], { stdio: 'ignore' }).status === 0;
  } catch {
    return false; // e.g. reindent choking on an empty fragment
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// Prepend a <release> to the metainfo when the version moved.
let metainfoChanged = false;
let newMetainfo = metainfo;
if (metainfo && resolver.version && resolver.version !== knownVersion) {
  const notes = String(resolver.releaseNotes || '').trim();
  const keepNotes = notes ? notesAreValid(notes) : false;
  if (notes && !keepNotes) {
    process.stderr.write('update-pins: releaseNotes failed AppStream validation, dropping them\n');
  }
  newMetainfo = insertRelease(releaseElement(keepNotes));
  metainfoChanged = newMetainfo !== metainfo;
}

// Import presentation only after resolving every pin, before writing either
// file. The exact-version/ID checks and final AppStream validation are mandatory
// for this opt-in; older resolver behavior is unchanged.
if (resolver.upstreamMetainfo) {
  if (!metainfo || !resolver.version) die('upstreamMetainfo requires local metainfo and a version');
  const helper = fileURLToPath(new URL('./sync-upstream-metainfo.py', import.meta.url));
  const merged = spawnSync('python3', [helper], {
    input: JSON.stringify({ local: newMetainfo, upstream: resolver.upstreamMetainfo,
      version: resolver.version, distributionDescription: resolver.distributionDescription || '' }),
    encoding: 'utf8', maxBuffer: 4 * 1024 * 1024,
  });
  if (merged.error || merged.status !== 0) die(merged.stderr || merged.error?.message || 'upstream metainfo import failed');
  const directory = mkdtempSync(join(tmpdir(), 'flatpark-metainfo-'));
  try {
    const path = join(directory, 'import.metainfo.xml');
    writeFileSync(path, merged.stdout);
    const validation = spawnSync('appstreamcli', ['validate', '--no-net', path], { encoding: 'utf8' });
    if (validation.error || validation.status !== 0) throw new Error(validation.stdout || validation.stderr || 'appstreamcli is required for upstreamMetainfo');
  } finally { rmSync(directory, { recursive: true, force: true }); }
  newMetainfo = merged.stdout;
  metainfoChanged = newMetainfo !== metainfo;
}

if (!manifestChanged && !metainfoChanged) process.exit(10);
if (manifestChanged) {
  writeFileSync(manifestPath, [...lines.slice(0, bi + 1), ...out, ...lines.slice(ei)].join('\n'));
}
if (metainfoChanged) writeFileSync(metainfoPath, newMetainfo);
process.stdout.write(`${resolver.version || ''}\n`);
