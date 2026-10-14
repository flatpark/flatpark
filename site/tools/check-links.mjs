// Batch-check the external URLs the site hotlinks (screenshots, homepage,
// help, license, source). Reads enriched apps/<id>.json from the data dir.
// LINK_CHECK_EXTRA_DATA names a TSV of extra-data pins (app, url, size), one
// per line, which scripts/check-links.sh lists from the manifests: each must
// answer and still be the pinned size, or installs of that app fail.
// Human summary by default, --json for machine output. Exits 1 if any link
// is broken so CI / a remediation job can act on it. LINK_CHECK_JSON_OUT also
// writes the JSON report to that file, next to the human summary — the
// workflows want both, and stdout is shared with the data regeneration.
import { readFileSync, readdirSync, existsSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const dataDir = process.env.FLATPARK_DATA_DIR || 'public';
const appsDir = join(dataDir, 'apps');
const asJson = process.argv.includes('--json');
const CONCURRENCY = Number(process.env.LINK_CHECK_CONCURRENCY || 8);
const TIMEOUT = Number(process.env.LINK_CHECK_TIMEOUT_MS || 10000);

// Errors that prove the host is live and reachable in a real browser, but that
// Node's stricter fetch/OpenSSL policy refuses. These reach TLS handshake with a
// running server (a down host fails earlier with ENOTFOUND/ECONNREFUSED/timeout),
// so they are warnings, not broken links. Legacy renegotiation is the known case
// (some vendor sites still require it; browsers allow it).
const SOFT_OK_CODES = new Set(['ERR_SSL_UNSAFE_LEGACY_RENEGOTIATION_DISABLED']);

// Transport-level failures that say nothing about whether the URL exists: a
// connect timeout or a reset is a property of the path between this runner and
// the host, and the same URL routinely answers from another region. Retried
// with backoff before they are believed.
// UND_ERR_SOCKET is how undici surfaces a peer that closed the connection.
const NET_ERRORS = new Set([
  'timeout',
  'ETIMEDOUT',
  'ECONNRESET',
  'EAI_AGAIN',
  'UND_ERR_SOCKET',
  'UND_ERR_CONNECT_TIMEOUT',
]);
const RETRIES = Number(process.env.LINK_CHECK_RETRIES || 2);

// Hosts whose links are verified by hand and must not fail the build on a
// NET_ERRORS code — a vendor site that answers in a browser but is not
// consistently routable from GitHub's runners. Only transport errors are
// waived: an HTTP 404 or 500 from these hosts is still a broken link. The list
// is empty today; LINK_CHECK_SOFT_OK_HOSTS appends to it (used by the tests).
const SOFT_OK_HOSTS = new Set([
  ...(process.env.LINK_CHECK_SOFT_OK_HOSTS || '').split(',').filter(Boolean),
]);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function hostOf(url) {
  try {
    return new URL(url).hostname;
  } catch {
    return '';
  }
}

function collect() {
  const urls = [];
  if (!existsSync(appsDir)) return urls;
  for (const f of readdirSync(appsDir).filter((n) => n.endsWith('.json'))) {
    const app = JSON.parse(readFileSync(join(appsDir, f), 'utf8'));
    const add = (type, url) => {
      if (typeof url === 'string' && /^https?:\/\//.test(url)) urls.push({ app: app.id, type, url });
    };
    for (const s of app.screenshots || []) add('screenshot', s.remoteUrl || s.url);
    add('website', app.website);
    for (const [k, v] of Object.entries(app.urls || {})) add(`url:${k}`, v);
    if (app.license?.url) add('license', app.license.url);
    add('source', app.sourceUrl);
  }
  const pinsFile = process.env.LINK_CHECK_EXTRA_DATA;
  if (pinsFile && existsSync(pinsFile)) {
    for (const line of readFileSync(pinsFile, 'utf8').split('\n')) {
      const [app, url, size] = line.split('\t');
      if (app && /^https?:\/\//.test(url || '')) urls.push({ app, type: 'extra-data', url, size: Number(size) });
    }
  }
  const seen = new Set();
  return urls.filter((u) => {
    const k = `${u.app}|${u.type}|${u.url}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

async function request(method, url, headers) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT);
  try {
    return await fetch(url, { method, headers, redirect: 'follow', signal: ctrl.signal });
  } finally {
    clearTimeout(timer);
  }
}

// An extra-data pin is downloaded by flatpak itself, so nothing a browser
// would clear applies: a 403 is a failed install, and the payload must still be
// the size the manifest pins (flatpak checks it before the sha256), which also
// catches an upstream re-uploading different bytes under the same URL. Only the
// headers are read; a GET fallback is cancelled before the body comes down.
function judgePin(entry, res) {
  if (!res.ok) return { ...entry, status: res.status, ok: false };
  const len = res.headers.get('content-length');
  if (len !== null && entry.size && Number(len) !== entry.size) {
    return { ...entry, status: `size ${len}, pinned ${entry.size}`, ok: false };
  }
  return { ...entry, status: res.status, ok: true };
}

async function probe(entry) {
  try {
    // Prefer HEAD, but it is only a hint: plenty of servers and CDNs reject or
    // mishandle it (block hotlinking, 405/501, or answer a blanket 404/400 to
    // every HEAD while serving the same URL fine over GET — CodeBuddy's site
    // does exactly this). So on a missing HEAD or any non-2xx HEAD, confirm with
    // a GET before believing it. A genuinely dead URL still fails the GET.
    // fetch asks for gzip/br by default, and a CDN that compresses (jsDelivr)
    // then reports the compressed length; a pin is compared uncompressed.
    const headers = entry.type === 'extra-data' ? { 'accept-encoding': 'identity' } : undefined;
    let res = await request('HEAD', entry.url, headers).catch(() => null);
    if (!res || !res.ok) {
      res = await request('GET', entry.url, headers);
    }
    // A 403 that survives the GET fallback means the host answered but refuses
    // automated clients — Cloudflare-style bot/region gating that a real browser
    // clears (a dead host fails earlier with ENOTFOUND/ECONNREFUSED/timeout, and
    // often varies by the runner's region). Treat it as reachable-but-blocked for
    // informational links (website, docs, license), where the URL only has to
    // open in the user's browser. Keep it a hard failure for screenshots: those
    // are hotlinked into our own pages, so a 403 there is a genuinely broken
    // image, not a false positive.
    if (entry.type === 'extra-data') {
      const out = judgePin(entry, res);
      try { await res.body?.cancel(); } catch {}
      return out;
    }
    if (res.status === 403 && entry.type !== 'screenshot') {
      try { await res.body?.cancel(); } catch {}
      return { ...entry, status: 403, ok: true, warn: true };
    }
    const out = { ...entry, status: res.status, ok: res.ok };
    try { await res.body?.cancel(); } catch {}
    return out;
  } catch (e) {
    const error = e.name === 'AbortError' ? 'timeout' : (e.cause?.code || e.message);
    if (SOFT_OK_CODES.has(error)) return { ...entry, status: error, ok: true, warn: true };
    return { ...entry, status: 0, ok: false, error };
  }
}

async function check(entry) {
  let res = await probe(entry);
  for (let i = 1; i <= RETRIES && !res.ok && NET_ERRORS.has(res.error); i++) {
    await sleep(500 * 2 ** (i - 1));
    res = await probe(entry);
  }
  if (!res.ok && NET_ERRORS.has(res.error) && SOFT_OK_HOSTS.has(hostOf(entry.url))) {
    return { ...entry, status: res.error, ok: true, warn: true };
  }
  return res;
}

async function pool(items, n, fn) {
  const out = [];
  let i = 0;
  await Promise.all(
    Array.from({ length: Math.min(n, items.length) || 1 }, async () => {
      while (i < items.length) {
        const idx = i++;
        out[idx] = await fn(items[idx]);
      }
    }),
  );
  return out;
}

const entries = collect();
const results = await pool(entries, CONCURRENCY, check);
const broken = results.filter((r) => !r.ok);
const warned = results.filter((r) => r.warn);

const report = { checked: results.length, broken: broken.length, warned: warned.length, results };
if (process.env.LINK_CHECK_JSON_OUT) writeFileSync(process.env.LINK_CHECK_JSON_OUT, JSON.stringify(report, null, 2));
if (asJson) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(`[check-links] checked ${results.length} link(s)`);
  if (warned.length > 0) {
    console.log(`[check-links] ${warned.length} reachable but skipped (bot/region-gated or client TLS policy; OK in browsers):`);
    for (const w of warned) console.log(`  ~ ${w.app}  [${w.type}]  ${w.status}  ${w.url}`);
  }
  if (broken.length === 0) {
    console.log('[check-links] all links OK');
  } else {
    console.log(`[check-links] ${broken.length} broken:`);
    for (const b of broken) {
      console.log(`  x ${b.app}  [${b.type}]  ${b.status || b.error}  ${b.url}`);
    }
  }
}

process.exit(broken.length > 0 ? 1 : 0);
