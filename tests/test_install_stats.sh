#!/usr/bin/env bash
# Install stats end to end, minus Cloudflare: the Worker's counting rule, the
# daily rollup (backfill, registry filter, idempotence, 30-day window), and
# enrich carrying the totals into the app JSON.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_install_stats: SKIP (no node)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# --- Worker: what counts, and the request always reaches the origin --------
cp "$ROOT/workers/install-stats/src/index.js" "$tmp/worker.mjs"
cat > "$tmp/worker_test.mjs" <<'EOF'
import assert from 'node:assert/strict';
import worker, { dataPoint } from './worker.mjs';

const req = (headers, method = 'GET') =>
  new Request('https://dl.flatpark.org/delta-indexes/ab/cd.index', { method, headers });
const ref = 'app/io.flatpark.TestOne/x86_64/stable';

assert.deepEqual(dataPoint(req({ 'Flatpak-Ref': ref })).blobs, ['io.flatpark.TestOne', 'install', 'x86_64', 'stable', '']);
assert.equal(dataPoint(req({ 'Flatpak-Ref': ref, 'Flatpak-Upgrade-From': 'c3e1' })).blobs[1], 'update');
assert.deepEqual(dataPoint(req({ 'Flatpak-Ref': ref })).indexes, ['io.flatpark.TestOne']);
// appstream refreshes ride along on every `flatpak update`; never an app pull
assert.equal(dataPoint(req({ 'Flatpak-Ref': 'appstream2/x86_64' })), null);
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
cat > "$fixture/2026-10-01.json" <<'EOF'
{"data":[{"id":"io.flatpark.TestOne","kind":"install","n":"3"},
         {"id":"io.flatpark.TestOne","kind":"update","n":2},
         {"id":"io.example.Spoofed","kind":"install","n":50}]}
EOF
cat > "$fixture/2026-10-03.json" <<'EOF'
{"data":[{"id":"io.flatpark.TestTwo","kind":"install","n":4}]}
EOF
stats="$tmp/stats"; mkdir -p "$stats/daily"
# An old day from before the backfill window stays in the totals (it is the
# only record once Analytics Engine has forgotten it) but not in the 30 days.
echo '{"date":"2026-08-01","apps":{"io.flatpark.TestOne":{"installs":10,"updates":0}}}' > "$stats/daily/2026-08-01.json"

rollup() {
    STATS_DIR="$stats" REGISTRY_DIR="$registry" STATS_SQL_FIXTURE="$fixture" STATS_TODAY=2026-10-04 \
        node "$ROOT/scripts/rollup-install-stats.mjs" >/dev/null
}
rollup
# backfill: the 7 finished days before "today", and not today itself
assert_file "$stats/daily/2026-09-27.json"
assert_file "$stats/daily/2026-10-03.json"
[ ! -e "$stats/daily/2026-10-04.json" ] || { echo "FAIL rolled up an unfinished day"; exit 1; }
assert_contains "$stats/daily/2026-10-01.json" '"io.flatpark.TestOne":{"installs":3,"updates":2}'
if grep -q Spoofed "$stats/daily/2026-10-01.json"; then echo "FAIL kept an id not in the registry"; exit 1; fi

check_totals() {
    node -e '
      const t = require(process.argv[1]);
      const a = require("node:assert/strict");
      a.equal(t.since, "2026-08-01");
      a.equal(t.through, "2026-10-03");
      a.deepEqual(t.apps["io.flatpark.TestOne"], { installs: 13, updates: 2, installs30: 3, updates30: 2 });
      a.deepEqual(t.apps["io.flatpark.TestTwo"], { installs: 4, updates: 0, installs30: 4, updates30: 0 });
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
      a.deepEqual(require(process.argv[1]).installs, { total: 13, last30: 3, since: "2026-08-01" });
      // listed after the last rollup: zero, not missing
      a.deepEqual(require(process.argv[2]).installs, { total: 0, last30: 0, since: "2026-08-01" });
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
    assert_ok node -e 'require("node:assert/strict").equal(require(process.argv[1]).installs, undefined)' \
        "$fresh/apps/io.flatpark.TestOne.json"
fi

echo "test_install_stats: ok"
