#!/usr/bin/env bash
# Install stats end to end, minus Cloudflare: the Worker's counting rule, the
# daily rollup (backfill, registry filter, idempotence, 30-day window,
# per-commit pulls next to pre-commit rows), and enrich carrying the totals
# into the app JSON.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_install_stats: SKIP (no node)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# --- Worker: what counts, and the request always reaches the origin --------
cp "$ROOT/workers/install-stats/src/index.js" "$tmp/worker.mjs"
cat > "$tmp/worker_test.mjs" <<'EOF'
import assert from 'node:assert/strict';
import worker, { dataPoint, targetCommit } from './worker.mjs';

// A real delta-index request from a flatpak 1.18 install, and its commit.
const IDX = '/delta-indexes/Cb/qGGDw4J2ct7JvNJcT0SwQIldtLV6RSrAFrUIlZcIs.index';
const COMMIT = '09ba86183c3827672dec9bcd25c4f44b040895db4b57a452ac016b508959708b';
const req = (headers, method = 'GET', path = IDX) =>
  new Request(`https://dl.flatpark.org${path}`, { method, headers });
const ref = 'app/io.flatpark.TestOne/x86_64/stable';

assert.equal(targetCommit(IDX), COMMIT);
assert.equal(targetCommit('/delta-indexes/w+/H4frjv4Kdl95NcGSREShAwU5V416qTfAL1tOjAOYA.index'),
  'c3e1f87eb8efe0a765f7935c1924444a1030539578d7aa937c02f5b4e8c03980');
assert.equal(targetCommit('/delta-indexes/ab/cd.index'), '');
// blob order is the SQL schema; blob6 (commit) and blob7–15 were appended, never inserted
const FROM = 'c3e1f87eb8efe0a765f7935c1924444a1030539578d7aa937c02f5b4e8c03980';
const flatpak = { 'User-Agent': 'libostree/2026.4 flatpak/1.18.4', 'Flatpak-Os-Info': 'debian;unknown;x86_64' };
assert.deepEqual(dataPoint(req({ 'Flatpak-Ref': ref })).blobs,
  ['io.flatpark.TestOne', 'install', 'x86_64', 'stable', '', COMMIT, '', '', '', '', '', '', '', '', '']);
assert.deepEqual(dataPoint(req({ ...flatpak, 'Flatpak-Ref': ref, 'Flatpak-Upgrade-From': FROM }), 200).blobs,
  ['io.flatpark.TestOne', 'update', 'x86_64', 'stable', '', COMMIT, FROM, '1.18.4', '2026.4', 'debian', 'unknown', 'x86_64', '', '', '200']);
// a path that is not a delta index still counts, just without a version
assert.equal(dataPoint(req({ 'Flatpak-Ref': ref }, 'GET', '/delta-indexes/ab/cd.index')).blobs[5], '');
// any Upgrade-From makes it an update; only a real commit is kept
assert.equal(dataPoint(req({ 'Flatpak-Ref': ref, 'Flatpak-Upgrade-From': 'c3e1' })).blobs[1], 'update');
assert.equal(dataPoint(req({ 'Flatpak-Ref': ref, 'Flatpak-Upgrade-From': 'c3e1' })).blobs[6], '');
// client-sent values are reduced to short tokens, never stored as sent
const odd = dataPoint(req({ 'Flatpak-Ref': ref, 'User-Agent': 'curl/8.0', 'Flatpak-Os-Info': 'my distro;<b>;' + 'x'.repeat(40) })).blobs;
assert.deepEqual(odd.slice(7, 12), ['', '', '', '', '']);
assert.deepEqual(dataPoint(req({ 'Flatpak-Ref': ref })).indexes, ['io.flatpark.TestOne']);
// appstream refreshes ride along on every `flatpak update`: kept under their own id
assert.deepEqual(dataPoint(req({ ...flatpak, 'Flatpak-Ref': 'appstream2/x86_64' })).blobs.slice(0, 4), ['appstream2', 'install', 'x86_64', '']);
assert.equal(dataPoint(req({ 'Flatpak-Ref': 'appstream/x86_64' })), null);
// a refresh of an already-current appstream still pulls the index: from == commit
assert.equal(dataPoint(req({ 'Flatpak-Ref': 'appstream2/x86_64', 'Flatpak-Upgrade-From': COMMIT })).blobs[6], COMMIT);
assert.equal(dataPoint(req({ 'Flatpak-Ref': 'runtime/org.example.Platform/x86_64/1' })), null);
assert.equal(dataPoint(req({})), null);
assert.equal(dataPoint(req({ 'Flatpak-Ref': 'app/../x86_64/stable' })), null);
assert.equal(dataPoint(req({ 'Flatpak-Ref': ref }, 'HEAD')), null);

// Pass-through: the origin's response comes back untouched, counted or not,
// and a broken binding never fails the pull.
const origin = new Response('idx', { status: 404 });
globalThis.fetch = async () => origin;
const points = [];
let res = await worker.fetch(req({ 'Flatpak-Ref': ref }), { INSTALLS: { writeDataPoint: (p) => points.push(p) } });
assert.equal(res, origin);
assert.equal(points.length, 1);
assert.equal(points[0].blobs[14], '404');
res = await worker.fetch(req({ 'Flatpak-Ref': ref }), { INSTALLS: { writeDataPoint() { throw new Error('down'); } } });
assert.equal(res, origin);
EOF
node "$tmp/worker_test.mjs" 2>/dev/null >/dev/null || { node "$tmp/worker_test.mjs"; echo "FAIL worker"; exit 1; }

# --- Rollup ----------------------------------------------------------------
registry="$tmp/registry"
for id in io.flatpark.TestOne io.flatpark.TestTwo; do
    mkdir -p "$registry/$id"; echo "id: $id" > "$registry/$id/flatpark.yml"
done
fixture="$tmp/sql"; mkdir -p "$fixture"
A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
C=cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
# 10-01: rows from before the Worker recorded the commit ("" — what Analytics
# Engine returns for a blob that was never written).
cat > "$fixture/2026-10-01.json" <<'EOF'
{"data":[{"id":"io.flatpark.TestOne","kind":"install","commit":"","n":"3"},
         {"id":"io.flatpark.TestOne","kind":"update","commit":"","n":2},
         {"id":"io.example.Spoofed","kind":"install","commit":"","n":50}]}
EOF
# 10-02: version A goes out; 10-03: version B replaces it, half-adopted so far,
# and the aarch64 build (its own ref, so its own commit C) gets two installs.
# Rows with no arch read as x86_64.
cat > "$fixture/2026-10-02.json" <<EOF
{"data":[{"id":"io.flatpark.TestOne","kind":"install","arch":"x86_64","commit":"$A","n":1},
         {"id":"io.flatpark.TestOne","kind":"update","commit":"$A","n":4}]}
EOF
cat > "$fixture/2026-10-03.json" <<EOF
{"data":[{"id":"io.flatpark.TestOne","kind":"update","arch":"x86_64","commit":"$B","n":2},
         {"id":"io.flatpark.TestOne","kind":"install","arch":"x86_64","commit":"$B","n":1},
         {"id":"io.flatpark.TestOne","kind":"install","arch":"aarch64","commit":"$C","n":2},
         {"id":"io.flatpark.TestTwo","kind":"install","commit":"","n":4}]}
EOF
stats="$tmp/stats"; mkdir -p "$stats/daily"
# An old day from before the backfill window stays in the totals (it is the
# only record once Analytics Engine has forgotten it) but not in the 30 days.
echo '{"date":"2026-08-01","apps":{"io.flatpark.TestOne":{"installs":10,"updates":0}}}' > "$stats/daily/2026-08-01.json"
# Version A was first pulled long ago: all its pulls count toward `active`
# because it was still pulled inside the last 30 days. This day file predates
# per-arch commits, so its flat map reads as x86_64.
echo "{\"date\":\"2026-08-20\",\"apps\":{\"io.flatpark.TestOne\":{\"installs\":0,\"updates\":7,\"commits\":{\"$A\":7}}}}" > "$stats/daily/2026-08-20.json"

rollup() {
    STATS_DIR="$stats" REGISTRY_DIR="$registry" STATS_SQL_FIXTURE="$fixture" STATS_TODAY=2026-10-04 \
        node "$ROOT/scripts/rollup-install-stats.mjs" >/dev/null
}
rollup
# backfill: the 7 finished days before "today", and not today itself
assert_file "$stats/daily/2026-09-27.json"
assert_file "$stats/daily/2026-10-03.json"
[ ! -e "$stats/daily/2026-10-04.json" ] || { echo "FAIL rolled up an unfinished day"; exit 1; }
# pre-commit rows: counted, but no commits map
assert_contains "$stats/daily/2026-10-01.json" '"io.flatpark.TestOne":{"installs":3,"updates":2}}'
assert_contains "$stats/daily/2026-10-02.json" "\"io.flatpark.TestOne\":{\"installs\":1,\"updates\":4,\"commits\":{\"x86_64\":{\"$A\":5}}}"
assert_contains "$stats/daily/2026-10-03.json" "\"commits\":{\"x86_64\":{\"$B\":3},\"aarch64\":{\"$C\":2}}"
if grep -q Spoofed "$stats/daily/2026-10-01.json"; then echo "FAIL kept an id not in the registry"; exit 1; fi

check_totals() {
    node -e '
      const t = require(process.argv[1]);
      const a = require("node:assert/strict");
      a.equal(t.since, "2026-08-01");
      a.equal(t.through, "2026-10-03");
      // active, per arch then summed: x86_64 A has 7 (08-20) + 5 (10-02) = 12
      // pulls (B only 3 so far), aarch64 C has 2 -> 14
      a.deepEqual(t.apps["io.flatpark.TestOne"],
        { installs: 17, updates: 15, installs30: 7, updates30: 8, downloads: 32, active: 14 });
      // only pre-commit rows: no version to place them on, so no estimate
      a.deepEqual(t.apps["io.flatpark.TestTwo"],
        { installs: 4, updates: 0, installs30: 4, updates30: 0, downloads: 4, active: null });
      a.equal(Object.keys(t.apps).length, 2);
    ' "$stats/totals.json"
}
assert_ok check_totals
# Idempotent: a second run (same day, or a retried workflow) adds nothing.
rollup
assert_ok check_totals

# --- enrich carries the totals into the app JSON ---------------------------
if [ -d "$ROOT/site/node_modules/yaml" ] && [ -d "$ROOT/site/node_modules/sharp" ]; then
    data="$tmp/data"; mkdir -p "$data/apps"
    for id in io.flatpark.TestOne io.flatpark.Fresh; do
        printf '{"id":"%s","name":"%s","summary":"s","permissions":[],"screenshots":[]}\n' "$id" "$id" > "$data/apps/$id.json"
    done
    ( cd "$ROOT/site" && FLATPARK_DATA_DIR="$data" FLATPARK_ALLOW_SHALLOW=1 FLATPARK_STATS_URL="$stats/totals.json" \
        node tools/enrich.mjs >/dev/null 2>&1 )
    assert_ok node -e '
      const a = require("node:assert/strict");
      a.deepEqual(require(process.argv[1]).stats, { downloads: 32, installs30: 7, active: 14, since: "2026-08-01" });
      // listed after the last rollup: zero, not missing
      a.deepEqual(require(process.argv[2]).stats, { downloads: 0, installs30: 0, active: null, since: "2026-08-01" });
    ' "$data/apps/io.flatpark.TestOne.json" "$data/apps/io.flatpark.Fresh.json"
    # unreachable stats never fail the build
    ( cd "$ROOT/site" && FLATPARK_DATA_DIR="$data" FLATPARK_ALLOW_SHALLOW=1 FLATPARK_STATS_URL="$tmp/missing.json" \
        node tools/enrich.mjs >/dev/null 2>&1 )
    # Rolled up but nothing counted yet (since: null): no install field at all,
    # rather than a 0 on every app.
    fresh="$tmp/fresh"; mkdir -p "$fresh/apps"
    printf '{"id":"io.flatpark.TestOne","name":"T","summary":"s","permissions":[],"screenshots":[]}\n' > "$fresh/apps/io.flatpark.TestOne.json"
    echo '{"since":null,"through":"2026-10-03","apps":{}}' > "$tmp/empty.json"
    ( cd "$ROOT/site" && FLATPARK_DATA_DIR="$fresh" FLATPARK_ALLOW_SHALLOW=1 FLATPARK_STATS_URL="$tmp/empty.json" \
        node tools/enrich.mjs >/dev/null 2>&1 )
    assert_ok node -e 'require("node:assert/strict").equal(require(process.argv[1]).stats, undefined)' \
        "$fresh/apps/io.flatpark.TestOne.json"
fi

echo "test_install_stats: ok"
