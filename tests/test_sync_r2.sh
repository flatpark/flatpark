#!/usr/bin/env bash
# sync-r2.sh against a stub rclone that only logs its arguments: which uploads
# get which Cache-Control, how they compare, and that REWRITE_HEADERS=1 forces
# the mutable files (and only those) up again.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/repo/objects" "$tmp/repo/refs" "$tmp/repo/summaries"
cat > "$tmp/bin/rclone" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$RCLONE_LOG"
EOF
chmod +x "$tmp/bin/rclone"

run() {   # <log> [env...]
    local log="$1"; shift
    : > "$log"
    env PATH="$tmp/bin:$PATH" RCLONE_LOG="$log" R2_BUCKET=b "$@" \
        "$ROOT/scripts/sync-r2.sh" "$tmp/repo" >/dev/null 2>&1
}
mutable()   { grep -F 's-maxage=60' "$1"; }
immutable() { grep -F 'immutable' "$1"; }

# Default publish: mutable files compared by content, edge-cacheable 60 s.
run "$tmp/default.log"
assert_eq "$(mutable "$tmp/default.log" | wc -l | tr -d ' ')" 6
assert_eq "$(mutable "$tmp/default.log" | grep -vc -- '--checksum' || true)" 0
assert_eq "$(grep -c -- '--ignore-times' "$tmp/default.log" || true)" 0
assert_eq "$(mutable "$tmp/default.log" | grep -c 'max-age=0, s-maxage=60, must-revalidate')" 6
# Content-addressed objects keep the year-long header and the size check.
assert_eq "$(immutable "$tmp/default.log" | grep -vc -- '--size-only' || true)" 0
assert_ok grep -qF -- '--exclude *.commitmeta' "$tmp/default.log"
# summary.idx still goes up strictly last.
assert_contains <(tail -n1 "$tmp/default.log") '--include summary.idx'

# REWRITE_HEADERS=1: every mutable upload ignores times, objects untouched.
run "$tmp/rewrite.log" REWRITE_HEADERS=1
assert_eq "$(mutable "$tmp/rewrite.log" | grep -vc -- '--ignore-times' || true)" 0
assert_eq "$(mutable "$tmp/rewrite.log" | grep -c -- '--checksum' || true)" 0
assert_eq "$(immutable "$tmp/rewrite.log")" "$(immutable "$tmp/default.log")"

echo "test_sync_r2: PASS"
