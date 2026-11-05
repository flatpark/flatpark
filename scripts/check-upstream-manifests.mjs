#!/usr/bin/env node
// Compare a package's Flatpak manifest with the upstream manifest it names.
//
// The pin sweep rewrites only the download. Finish-args and modules stay as
// they were the day the package was written, which is how a printing fix in
// upstream's own Flatpak never reached the FlatPark package. This check
// fetches the upstream file from source_url's default branch and reports the
// difference. It never edits a manifest.
//
//   node scripts/check-upstream-manifests.mjs [--registry DIR] [--app ID]
//        [--upstream-file PATH] [--alert]
//
// Exit 1 when a checked app differs or its upstream file could not be read.
// With --alert the same findings are written to ci-alert issues (one per app,
// refreshed every run, closed when the manifests agree) and the exit status
// stays 0, so a pin refresh can still merge. --upstream-file skips the
// network and requires --app; the tests use it.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

function unquote(v) {
  v = v.trim();
  if (v === '' || v === '~' || v === 'null') return '';
  const c = v[0];
  if ((c === '"' || c === "'") && v[v.length - 1] === c) return v.slice(1, -1);
  return v;
}

function indentOf(line) {
  return line.length - line.trimStart().length;
}

// The descriptor schema is ours and small. Pull out the fields this check
// needs; everything else is ignored, the same way read-descriptor.mjs works.
function parseDescriptor(text) {
  const d = {
    sourceUrl: '',
    manifest: '',
    upstreamManifest: '',
    acceptMissingPermissions: [],
    acceptExtraPermissions: [],
    acceptMissingModules: [],
    acceptExtraModules: [],
  };
  const lists = {
    accept_missing_permissions: d.acceptMissingPermissions,
    accept_extra_permissions: d.acceptExtraPermissions,
    accept_missing_modules: d.acceptMissingModules,
    accept_extra_modules: d.acceptExtraModules,
  };
  let section = null;
  let list = null;
  for (const raw of text.split('\n')) {
    const line = raw.replace(/\r$/, '');
    if (!line.trim() || /^\s*#/.test(line)) continue;
    const indent = indentOf(line);
    const s = line.trim();
    if (indent === 0) {
      list = null;
      const m = s.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
      if (m && m[1] === 'source_url' && m[2] !== '') d.sourceUrl = unquote(m[2]);
      section = m && m[2] === '' ? m[1] : null;
      continue;
    }
    if (s.startsWith('- ')) {
      if (list) list.push(unquote(s.slice(2)));
      continue;
    }
    const m = s.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!m) continue;
    const [, k, v] = m;
    if (section === 'build' && k === 'manifest') d.manifest = unquote(v);
    else if (section === 'upstream') {
      list = null;
      if (k === 'manifest') d.upstreamManifest = unquote(v);
      else if (lists[k] && v.trim() === '') list = lists[k];
    }
  }
  return d;
}

// finish-args, plus each module's name, the source types it uses, and the
// archive/git URLs those sources pin. Enough to see a new permission, a new
// helper module, or a helper's tarball moving. Not a general YAML parser:
// Flatpak manifests in this check are block lists of scalars and maps.
function parseManifest(text) {
  const finish = [];
  const modules = [];
  let inFinish = false;
  let finishIndent = null;
  let inModules = false;
  let modulesIndent = null;
  let module = null;
  let sourceType = null;

  function closeModule() {
    if (module && module.name) modules.push(module);
    module = null;
    sourceType = null;
  }

  for (const raw of text.split('\n')) {
    const line = raw.replace(/\r$/, '');
    if (!line.trim() || /^\s*#/.test(line)) continue;
    const indent = indentOf(line);
    const s = line.trim();

    if (indent === 0) {
      if (inModules) closeModule();
      inFinish = false;
      inModules = false;
      finishIndent = null;
      modulesIndent = null;
      const m = s.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
      if (m && m[2] === '' && m[1] === 'finish-args') inFinish = true;
      else if (m && m[2] === '' && m[1] === 'modules') inModules = true;
      continue;
    }

    if (inFinish) {
      if (finishIndent === null) finishIndent = indent;
      if (indent < finishIndent) inFinish = false;
      else if (indent === finishIndent && s.startsWith('- ')) finish.push(unquote(s.slice(2)));
      if (inFinish) continue;
    }

    if (inModules) {
      if (modulesIndent === null) modulesIndent = indent;
      if (indent < modulesIndent) {
        closeModule();
        inModules = false;
      } else if (indent === modulesIndent && s.startsWith('- ')) {
        closeModule();
        const rest = s.slice(2);
        const named = rest.match(/^name:\s*(.*)$/);
        module = {
          name: named ? unquote(named[1]) : unquote(rest),
          types: new Set(),
          urls: [],
        };
        continue;
      } else if (module) {
        if (s.startsWith('- ')) {
          sourceType = null;
          const typed = s.slice(2).match(/^type:\s*(.*)$/);
          if (typed) module.types.add(unquote(typed[1])), sourceType = unquote(typed[1]);
        } else {
          const typed = s.match(/^type:\s*(.*)$/);
          if (typed) module.types.add(unquote(typed[1])), sourceType = unquote(typed[1]);
          const named = s.match(/^name:\s*(.*)$/);
          if (named && !module.name) module.name = unquote(named[1]);
          const url = s.match(/^url:\s*(.*)$/);
          if (url && (sourceType === 'archive' || sourceType === 'git')) module.urls.push(unquote(url[1]));
        }
        continue;
      }
    }
  }
  if (inModules) closeModule();
  return { finish, modules };
}

function without(items, gone) {
  const skip = new Set(gone);
  return items.filter((item) => !skip.has(item));
}

function diffLists(ours, upstream, acceptMissing, acceptExtra) {
  const oursSet = new Set(ours);
  const upstreamSet = new Set(upstream);
  return {
    missing: without(upstream.filter((item) => !oursSet.has(item)), acceptMissing),
    extra: without(ours.filter((item) => !upstreamSet.has(item)), acceptExtra),
  };
}

function urlsOf(mod) {
  return [...new Set(mod.urls)].sort();
}

// The app module itself is a dir or an extra-data tarball, so its URLs are a
// different kind of pin and move on every release. A helper such as
// cups-client is an archive on both sides; that URL is the thing to watch.
function skipSourceCompare(ours, upstream) {
  return ours.types.has('dir') || ours.types.has('extra-data')
    || upstream.types.has('dir') || upstream.types.has('extra-data');
}

function sourceChanges(ours, upstream) {
  const oursByName = new Map(ours.map((mod) => [mod.name, mod]));
  const changes = [];
  for (const up of upstream) {
    const here = oursByName.get(up.name);
    if (!here || skipSourceCompare(here, up)) continue;
    const a = urlsOf(here);
    const b = urlsOf(up);
    if (a.join('\n') !== b.join('\n')) changes.push({ module: up.name, ours: a, upstream: b });
  }
  return changes;
}

function githubContentsUrl(sourceUrl, manifestPath) {
  const m = sourceUrl.match(/^https:\/\/github\.com\/([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)$/);
  if (!m) return null;
  return `https://api.github.com/repos/${m[1]}/${m[2]}/contents/${manifestPath}`;
}

async function fetchText(url) {
  const headers = {
    Accept: 'application/vnd.github.raw',
    'User-Agent': 'flatpark-upstream-manifest',
  };
  if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
  return res.text();
}

function emptyApp(id) {
  return {
    id,
    error: '',
    missingPermissions: [],
    extraPermissions: [],
    missingModules: [],
    extraModules: [],
    sourceChanges: [],
  };
}

function drifted(app) {
  return Boolean(app.error)
    || app.missingPermissions.length
    || app.extraPermissions.length
    || app.missingModules.length
    || app.extraModules.length
    || app.sourceChanges.length;
}

function lines(title, items) {
  if (!items.length) return '';
  return `**${title}**\n\n${items.map((item) => `- \`${item}\``).join('\n')}\n\n`;
}

function alertBody(app, descriptor) {
  if (app.error) {
    return [
      `The update sweep could not read the upstream Flatpak manifest for \`${app.id}\`, so a permission change there would ship unnoticed.`,
      '',
      `\`${descriptor.upstreamManifest}\` in ${descriptor.sourceUrl}`,
      '',
      '```',
      app.error,
      '```',
      '',
      'The pin refresh does not copy permissions or modules, and this check does not edit the package. This issue closes itself once the file can be read and the manifests agree.',
    ].join('\n');
  }
  const sources = app.sourceChanges.map((change) => {
    const ours = change.ours.length ? change.ours.join(', ') : '(none)';
    const upstream = change.upstream.length ? change.upstream.join(', ') : '(none)';
    return `\`${change.module}\`: ours \`${ours}\`, upstream \`${upstream}\``;
  });
  return [
    `Upstream's Flatpak manifest for \`${app.id}\` no longer matches this package. The pin refresh does not copy permissions or modules; someone decides in a pull request.`,
    '',
    `\`${descriptor.upstreamManifest}\` in ${descriptor.sourceUrl}`,
    '',
    lines('Upstream grants permissions this package does not', app.missingPermissions),
    lines('Upstream builds modules this package does not', app.missingModules),
    lines('A shared module pins a different archive', sources),
    lines('This package grants permissions upstream does not', app.extraPermissions),
    lines('This package builds modules upstream does not', app.extraModules),
    'A permission on its own may not be enough: the WordCraft print dialog needed `lpstat` and `lp` as well as the CUPS socket, and those tools are a module. Add the tool with the permission, or record a deliberate omission in `upstream:` in `flatpark.yml` with a comment saying why.',
    '',
    'This issue closes itself once the manifests agree.',
  ].join('\n');
}

function writeText(apps) {
  if (!apps.length) {
    process.stdout.write('no package names an upstream manifest\n');
    return;
  }
  for (const app of apps) {
    if (!drifted(app)) {
      process.stdout.write(`ok ${app.id}\n`);
      continue;
    }
    process.stdout.write(`drift ${app.id}\n`);
    if (app.error) process.stdout.write(`  error ${app.error}\n`);
    for (const item of app.missingPermissions) process.stdout.write(`  missing-permission ${item}\n`);
    for (const item of app.extraPermissions) process.stdout.write(`  extra-permission ${item}\n`);
    for (const item of app.missingModules) process.stdout.write(`  missing-module ${item}\n`);
    for (const item of app.extraModules) process.stdout.write(`  extra-module ${item}\n`);
    for (const change of app.sourceChanges) {
      process.stdout.write(`  module-source ${change.module}\n`);
      process.stdout.write(`    ours ${change.ours.join(' ') || '(none)'}\n`);
      process.stdout.write(`    upstream ${change.upstream.join(' ') || '(none)'}\n`);
    }
  }
}

function runAlert(command, key, title, body) {
  const script = join(ROOT, 'scripts/ci-alert.sh');
  const result = spawnSync('bash', [script, command, key, title], {
    input: body,
    encoding: 'utf8',
  });
  if (result.status !== 0) {
    process.stderr.write(result.stderr || result.stdout || `${command} ${key} failed\n`);
    return false;
  }
  return true;
}

function parseArgs(argv) {
  const opts = { registry: join(ROOT, 'registry'), app: '', upstreamFile: '', alert: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--alert') opts.alert = true;
    else if (arg === '--registry') opts.registry = argv[++i];
    else if (arg === '--app') opts.app = argv[++i];
    else if (arg === '--upstream-file') opts.upstreamFile = argv[++i];
    else {
      process.stderr.write(`unknown argument: ${arg}\n`);
      process.exit(2);
    }
  }
  if (opts.upstreamFile && !opts.app) {
    process.stderr.write('--upstream-file requires --app\n');
    process.exit(2);
  }
  if (!opts.registry) {
    process.stderr.write('missing registry path\n');
    process.exit(2);
  }
  return opts;
}

const opts = parseArgs(process.argv.slice(2));
const ids = readdirSync(opts.registry, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .filter((id) => !opts.app || id === opts.app)
  .sort();

const checked = [];
for (const id of ids) {
  const descriptorPath = join(opts.registry, id, 'flatpark.yml');
  if (!existsSync(descriptorPath)) continue;
  const descriptor = parseDescriptor(readFileSync(descriptorPath, 'utf8'));
  if (!descriptor.upstreamManifest) continue;

  const app = emptyApp(id);
  const oursPath = join(opts.registry, id, descriptor.manifest);
  let oursText = '';
  let upstreamText = '';
  try {
    if (!descriptor.manifest || !existsSync(oursPath)) throw new Error(`package manifest not found: ${descriptor.manifest || '(missing build.manifest)'}`);
    oursText = readFileSync(oursPath, 'utf8');
    if (opts.upstreamFile) upstreamText = readFileSync(opts.upstreamFile, 'utf8');
    else {
      const url = githubContentsUrl(descriptor.sourceUrl, descriptor.upstreamManifest);
      if (!url) throw new Error(`source_url is not a github.com repository: ${descriptor.sourceUrl}`);
      upstreamText = await fetchText(url);
    }
  } catch (error) {
    app.error = error.message || String(error);
    checked.push({ app, descriptor });
    continue;
  }

  const ours = parseManifest(oursText);
  const upstream = parseManifest(upstreamText);
  if (!upstream.finish.length && !upstream.modules.length) {
    app.error = 'upstream manifest has no finish-args and no modules';
    checked.push({ app, descriptor });
    continue;
  }
  const permissions = diffLists(
    ours.finish,
    upstream.finish,
    descriptor.acceptMissingPermissions,
    descriptor.acceptExtraPermissions,
  );
  const modules = diffLists(
    ours.modules.map((mod) => mod.name),
    upstream.modules.map((mod) => mod.name),
    descriptor.acceptMissingModules,
    descriptor.acceptExtraModules,
  );
  app.missingPermissions = permissions.missing;
  app.extraPermissions = permissions.extra;
  app.missingModules = modules.missing;
  app.extraModules = modules.extra;
  app.sourceChanges = sourceChanges(ours.modules, upstream.modules);
  checked.push({ app, descriptor });
}

writeText(checked.map((item) => item.app));

if (opts.alert) {
  let ok = true;
  for (const { app, descriptor } of checked) {
    const key = `upstream-manifest/${app.id}`;
    const title = `upstream manifest: ${app.id} differs from its Flatpak manifest`;
    if (drifted(app)) ok = runAlert('sync', key, title, alertBody(app, descriptor)) && ok;
    else ok = runAlert('resolve', key, `The Flatpak manifest for ${app.id} matches upstream again.`) && ok;
  }
  process.exit(ok ? 0 : 1);
}

process.exit(checked.some((item) => drifted(item.app)) ? 1 : 0);
