#!/usr/bin/env node
// What an extension needs to know about its parent's manifest: the extension
// points under `add-extensions:` and the top-level keys a stand-in for the app
// needs. Like read-descriptor.mjs this is NOT a general YAML parser: manifests
// here keep a fixed shape, and the pipeline stays dependency-free.
//
// Run directly, it prints the metadata of that stand-in
// (install-parent-skeleton.sh), or with --bundled the points the app builds
// itself (`bundle: true`), whose refs ship with it (prune-and-reclaim.sh).
//
// Usage: read-extension-points.mjs <manifest.yml> <arch>
//        read-extension-points.mjs --bundled <manifest.yml>
import { readFileSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const strip = (v) => v.trim().replace(/^["'](.*)["']$/, '$1');

export function readManifestHead(text) {
  const head = { points: {} };
  let inBlock = false;
  let pointIndent = null;
  let point = null;
  for (const raw of text.replace(/\r/g, '').split('\n')) {
    const t = raw.trim();
    if (!t || t.startsWith('#')) continue;
    const indent = raw.length - raw.trimStart().length;
    if (indent === 0) {
      inBlock = /^add-extensions:\s*$/.test(raw);
      pointIndent = null;
      const m = raw.match(/^(id|runtime|runtime-version|sdk|command|build-extension):\s*(.+)$/);
      if (m) head[m[1]] = strip(m[2]);
      continue;
    }
    if (!inBlock) continue;
    const m = t.match(/^([^:\s]+):\s*(.*)$/);
    if (!m) continue;
    if (pointIndent === null || indent <= pointIndent) {
      pointIndent = indent;
      point = m[1];
      head.points[point] = {};
    } else {
      head.points[point][m[1]] = strip(m[2]);
    }
  }
  return head;
}

function skeletonMetadata(head, arch) {
  const version = head['runtime-version'];
  const sdk = (head.sdk || '').split('//')[0];
  const out = ['[Application]', `name=${head.id}`, `runtime=${head.runtime}/${arch}/${version}`];
  if (sdk) out.push(`sdk=${sdk}/${arch}/${version}`);
  out.push(`command=${head.command || 'stub'}`);
  for (const [name, keys] of Object.entries(head.points)) {
    out.push('', `[Extension ${name}]`);
    for (const [k, v] of Object.entries(keys)) out.push(`${k}=${v}`);
  }
  return out.join('\n') + '\n';
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [file, arch] = process.argv.slice(2);
  if (!file || !arch) {
    process.stderr.write('usage: read-extension-points.mjs <manifest.yml> <arch> | --bundled <manifest.yml>\n');
    process.exit(2);
  }
  if (file === '--bundled') {
    const { points } = readManifestHead(readFileSync(arch, 'utf8'));
    for (const [name, keys] of Object.entries(points)) if (keys.bundle === 'true') process.stdout.write(`${name}\n`);
    process.exit(0);
  }
  const head = readManifestHead(readFileSync(file, 'utf8'));
  if (!head.id || !head.runtime || !head['runtime-version']) {
    process.stderr.write(`${file}: no top-level id / runtime / runtime-version\n`);
    process.exit(1);
  }
  process.stdout.write(skeletonMetadata(head, arch));
}
