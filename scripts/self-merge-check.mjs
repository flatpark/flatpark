#!/usr/bin/env node
// Decide whether an upstream maintainer's `/merge` may merge a PR without a
// FlatPark maintainer's review. Used by .github/workflows/self-merge.yml.
//
//   self-merge-check.mjs <base-sha> <head-sha> <commenter-user-id>
//
// <base-sha> is the PR's merge-base with main; the diff base..head is exactly
// what the PR changes. The maintainer list and the "app already exists" test
// are read from the CHECKED-OUT tree (main), never from the PR, so a PR cannot
// grant itself rights.
//
// The self-merge surface ("option A"): regular files at the top level of
// registry/<id>/ of an app the commenter maintains, EXCEPT what runs as code in
// trusted CI or feeds the site unescaped:
//
//   - flatpark.yml, whole. Its `update:` section is `eval`d by check-updates.sh
//     in update-check.yml on a contents:write token; `build.manifest` picks the
//     recipe publish.yml builds; name/summary land in the site. Upstream rarely
//     needs to touch it, so it is simply frozen.
//   - resolve-update.sh — the same CI eval.
//   - the build recipe. Every *.yml/*.yaml/*.json in the app dir is a manifest
//     (or a module file), built in publish.yml next to the signing key and the
//     R2 credentials, and so is any file a manifest lists as a bare `- <file>`
//     module entry. A manifest may change only in `finish-args` and inside the
//     MANAGED EXTRA-DATA block, comments and blank lines aside; the block may
//     only carry extra-data sources with the six keys update-pins.mjs writes —
//     extra-data is fetched on the user's machine at install time, never in CI.
//     A new manifest-like file is refused outright.
//   - anything that is not a plain file at the top level: subdirectories (a
//     recipe can live anywhere build.manifest points), dotfiles (.gitattributes
//     changes what every `git diff` consumer sees), symlinks and gitlinks (they
//     make a checked-out path read something else), and type changes.
//   - adding or removing an app. A self-merge edits an app already on main; it
//     never creates, renames or de-lists one.
//
// Local files the recipe installs (wrapper, apply_extra.sh, desktop, metainfo,
// icons) are in the surface: they are copied into /app by build-commands that
// cannot change, inside flatpak-builder's sandbox, and they run on users'
// machines with the same trust users already place in the upstream binary.
//
// File contents are read with `git cat-file blob`, never through a checkout or
// a diff driver, so no attribute or textconv can change what is compared.
//
// Prints a markdown reason list on stdout. Exit 0 = allowed, 1 = refused,
// 2 = usage / environment error.
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const MAINTAINERS = join(ROOT, 'config/maintainers.yml');
const BEGIN = '# BEGIN MANAGED EXTRA-DATA';
const END = '# END MANAGED EXTRA-DATA';
const MANAGED_KEYS = new Set(['type', 'filename', 'only-arches', 'url', 'sha256', 'size']);
const ARCHES = new Set(['x86_64', 'aarch64']);

const [base, head, userId] = process.argv.slice(2);
if (!base || !head || !/^\d+$/.test(userId || '')) {
  process.stderr.write('usage: self-merge-check.mjs <base-sha> <head-sha> <commenter-user-id>\n');
  process.exit(2);
}

function git(...args) {
  const r = spawnSync('git', ['-C', ROOT, ...args], { encoding: 'utf8', maxBuffer: 64 << 20 });
  if (r.status !== 0) {
    process.stderr.write(`git ${args.join(' ')} failed: ${r.stderr}`);
    process.exit(2);
  }
  return r.stdout;
}
const show = (rev, path) => git('cat-file', 'blob', `${rev}:${path}`);
// Mode of a path at a revision ('' when absent): 100644/100755 are plain files.
const mode = (rev, path) => git('ls-tree', '-z', rev, '--', path).split(' ')[0] || '';
// Paths go into markdown code spans in the PR reply; keep them from breaking out.
const q = (s) => '`' + String(s).replace(/[`\r\n]/g, '?') + '`';

// config/maintainers.yml: `<app-id>:` then `- login: x` / `id: N` pairs. Only
// the numeric id is authoritative — a login can be renamed and re-registered.
function parseMaintainers(text) {
  const apps = new Map();
  let app = null;
  for (const raw of text.split('\n')) {
    const line = raw.replace(/\s+#.*$/, '').replace(/^#.*$/, '');
    if (!line.trim()) continue;
    let m;
    if ((m = line.match(/^([A-Za-z0-9._-]+):\s*$/))) {
      app = m[1];
      apps.set(app, new Set());
    } else if (app && (m = line.match(/^\s+(?:-\s+)?id:\s*(\d+)\s*$/))) {
      apps.get(app).add(m[1]);
    }
  }
  return apps;
}

// Drop comments and blank lines, and the lines inside the regions a
// maintainer may change, so what is left can be compared verbatim.
function skeleton(text, { finishArgs = false, managed = false } = {}) {
  const out = [];
  let inManaged = false;
  let top = null; // current top-level key
  for (const raw of text.split('\n')) {
    const t = raw.trim();
    if (t === BEGIN) { inManaged = true; if (managed) continue; }
    if (t === END) { inManaged = false; if (managed) continue; }
    if (managed && inManaged) continue;
    if (t === '' || t.startsWith('#')) continue;
    const m = raw.match(/^([A-Za-z0-9_-]+):/);
    if (m) top = m[1];
    if (finishArgs && top === 'finish-args') continue;
    out.push(raw.replace(/\s+$/, ''));
  }
  return out.join('\n');
}

// Everything a PR may put inside the MANAGED block: extra-data list items with
// the keys update-pins.mjs writes, indented at least as deep as the first item
// so nothing can climb out of `sources:` into the module.
function managedProblems(text) {
  const problems = [];
  let inManaged = false;
  let indent = null;
  for (const raw of text.split('\n')) {
    const t = raw.trim();
    if (t === BEGIN) { inManaged = true; indent = null; continue; }
    if (t === END) { inManaged = false; continue; }
    if (!inManaged || t === '' || t.startsWith('#')) continue;
    const lead = raw.length - raw.trimStart().length;
    if (indent === null) indent = lead;
    if (lead < indent) { problems.push(`line escapes the managed block: ${q(t)}`); continue; }
    if (t.startsWith('- ') && ARCHES.has(t.slice(2).trim())) continue;
    const m = t.match(/^(?:-\s+)?([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!m || !MANAGED_KEYS.has(m[1])) { problems.push(`unexpected line in the managed block: ${q(t)}`); continue; }
    if (m[1] === 'type' && m[2] !== 'extra-data') problems.push(`managed source is not extra-data: ${q(t)}`);
  }
  return problems;
}

const reasons = [];
const refuse = (msg) => reasons.push(msg);

const maintainers = parseMaintainers(readFileSync(MAINTAINERS, 'utf8'));
const mine = new Set([...maintainers].filter(([, ids]) => ids.has(userId)).map(([app]) => app));
if (mine.size === 0) {
  process.stdout.write('- You are not listed as a maintainer of any app in `config/maintainers.yml`.\n');
  process.exit(1);
}

const changes = [];
{
  const f = git('diff', '-z', '--name-status', '--no-renames', base, head).split('\0');
  for (let i = 0; i + 1 < f.length; i += 2) changes.push([f[i], f[i + 1]]);
}
if (changes.length === 0) refuse('The PR changes nothing.');

const onMain = (path) => spawnSync('git', ['-C', ROOT, 'cat-file', '-e', `HEAD:${path}`]).status === 0;
const isManifest = (rel) => /\.(ya?ml|json)$/.test(rel) && rel !== 'flatpark.yml';
const REGULAR = new Set(['100644', '100755']);

// Files the base manifests list as bare `- <file>` entries (flatpak-builder
// module files). Nothing else in a manifest is a lone token: finish-args start
// with `--`, build-commands have spaces, sources are maps.
const moduleRefs = new Map();
function referencedModules(id) {
  if (!moduleRefs.has(id)) {
    const refs = new Set();
    const listing = git('ls-tree', '-z', '--name-only', base, '--', `registry/${id}/`).split('\0').filter(Boolean);
    for (const p of listing) {
      const rel = p.slice(`registry/${id}/`.length);
      if (!isManifest(rel) || !REGULAR.has(mode(base, p))) continue;
      for (const line of show(base, p).split('\n')) {
        const m = line.match(/^\s*-\s+["']?([^\s"']+)["']?\s*$/);
        if (m && !m[1].startsWith('-')) refs.add(m[1].replace(/^\.\//, ''));
      }
    }
    moduleRefs.set(id, refs);
  }
  return moduleRefs.get(id);
}

const apps = new Set();

for (const [status, path] of changes) {
  const m = path.match(/^registry\/([^/]+)\/(.+)$/s);
  if (!m) { refuse(`${q(path)} is outside registry/<app-id>/.`); continue; }
  const [, id, rel] = m;
  apps.add(id);
  if (!mine.has(id)) { refuse(`${q(path)} belongs to ${q(id)}, which you do not maintain.`); continue; }
  if (!onMain(`registry/${id}/flatpark.yml`)) { refuse(`${q(id)} is not on main — adding an app needs a maintainer review.`); continue; }

  if (!/^[A-Za-z0-9][A-Za-z0-9._+-]*$/.test(rel)) {
    refuse(`${q(path)}: only plain file names at the top of the app directory may change — no subdirectories or dotfiles.`);
    continue;
  }
  if (!['M', 'A', 'D'].includes(status)) {
    refuse(`${q(path)}: type change (${q(status)}) — symlinks and submodules need a maintainer review.`);
    continue;
  }
  if ((status !== 'D' && !REGULAR.has(mode(head, path))) || (status !== 'A' && !REGULAR.has(mode(base, path)))) {
    refuse(`${q(path)}: not a regular file — symlinks and submodules need a maintainer review.`);
    continue;
  }
  if (rel === 'flatpark.yml' && status === 'D') {
    refuse(`${q(path)} is deleted — de-listing needs a maintainer review.`);
  } else if (rel === 'flatpark.yml') {
    refuse(`${q(path)}: the descriptor drives the update resolver, the build and the site, so changes to it need a maintainer review.`);
  } else if (rel === 'resolve-update.sh') {
    refuse(`${q(path)}: the update resolver runs in CI with a write token, so changes to it need a maintainer review.`);
  } else if (referencedModules(id).has(rel)) {
    refuse(`${q(path)}: a manifest builds this file as a module — build recipe changes need a maintainer review.`);
  } else if (isManifest(rel)) {
    if (status !== 'M') { refuse(`${q(path)} is ${status === 'A' ? 'a new' : 'a deleted'} manifest file — build recipe changes need a maintainer review.`); continue; }
    const before = show(base, path);
    const after = show(head, path);
    if (skeleton(before, { finishArgs: true, managed: true }) !== skeleton(after, { finishArgs: true, managed: true })) {
      refuse(`${q(path)}: only \`finish-args\` and the MANAGED EXTRA-DATA block may change — build steps, modules and non-extra-data sources need a maintainer review.`);
    }
    const markers = (x) => x.split('\n').filter((l) => l.trim() === BEGIN).length;
    if (markers(after) !== markers(before)) refuse(`${q(path)}: the number of MANAGED EXTRA-DATA blocks changed.`);
    for (const p of managedProblems(after)) refuse(`${q(path)}: ${p}`);
    let inFa = false;
    for (const raw of after.split('\n')) {
      if (/^[A-Za-z0-9_-]+:/.test(raw)) inFa = raw.startsWith('finish-args:');
      else if (inFa && raw.trim() && !raw.trim().startsWith('#') && !/^\s+-\s/.test(raw)) {
        refuse(`${q(path)}: unexpected line under finish-args: ${q(raw.trim())}`);
      }
    }
  }
}

if (reasons.length) {
  process.stdout.write(reasons.map((r) => `- ${r}`).join('\n') + '\n');
  process.exit(1);
}
process.stdout.write(`- Every change is inside ${[...apps].map((a) => q(`registry/${a}/`)).join(', ')}, within the self-merge surface.\n`);
