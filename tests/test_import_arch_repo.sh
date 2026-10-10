#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v ostree >/dev/null || { echo "test_import_arch_repo: SKIP (no ostree)"; exit 0; }
command -v flatpak >/dev/null || { echo "test_import_arch_repo: SKIP (no flatpak)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
env_common=(OUT_DIR="$tmp/out" GNUPGHOME_DIR="$tmp/gnupg" REPO_DIR="$tmp/repo")
env "${env_common[@]}" "$ROOT/scripts/gen-signing-key.sh" >/dev/null

# The hand-over repo an arm runner produces: an aarch64 app ref carrying its
# metadata (where extra-data sources live) plus a per-repo appstream ref that
# must not be imported.
src="$tmp/src"
ostree --repo="$src" init --mode=archive-z2
ostree --repo="$tmp/repo" init --mode=archive-z2
mkdir -p "$tmp/tree/files"; echo hi > "$tmp/tree/files/x"
printf '[Application]\nname=test.App\n' > "$tmp/tree/metadata"
ostree --repo="$src" commit --branch=app/test.App/aarch64/stable --subject=t \
    --add-metadata-string=xa.metadata="marker" "$tmp/tree" >/dev/null
ostree --repo="$src" commit --branch=appstream/aarch64 --subject=t "$tmp/tree" >/dev/null

env "${env_common[@]}" "$ROOT/scripts/import-arch-repo.sh" "$src" 2>/dev/null
assert_eq "$(ostree --repo="$tmp/repo" refs)" "app/test.App/aarch64/stable"
assert_eq "$(ostree --repo="$tmp/repo" show --print-metadata-key=xa.metadata app/test.App/aarch64/stable)" "'marker'"
# Signed with the FlatPark key: the commit verifies against it.
ostree --repo="$tmp/repo" show app/test.App/aarch64/stable | grep -q "Found 1 signature" \
    || { echo "FAIL: imported commit is not signed"; exit 1; }

# The summary then covers it, like any locally built ref.
env "${env_common[@]}" "$ROOT/scripts/publish-repo.sh" "$tmp/repo" 2>/dev/null
assert_file "$tmp/repo/summary.sig"

# An empty hand-over is an error, not a silent no-op.
ostree --repo="$tmp/empty" init --mode=archive-z2
if env "${env_common[@]}" "$ROOT/scripts/import-arch-repo.sh" "$tmp/empty" 2>/dev/null; then
    echo "FAIL: empty source repo accepted"; exit 1
fi
echo "test_import_arch_repo: PASS"
