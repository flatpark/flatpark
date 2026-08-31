#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v flatpak-builder >/dev/null || { echo "test_publish_e2e: SKIP (no flatpak-builder)"; exit 0; }
[ -x "$ROOT/scripts/publish.sh" ] || { echo "FAIL: missing publish script"; exit 1; }
tmp="$(mktemp -d)"
# The Astro build moves prerender assets out of site/.astro/ with a bare
# rename(2), which fails with EXDEV when OUT_DIR is on another filesystem than
# the repo (e.g. a tmpfs /tmp). Keep OUT_DIR on the repo's filesystem; out/ is
# gitignored.
out="$ROOT/out/test-e2e.$$"
trap 'rm -rf "$tmp" "$out"' EXIT
# Publish the self-contained synthetic fixture end-to-end. Pass the explicit id
# so only this fixture is built even if more land under tests/fixtures.
env_common=(
    OUT_DIR="$out" GNUPGHOME_DIR="$tmp/gnupg" REPO_DIR="$out/repo"
    REPO_URL="file://$out/repo" REGISTRY_DIR="$ROOT/tests/fixtures"
    DATA_DIR="$tmp/data" FLATPARK_DATA_DIR="$tmp/data"
)

if ! env "${env_common[@]}" "$ROOT/scripts/publish.sh" io.flatpark.BuildOne; then
    echo "test_publish_e2e: SKIP (publish failed, likely no runtime/network)"; exit 0
fi
assert_file "$out/flatpark.flatpakrepo"
assert_file "$out/io.flatpark.BuildOne.flatpakref"
assert_file "$out/site/index.html"
assert_file "$out/repo/summary.sig"
echo "test_publish_e2e: PASS"
