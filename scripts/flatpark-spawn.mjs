#!/usr/bin/env node
// What the pipeline knows about flatpark-spawn, the shared extension
// org.flatpark.Spawn that runs an app's commands on the host
// (docs/packagers/permissions.md#running-commands-on-the-host): how an app has
// to declare it, and the allow-list of apps that may (config/flatpark-spawn.yml).
// Dependency-free like the rest of the PR gate, so the allow-list is read with
// a line scan, not a YAML library: it is a flat list and stays one.
//
// Run directly, it prints the allowed app ids, one per line.
//
// Usage: flatpark-spawn.mjs [allow-list.yml]
import { readFileSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const SPAWN_ID = 'org.flatpark.Spawn';
// The extension point an app declares, as README.md of flatpark/flatpark-spawn
// gives it: `version` is the ABI major, the extension's branch.
export const SPAWN_DIRECTORY = 'lib/flatpark-spawn';
export const SPAWN_VERSION = '1';
// Without it the extension does nothing; with it the app can leave the sandbox.
export const SPAWN_TALK_NAME = '--talk-name=org.freedesktop.Flatpak';

export const ALLOW_LIST = fileURLToPath(new URL('../config/flatpark-spawn.yml', import.meta.url));

const strip = (v) => v.trim().replace(/^["'](.*)["']$/, '$1');

// The ids under `apps:`, as a block list or an inline [a, b]. Throws when the
// file can't be read: the caller decides what a missing list means.
export function readAllowList(path = ALLOW_LIST) {
  const ids = [];
  let inApps = false;
  for (const raw of readFileSync(path, 'utf8').replace(/\r/g, '').split('\n')) {
    if (/^\s*#/.test(raw)) continue;
    const line = raw.replace(/\s+#.*$/, '');
    if (!line.trim()) continue;
    if (!/^\s/.test(line)) {
      const m = line.match(/^apps:\s*(.*)$/);
      inApps = !!m && m[1].trim() === '';
      if (m && m[1].trim() !== '' && m[1].trim() !== '[]') {
        m[1].trim().replace(/^\[|\]$/g, '').split(',').map(strip).filter(Boolean).forEach((id) => ids.push(id));
      }
      continue;
    }
    const m = inApps && line.trim().match(/^-\s+(\S+)$/);
    if (m) ids.push(strip(m[1]));
  }
  return ids;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  for (const id of readAllowList(process.argv[2] || ALLOW_LIST)) process.stdout.write(`${id}\n`);
}
