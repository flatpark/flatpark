#!/usr/bin/env node
// Roll the install-stats Worker's Analytics Engine rows up into the public,
// durable aggregates served from dl.flatpark.org/stats/:
//
//   daily/<YYYY-MM-DD>.json  {date, apps: {<id>: {installs, updates, commits?}}}
//   totals.json              {generated, since, through,
//                             apps: {<id>: {installs, updates, installs30, updates30,
//                                           downloads, active}}}
//
// `commits` maps each pulled commit to its pulls (installs + updates) that day.
// It is absent on days, and for rows, from before the Worker recorded the
// commit (2026-10-04) — those still count toward installs/updates/downloads,
// they just cannot place a pull on a version.
//
// `downloads` is every pull, installs + updates. `active` estimates how many
// installations are in use: the repo keeps one version per ref, so each
// installation pulls a given commit once, and pulls of one commit ≈
// installations that reached it. A version released yesterday has not been
// pulled by everyone yet, so `active` is the most-pulled commit among those
// pulled in the last 30 days, counting each such commit's pulls on every day
// it was ever pulled. It is null until the app has any commit-tagged pull.
// Installations that never update are invisible to it, so it is a floor.
//
// Analytics Engine keeps rows for three months, so the daily files are the
// record. The script works on a local mirror of stats/ (the workflow syncs it
// from R2 and back): it writes a daily file for every finished UTC day in the
// backfill window that does not have one yet — a missed run heals itself on
// the next — and then recomputes totals.json from all daily files, so running
// it twice never double-counts.
//
// Only ids that are in the registry right now are kept. Flatpak-Ref is a
// client-sent header, so anything else is noise (or someone typing curl), and
// a de-listed app drops out of the totals with its directory.
//
// Env: STATS_DIR (local stats/ mirror), REGISTRY_DIR, CF_ACCOUNT_ID,
// CF_ANALYTICS_TOKEN. Tests: STATS_TODAY (UTC date that counts as today),
// STATS_SQL_FIXTURE (dir of <date>.json SQL responses, used instead of the API).
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const DATASET = 'flatpark_installs';
const BACKFILL_DAYS = 7;

const statsDir = process.env.STATS_DIR || 'stats';
const registryDir = process.env.REGISTRY_DIR || 'registry';
const dailyDir = join(statsDir, 'daily');

const day = (d) => d.toISOString().slice(0, 10);
const addDays = (date, n) => {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return day(d);
};
const today = process.env.STATS_TODAY || day(new Date());

const known = new Set(
  readdirSync(registryDir, { withFileTypes: true })
    .filter((e) => e.isDirectory() && existsSync(join(registryDir, e.name, 'flatpark.yml')))
    .map((e) => e.name),
);

async function query(date) {
  const fixture = process.env.STATS_SQL_FIXTURE;
  if (fixture) {
    const f = join(fixture, `${date}.json`);
    return existsSync(f) ? JSON.parse(readFileSync(f, 'utf8')) : { data: [] };
  }
  const account = process.env.CF_ACCOUNT_ID;
  const token = process.env.CF_ANALYTICS_TOKEN;
  if (!account || !token) throw new Error('set CF_ACCOUNT_ID and CF_ANALYTICS_TOKEN');
  // _sample_interval: Analytics Engine may sample under load; each row then
  // stands for that many points, so it is summed rather than counted.
  // blob6 (commit) reads back as "" on rows written before it existed.
  const sql = `SELECT blob1 AS id, blob2 AS kind, blob6 AS commit, SUM(_sample_interval) AS n
FROM ${DATASET}
WHERE timestamp >= toDateTime('${date} 00:00:00')
  AND timestamp < toDateTime('${addDays(date, 1)} 00:00:00')
GROUP BY id, kind, commit
FORMAT JSON`;
  const res = await fetch(`https://api.cloudflare.com/client/v4/accounts/${account}/analytics_engine/sql`, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}` },
    body: sql,
  });
  if (!res.ok) throw new Error(`SQL API ${res.status} for ${date}: ${(await res.text()).slice(0, 300)}`);
  return res.json();
}

function toDaily(date, result) {
  const apps = {};
  for (const row of result.data ?? []) {
    if (!known.has(row.id)) continue;
    const key = row.kind === 'update' ? 'updates' : row.kind === 'install' ? 'installs' : null;
    if (!key) continue;
    const n = Number(row.n) || 0;
    const a = (apps[row.id] ??= { installs: 0, updates: 0 });
    a[key] += n;
    if (/^[0-9a-f]{64}$/.test(row.commit ?? '')) {
      a.commits ??= {};
      a.commits[row.commit] = (a.commits[row.commit] ?? 0) + n;
    }
  }
  return { date, apps };
}

mkdirSync(dailyDir, { recursive: true });
let written = 0;
for (let date = addDays(today, -BACKFILL_DAYS); date < today; date = addDays(date, 1)) {
  const file = join(dailyDir, `${date}.json`);
  if (existsSync(file)) continue;
  writeFileSync(file, JSON.stringify(toDaily(date, await query(date))) + '\n');
  written += 1;
}

const dailies = readdirSync(dailyDir)
  .filter((f) => /^\d{4}-\d{2}-\d{2}\.json$/.test(f))
  .sort()
  .map((f) => JSON.parse(readFileSync(join(dailyDir, f), 'utf8')));
const recentFrom = addDays(today, -30);
const apps = {};
const pulls = {}; // id -> commit -> pulls, all time
const recent = {}; // id -> commits pulled in the last 30 days
let since = null;
for (const d of dailies) {
  for (const [id, c] of Object.entries(d.apps)) {
    if (!known.has(id)) continue;
    if (c.installs || c.updates) since ??= d.date;
    const a = (apps[id] ??= { installs: 0, updates: 0, installs30: 0, updates30: 0 });
    a.installs += c.installs;
    a.updates += c.updates;
    if (d.date >= recentFrom) {
      a.installs30 += c.installs;
      a.updates30 += c.updates;
    }
    for (const [commit, n] of Object.entries(c.commits ?? {})) {
      (pulls[id] ??= {})[commit] = (pulls[id][commit] ?? 0) + n;
      if (d.date >= recentFrom) (recent[id] ??= new Set()).add(commit);
    }
  }
}
for (const [id, a] of Object.entries(apps)) {
  a.downloads = a.installs + a.updates;
  const seen = [...(recent[id] ?? [])];
  a.active = seen.length ? Math.max(...seen.map((c) => pulls[id][c])) : null;
}
const totals = {
  generated: new Date().toISOString(),
  since,
  through: dailies.at(-1)?.date ?? null,
  apps: Object.fromEntries(Object.entries(apps).sort(([a], [b]) => a.localeCompare(b))),
};
writeFileSync(join(statsDir, 'totals.json'), JSON.stringify(totals, null, 2) + '\n');
console.log(`[stats] wrote ${written} new day(s); totals cover ${Object.keys(apps).length} app(s) through ${totals.through}`);
