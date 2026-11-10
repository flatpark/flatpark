#!/usr/bin/env node
// Audit a FlatPark registry descriptor + its manifest against the review-bar
// guardrails (see docs/reviewers/review-runbook.md). Dependency-free: the PR gate runs `node`
// before any `npm ci`, so this uses the same manual line-scan style as
// read-descriptor.mjs rather than a YAML library.
//
//   node scripts/audit-descriptor.mjs <flatpark.yml>
//
// Exit 0 = no hard failures (warnings allowed); exit 1 = hard failure(s).
// Hard failures print `FAIL: ...`; advisory findings print `WARN: ...`.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readManifestHead } from './read-extension-points.mjs';

const file = process.argv[2];
if (!file) {
  process.stderr.write('usage: audit-descriptor.mjs <flatpark.yml>\n');
  process.exit(2);
}

const fails = [];
const warns = [];
const fail = (m) => fails.push(m);
const warn = (m) => warns.push(m);

const readText = (p) => readFileSync(p, 'utf8').replace(/\r/g, '');
const indentOf = (l) => l.length - l.replace(/^\s+/, '').length;
function unquote(v) {
  v = v.trim();
  if (v === '' || v === '~' || v === 'null') return '';
  const c = v[0];
  if ((c === '"' || c === "'") && v[v.length - 1] === c) return v.slice(1, -1);
  return v;
}

// --- descriptor: build.manifest, update.{command,auto}, policy.{proprietary,dangerous_permissions}
let descText;
try {
  descText = readText(file);
} catch (e) {
  process.stderr.write(`FAIL: cannot read ${file}: ${e.message || e}\n`);
  process.exit(1);
}

let appId = '';
let sourceUrl = '';
let manifestName = '';
let extendsId = '';
let updateCommand = '';
let updateAuto = null;
let proprietary = null;
let upstreamSeen = false;
let starsRepo = null;
let upstreamManifest = '';
let upstreamList = null;
const dangerousPerms = [];
const packagingKinds = [];
const UPSTREAM_LISTS = {
  accept_missing_permissions: [],
  accept_extra_permissions: [],
  accept_missing_modules: [],
  accept_extra_modules: [],
};
{
  let section = null;
  let inDanger = false;
  for (const raw of descText.split('\n')) {
    if (!raw.trim() || /^\s*#/.test(raw)) continue;
    const ind = indentOf(raw);
    const s = raw.trim();
    if (ind === 0) {
      inDanger = false;
      upstreamList = null;
      const m = s.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
      if (m && m[1] === 'id' && m[2] !== '') appId = unquote(m[2]);
      if (m && m[1] === 'source_url' && m[2] !== '') sourceUrl = unquote(m[2]);
      section = m && m[2] === '' ? m[1] : null;
      continue;
    }
    if (section === 'packaging') {
      const km = s.match(/^(?:-\s+)?kind:\s*(.*)$/);
      if (km) packagingKinds.push(unquote(km[1]));
      continue;
    }
    if (s.startsWith('- ')) {
      if (section === 'policy' && inDanger) dangerousPerms.push(unquote(s.slice(2)));
      else if (section === 'upstream' && upstreamList) UPSTREAM_LISTS[upstreamList].push(unquote(s.slice(2)));
      continue;
    }
    const m = s.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!m) continue;
    const [, k, v] = m;
    if (section === 'build' && k === 'manifest') manifestName = unquote(v);
    else if (section === 'build' && k === 'extends') extendsId = unquote(v);
    else if (section === 'catalog' && k === 'stars_repo') starsRepo = unquote(v);
    else if (section === 'update' && k === 'command') updateCommand = unquote(v);
    else if (section === 'update' && k === 'auto') updateAuto = unquote(v);
    else if (section === 'policy') {
      if (k === 'proprietary') proprietary = unquote(v) === 'true';
      else if (k === 'dangerous_permissions') {
        const t = v.trim();
        if (t === '') inDanger = true;
        else if (t !== '[]') t.replace(/^\[|\]$/g, '').split(',').map(unquote).filter(Boolean).forEach((x) => dangerousPerms.push(x));
      }
    } else if (section === 'upstream') {
      upstreamSeen = true;
      upstreamList = null;
      if (k === 'manifest') upstreamManifest = unquote(v);
      else if (Object.prototype.hasOwnProperty.call(UPSTREAM_LISTS, k)) {
        const t = v.trim();
        if (t === '') upstreamList = k;
        else if (t !== '[]') fail(`upstream.${k} must be a block list or []`);
      } else fail(`upstream: unknown key ${k}`);
    }
  }
}

if (!manifestName) fail('descriptor missing build.manifest');

// Opt-in drift check (scripts/check-upstream-manifests.mjs). A typo here would
// either point the sweep at the wrong file or hide a real permission change,
// so the shape is a gate rather than a warning.
if (upstreamSeen) {
  if (!upstreamManifest) fail('upstream.manifest is required when upstream: is set');
  else if (!/^[A-Za-z0-9._+/-]+\.ya?ml$/.test(upstreamManifest) || upstreamManifest.split('/').includes('..')) {
    fail(`upstream.manifest must be a relative .yml path inside the upstream repo, got: ${upstreamManifest}`);
  }
  if (!/^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(sourceUrl)) {
    fail('upstream: source_url must be an https://github.com/owner/repo URL');
  }
  for (const p of UPSTREAM_LISTS.accept_missing_permissions.concat(UPSTREAM_LISTS.accept_extra_permissions)) {
    if (!/^--\S+$/.test(p)) fail(`upstream permission must be a finish-arg, got: ${p}`);
  }
  for (const name of UPSTREAM_LISTS.accept_missing_modules.concat(UPSTREAM_LISTS.accept_extra_modules)) {
    if (!/^[A-Za-z0-9._+-]+$/.test(name)) fail(`upstream module name is not a plain name, got: ${name}`);
  }
}

// Upstream stars (site/src/lib/stars.mjs) come from source_url's repository
// unless catalog.stars_repo names another or opts out. A source_url that is a
// build or packaging repo (a third-party build, or a closed app packaged by
// someone else) would show that repo's handful of stars as the project's, so
// it has to say which repository counts.
if (starsRepo !== null && starsRepo !== 'none' && !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(starsRepo)) {
  fail(`catalog.stars_repo must be owner/name or none, got: ${starsRepo}`);
}
{
  const gh = /^https?:\/\/github\.com\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)/.exec(sourceUrl);
  if (gh && starsRepo === null && !extendsId &&
      (gh[1].toLowerCase() === 'flathub' || /[-_.](release|releases|flatpak|build|builds|packaging)$/i.test(gh[2]))) {
    warn(`source_url ${gh[1]}/${gh[2]} looks like a build/packaging repo: set catalog.stars_repo to upstream's owner/name, or none (docs/packagers/basics.md)`);
  }
}

// The catalog card and the app page render registry/<id>/<id>.svg|png, copied
// verbatim by gen-apps-json.sh. Any other filename is invisible to the site,
// which then falls back to the app's initials on a coloured square — so the
// naming convention is a gate, not a style note.
if (appId) {
  const iconDir = dirname(file);
  if (!['svg', 'png'].some((ext) => existsSync(join(iconDir, `${appId}.${ext}`)))) {
    fail(`missing catalog icon: expected ${appId}.svg or ${appId}.png next to the descriptor`);
  }
}

// update.command must be a simple relative script path (it runs in CI).
if (updateCommand && !/^\.\/[A-Za-z0-9._-]+$/.test(updateCommand)) {
  fail(`update.command must be a simple relative script path (e.g. ./resolve-update.sh), got: ${updateCommand}`);
}
// read-descriptor.mjs treats anything but `false` as on, so a typo would
// silently re-enable the sweep.
if (updateAuto !== null && updateAuto !== 'true' && updateAuto !== 'false') {
  fail(`update.auto must be true or false, got: ${updateAuto}`);
}
// check-updates.sh runs it directly, so a missing exec bit only shows up as
// "Permission denied" in the nightly sweep.
if (updateCommand && /^\.\/[A-Za-z0-9._-]+$/.test(updateCommand)) {
  const script = join(dirname(file), updateCommand);
  if (existsSync(script) && !(statSync(script).mode & 0o111)) fail(`update.command is not executable: ${updateCommand} (git update-index --chmod=+x)`);
}

// --- manifest: finish-args, sources, build-commands
const dir = dirname(file);
const finishArgs = [];
const sources = []; // [{ type, keys }]
const buildCommands = [];
if (manifestName) {
  let manifestText = '';
  try {
    manifestText = readText(join(dir, manifestName));
  } catch {
    fail(`cannot read manifest ${manifestName}`);
  }
  if (manifestText) {
    let block = null; // 'finish' | 'build' | 'sources'
    let blockIndent = -1;
    let cur = null; // current source
    let curIndent = -1;
    let srcItemIndent = -1; // indent of a `- ` source item within the current sources block
    for (const raw of manifestText.split('\n')) {
      if (!raw.trim() || /^\s*#/.test(raw)) continue;
      const ind = indentOf(raw);
      const s = raw.trim();

      if (block !== null && ind <= blockIndent) { block = null; cur = null; srcItemIndent = -1; }

      const hdr = s.match(/^(finish-args|build-commands|sources):\s*(.*)$/);
      if (hdr && (hdr[2].trim() === '' || hdr[2].trim() === '[]')) {
        block = hdr[1] === 'finish-args' ? 'finish' : hdr[1] === 'build-commands' ? 'build' : 'sources';
        blockIndent = ind;
        cur = null;
        srcItemIndent = -1;
        continue;
      }

      if (block === 'finish' && s.startsWith('- ')) { finishArgs.push(unquote(s.slice(2))); continue; }
      if (block === 'build' && s.startsWith('- ')) { buildCommands.push(unquote(s.slice(2))); continue; }
      if (block === 'sources') {
        if (s.startsWith('- ')) {
          if (srcItemIndent === -1) srcItemIndent = ind;
          // Only a `- ` at the source-item indent starts a new source; a deeper
          // `- ` is a nested list value (e.g. a mirror-urls entry).
          if (ind === srcItemIndent) {
            cur = { type: '', keys: {} };
            curIndent = ind;
            sources.push(cur);
            const li = s.slice(2).match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
            if (li) {
              cur.keys[li[1]] = unquote(li[2]);
              if (li[1] === 'type') cur.type = unquote(li[2]);
            }
          }
          continue;
        }
        if (cur && ind > curIndent) {
          const kv = s.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
          if (kv) {
            cur.keys[kv[1]] = unquote(kv[2]);
            if (kv[1] === 'type') cur.type = unquote(kv[2]);
          }
          continue;
        }
      }
    }
  }
}

// G1 — source pinning, per type.
const LOCAL = new Set(['file', 'script', 'patch', 'dir', 'shell']);
for (const src of sources) {
  const t = src.type;
  if (t === 'git') {
    if (!src.keys.commit) fail(`git source missing immutable commit (${src.keys.url || ''})`);
  } else if (t === 'archive') {
    if (!src.keys.sha256) fail(`archive source missing sha256 (${src.keys.url || ''})`);
  } else if (t === 'extra-data') {
    if (!src.keys.sha256) fail(`extra-data source missing sha256 (${src.keys.url || src.keys.filename || ''})`);
    if (!src.keys.size || src.keys.size === '0') fail(`extra-data source missing/zero size (${src.keys.url || src.keys.filename || ''})`);
  } else if (t === '' || !LOCAL.has(t)) {
    warn(`source type '${t || '?'}' not auto-verified — needs human review`);
  }
}

// An extension runs inside its parent's sandbox, on its parent's runtime, and
// the repo only holds what the ref carries: its payload has to be extra-data.
if (manifestName && existsSync(join(dirname(file), manifestName))) {
  const own = readManifestHead(readText(join(dirname(file), manifestName)));
  if (own['build-extension'] === 'true' && !extendsId) fail('build-extension: true needs build.extends in the descriptor');
  if (extendsId) {
    const parentDir = join(dirname(file), '..', extendsId);
    const parentManifest = existsSync(join(parentDir, 'flatpark.yml'))
      ? readText(join(parentDir, 'flatpark.yml')).match(/^\s+manifest:\s*(\S+)\s*$/m)?.[1]
      : '';
    if (!parentManifest || !existsSync(join(parentDir, parentManifest))) {
      fail(`build.extends: ${extendsId} is not in the registry`);
    } else {
      const parent = readManifestHead(readText(join(parentDir, parentManifest)));
      const declared = Object.entries(parent.points).some(([point, keys]) =>
        appId === point || (keys.subdirectories === 'true' && appId.startsWith(`${point}.`)));
      if (!declared) fail(`build.extends: ${extendsId} declares no extension point for ${appId}`);
      if (own['build-extension'] !== 'true') fail('build.extends needs build-extension: true in the manifest');
      if (own.runtime !== extendsId) fail(`build.extends: the manifest's runtime must be ${extendsId}`);
      if (finishArgs.length) fail("an extension has no finish-args: it runs with its parent's");
      if (!sources.some((s) => s.type === 'extra-data')) fail('an extension carries its payload as extra-data');
      for (const s of sources) {
        if (s.type === 'archive' || s.type === 'git') fail(`an extension can't build from a ${s.type} source: only extra-data keeps it out of the repo`);
      }
      const sdkVersion = (own.sdk || '').split('//')[1];
      if (sdkVersion !== parent['runtime-version']) {
        fail(`build.extends: sdk version ${sdkVersion} differs from ${extendsId}'s runtime ${parent['runtime-version']}`);
      }
      // build.arches as read-descriptor.mjs resolves it (x86_64 when silent).
      // A descriptor it rejects fails on its own elsewhere.
      const archesOf = (descriptor) => {
        try {
          const out = execFileSync(process.execPath, [fileURLToPath(new URL('./read-descriptor.mjs', import.meta.url)), descriptor],
            { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
          return (out.match(/^_FP_ARCHES='([^']*)'/m)?.[1] ?? '').split(' ').filter(Boolean);
        } catch {
          return null;
        }
      };
      const ownArches = archesOf(file);
      const parentArches = archesOf(join(parentDir, 'flatpark.yml'));
      const missing = ownArches && parentArches ? ownArches.filter((a) => !parentArches.includes(a)) : [];
      if (missing.length) fail(`build.arches: ${extendsId} is not built for ${missing.join(', ')}`);
    }
  }
}

// G2(a) — sandbox-escape permissions are a hard fail.
const ESCAPE = ['--talk-name=org.freedesktop.Flatpak', '--filesystem=host', '--filesystem=/'];
// G2(b) — broad perms must be declared in policy.dangerous_permissions (warn until schema lands).
// The PipeWire socket is here because it reaches every camera and other apps'
// video streams without a portal (docs/packagers/permissions.md#the-pipewire-socket).
const WATCH = ['--device=all', '--filesystem=home', '--filesystem=xdg-run/pipewire-0'];
// Compare --filesystem grants without their :ro / :rw / :create mode, so
// home:ro and host:ro hit the same lists as home and host.
const baseFs = (p) => p.replace(/^(--filesystem=[^:]+):(ro|rw|create)$/, '$1');
const declared = new Set(dangerousPerms.map(baseFs));
for (const fa of finishArgs) {
  const base = baseFs(fa);
  if (ESCAPE.includes(base)) {
    // A declared escape permission is an explicit, reviewed exemption: downgrade
    // the hard fail to a warning so it stays visible without blocking the gate.
    if (declared.has(base)) warn(`sandbox-escape permission ${fa} (declared in policy.dangerous_permissions)`);
    else fail(`sandbox-escape permission: ${fa}`);
  }
  if (WATCH.includes(base) && !declared.has(base)) {
    warn(`dangerous permission ${fa} not declared in policy.dangerous_permissions`);
  }
}

// G3 — runtime fetch-and-exec (warn only; vendor self-updaters surface here too).
const FETCH = [/\bnpm install\b/, /\bpip install\b/, /\bpip3 install\b/, /curl[^\n]*\|\s*sh\b/, /wget[^\n]*\|\s*sh\b/];
const scan = [...buildCommands];
try {
  for (const f of readdirSync(dir)) {
    if (/\.sh$/.test(f) || /wrapper$/.test(f)) {
      try { scan.push(readText(join(dir, f))); } catch { /* ignore */ }
    }
  }
} catch { /* ignore */ }
for (const text of scan) {
  for (const re of FETCH) {
    if (re.test(text)) { warn(`possible runtime fetch-and-exec: ${text.trim().split('\n')[0].slice(0, 80)}`); break; }
  }
}

// G6 — packaging transparency (shown on the site as the packaging level). What
// the scripts plainly do must be declared under `packaging:`, and an
// open-source app may not modify the vendor's build at all.
const PACKAGING_KINDS = new Set([
  'support-files', 'seeded-config', 'injected-code', 'file-change', 'runtime-install', 'host-command', 'sandbox-off',
]);
for (const k of packagingKinds) if (!PACKAGING_KINDS.has(k)) fail(`packaging: unknown kind "${k}"`);
{
  const declared = new Set(packagingKinds);
  const codeOnly = (text) => text.split('\n').filter((l) => !/^\s*(#|\/\/|\*|\/\*)/.test(l)).join('\n');
  let code = '';
  let hasC = false;
  try {
    for (const f of readdirSync(dir)) {
      if (/\.(xml|png|svg|desktop|md)$/.test(f) || f === 'flatpark.yml' || f === 'resolve-update.sh') continue;
      if (/\.c$/.test(f)) hasC = true;
      try { code += '\n' + codeOnly(readText(join(dir, f))); } catch { /* ignore */ }
    }
  } catch { /* ignore */ }
  const need = (kind, why) => {
    if (!declared.has(kind)) fail(`packaging: ${why}, but packaging: declares no "${kind}" entry`);
  };
  if (hasC || /(^|[\s;"'])(export\s+)?(ZYPAK_)?LD_PRELOAD=|--env=LD_PRELOAD=/m.test(code)) {
    need('injected-code', 'a C module or an LD_PRELOAD puts code into the app process');
  }
  if (finishArgs.includes('--talk-name=org.freedesktop.Flatpak') || /\bflatpak-spawn\b/.test(code)) {
    need('host-command', 'the app can run host commands (org.freedesktop.Flatpak / flatpak-spawn)');
  }
  if (/--no-sandbox\b|WEBKIT_DISABLE_SANDBOX/.test(code)) {
    need('sandbox-off', "the app's own sandbox is turned off (--no-sandbox / WEBKIT_DISABLE_SANDBOX)");
  }
  if (proprietary === false) {
    for (const k of ['injected-code', 'file-change', 'runtime-install']) {
      if (declared.has(k)) fail(`packaging: "${k}" is not allowed for an open-source app (it ships unmodified; the fix belongs upstream)`);
    }
  }
}

for (const w of warns) process.stderr.write(`WARN: ${w}\n`);
for (const f of fails) process.stderr.write(`FAIL: ${f}\n`);
process.exit(fails.length ? 1 : 0);
