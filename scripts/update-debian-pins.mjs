#!/usr/bin/env node
// Re-pin the Debian packages an app carries as extra-data.
//
//   node scripts/update-debian-pins.mjs [<app-id>...]      # default: every app
//
// Why this is its own script. A handful of apps need a command-line program that
// neither the runtime nor the vendor's own payload ships, and the cheapest honest
// source for one is the distribution's own binary package, pinned as a second
// extra-data source. Debian keeps exactly one version of a package per suite in
// the pool: the moment a new upload supersedes it, the file this manifest points
// at is gone, and every *new* install of the app fails on the download. Existing
// installs are unaffected — they already have the bytes — which is precisely why
// nobody notices.
//
// update-check.yml cannot do this job. It runs the app's own resolver and
// short-circuits on the app's version (update-pins.mjs exits 10 when upstream
// hasn't moved), so a Debian-side upload is invisible to it for as long as the
// app itself stays put. This script is driven by the distribution instead, and
// touches nothing else.
//
// The manifest marks the block, and the suite and components to resolve against:
//
//   # BEGIN MANAGED DEBIAN sid main
//   - type: extra-data
//     filename: libidn12.deb
//     ...
//   # END MANAGED DEBIAN
//
// `filename` minus `.deb` is the binary package name — that is the whole contract.
// The package index carries the URL, the SHA-256 and the size, so nothing is
// downloaded here: one index per suite/component, whatever the number of apps.
//
// Prints one line per change, and exits 0 whether or not anything moved. A
// missing package in the suite is an error (exit 1): silently keeping a stale pin
// is the failure this script exists to prevent.
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { gunzipSync } from 'node:zlib';

const ROOT = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const REGISTRY = join(ROOT, 'registry');
const MIRROR = process.env.DEBIAN_MIRROR || 'https://deb.debian.org/debian';
const BEGIN = /^(\s*)#\s*BEGIN MANAGED DEBIAN\s+(\S+)\s+(\S+)\s*$/;
const END = /^\s*#\s*END MANAGED DEBIAN\s*$/;

const indexCache = new Map();
async function index(suite, component) {
  const key = `${suite}/${component}`;
  if (indexCache.has(key)) return indexCache.get(key);
  const url = `${MIRROR}/dists/${suite}/${component}/binary-amd64/Packages.gz`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  const text = gunzipSync(Buffer.from(await res.arrayBuffer())).toString('utf8');
  const map = new Map();
  for (const para of text.split('\n\n')) {
    const name = /^Package: (.+)$/m.exec(para);
    const file = /^Filename: (.+)$/m.exec(para);
    const sha = /^SHA256: (.+)$/m.exec(para);
    const size = /^Size: (.+)$/m.exec(para);
    const version = /^Version: (.+)$/m.exec(para);
    if (!name || !file || !sha || !size) continue;
    map.set(name[1].trim(), {
      url: `${MIRROR}/${file[1].trim()}`,
      sha256: sha[1].trim(),
      size: size[1].trim(),
      version: version ? version[1].trim() : '?',
    });
  }
  indexCache.set(key, map);
  return map;
}

const ids = process.argv.slice(2).length
  ? process.argv.slice(2)
  : readdirSync(REGISTRY).filter((d) => existsSync(join(REGISTRY, d, 'flatpark.yml')));

let changed = 0;
for (const id of ids) {
  const dir = join(REGISTRY, id);
  const manifest = join(dir, `${id}.yml`);
  if (!existsSync(manifest)) continue;
  const lines = readFileSync(manifest, 'utf8').split('\n');
  const start = lines.findIndex((l) => BEGIN.test(l));
  if (start < 0) continue;
  const end = lines.findIndex((l, i) => i > start && END.test(l));
  if (end < 0) throw new Error(`${id}: MANAGED DEBIAN block is not closed`);
  const [, indent, suite, componentList] = BEGIN.exec(lines[start]);

  // Read the block the way read-descriptor does — a line scan, not a YAML parse.
  const entries = [];
  let cur = null;
  for (const raw of lines.slice(start + 1, end)) {
    const t = raw.trim();
    if (t.startsWith('- type:')) { cur = { arches: [] }; entries.push(cur); continue; }
    if (!cur) continue;
    let m;
    if ((m = /^filename:\s*(.+)$/.exec(t))) cur.filename = m[1].trim();
    else if ((m = /^url:\s*(.+)$/.exec(t))) cur.url = m[1].trim();
    else if ((m = /^sha256:\s*(.+)$/.exec(t))) cur.sha256 = m[1].trim();
    else if ((m = /^size:\s*(.+)$/.exec(t))) cur.size = m[1].trim();
    else if ((m = /^-\s*(\S+)$/.exec(t))) cur.arches.push(m[1].trim());
  }

  const out = [];
  let touched = false;
  for (const e of entries) {
    if (!e.filename || !e.filename.endsWith('.deb')) {
      throw new Error(`${id}: MANAGED DEBIAN entries must be named <package>.deb, got ${e.filename}`);
    }
    const pkg = e.filename.slice(0, -4);
    let found = null;
    for (const component of componentList.split(',')) {
      const map = await index(suite, component.trim());
      if (map.has(pkg)) { found = map.get(pkg); break; }
    }
    if (!found) throw new Error(`${id}: ${pkg} is not in ${suite} (${componentList})`);
    if (found.url !== e.url || found.sha256 !== e.sha256 || found.size !== e.size) {
      console.log(`${id}: ${pkg} -> ${found.version}`);
      touched = true;
      changed++;
    }
    const arches = e.arches.length ? e.arches : ['x86_64'];
    out.push(`${indent}- type: extra-data`);
    out.push(`${indent}  filename: ${e.filename}`);
    out.push(`${indent}  only-arches:`);
    for (const a of arches) out.push(`${indent}    - ${a}`);
    out.push(`${indent}  url: ${found.url}`);
    out.push(`${indent}  sha256: ${found.sha256}`);
    out.push(`${indent}  size: ${found.size}`);
  }
  if (touched) {
    writeFileSync(manifest, [...lines.slice(0, start + 1), ...out, ...lines.slice(end)].join('\n'));
  }
}
if (!changed) console.log('debian pins: up to date');
