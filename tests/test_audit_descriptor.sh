#!/usr/bin/env bash
# Tests for scripts/audit-descriptor.mjs — the review-bar guardrails.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
AUDIT="node $ROOT/scripts/audit-descriptor.mjs"
F="$ROOT/tests/fixtures/audit"

# G1: a fully-pinned descriptor passes (exit 0)
$AUDIT "$F/good/flatpark.yml" >/dev/null 2>&1
assert_eq "$?" "0"

# G1: extra-data without sha256 hard-fails (exit 1, FAIL line)
out="$($AUDIT "$F/bad-unpinned/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "1"
printf '%s' "$out" | grep -qF "FAIL:" || { echo "FAIL: expected FAIL line for unpinned"; exit 1; }

# G2(a): escape permission hard-fails and names the perm
out="$($AUDIT "$F/bad-escape/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "1"
printf '%s' "$out" | grep -qF "filesystem=host" || { echo "FAIL: escape perm not reported"; exit 1; }

# update.command must be a simple relative script path
out="$($AUDIT "$F/bad-updatecmd/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "1"
printf '%s' "$out" | grep -qiF "update.command" || { echo "FAIL: update.command not reported"; exit 1; }

# G3: runtime npm install warns but does NOT fail (exit 0, WARN line)
out="$($AUDIT "$F/warn-runtimefetch/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "0"
printf '%s' "$out" | grep -qF "WARN:" || { echo "FAIL: expected WARN line for runtime fetch"; exit 1; }

# Regression: every shipping registry app must pass (no hard fail)
for d in "$ROOT"/registry/*/flatpark.yml; do
  $AUDIT "$d" >/dev/null 2>&1 || { echo "FAIL: audit hard-failed on shipping app $d"; $AUDIT "$d"; exit 1; }
done

echo "ok test_audit_descriptor"
