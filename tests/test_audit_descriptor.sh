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

# Catalog icon: the site only picks up <id>.svg|png, so a differently named
# icon file is a hard fail (it would ship a card with initials instead).
noicon="$(mktemp -d)"
cp "$F/good/flatpark.yml" "$F/good/manifest.yml" "$noicon/"
cp "$F/good/com.example.App.svg" "$noicon/lion.svg"
out="$($AUDIT "$noicon/flatpark.yml" 2>&1)"; rc=$?
rm -rf "$noicon"
assert_eq "$rc" "1"
printf '%s' "$out" | grep -qF "catalog icon" || { echo "FAIL: missing icon not reported"; exit 1; }

# G3: runtime npm install warns but does NOT fail (exit 0, WARN line)
out="$($AUDIT "$F/warn-runtimefetch/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "0"
printf '%s' "$out" | grep -qF "WARN:" || { echo "FAIL: expected WARN line for runtime fetch"; exit 1; }

# G6: packaging transparency. An LD_PRELOAD in a wrapper must be declared as
# injected-code; an open-source app may not declare it at all; kinds are a
# closed set.
pk="$(mktemp -d)"
cp "$F/good/flatpark.yml" "$F/good/manifest.yml" "$F/good/com.example.App.svg" "$pk/"
printf '#!/bin/sh\nexport LD_PRELOAD=/app/lib/shim.so\nexec /app/extra/app "$@"\n' > "$pk/app-wrapper"
out="$($AUDIT "$pk/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "1"
printf '%s' "$out" | grep -qF '"injected-code"' || { echo "FAIL: undeclared LD_PRELOAD not reported"; exit 1; }
printf 'packaging:\n  - kind: injected-code\n    detail: Reports a fixed PID to the tray code.\n' >> "$pk/flatpark.yml"
$AUDIT "$pk/flatpark.yml" >/dev/null 2>&1
assert_eq "$?" "0"
sed -i 's/proprietary: true/proprietary: false/' "$pk/flatpark.yml"
out="$($AUDIT "$pk/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "1"
printf '%s' "$out" | grep -qF "not allowed for an open-source app" || { echo "FAIL: OSS injected-code not rejected"; exit 1; }
sed -i 's/proprietary: false/proprietary: true/; s/kind: injected-code/kind: magic/' "$pk/flatpark.yml"
out="$($AUDIT "$pk/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "1"
printf '%s' "$out" | grep -qF 'unknown kind "magic"' || { echo "FAIL: unknown packaging kind not reported"; exit 1; }
rm -rf "$pk"

# G2(b): the PipeWire socket warns until declared, with or without :ro
pw="$(mktemp -d)"
cp "$F/good/flatpark.yml" "$F/good/manifest.yml" "$F/good/com.example.App.svg" "$pw/"
sed -i 's|  - --socket=wayland|  - --socket=wayland\n  - --filesystem=xdg-run/pipewire-0:ro|' "$pw/manifest.yml"
out="$($AUDIT "$pw/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "0"
printf '%s' "$out" | grep -qF "xdg-run/pipewire-0:ro not declared" || { echo "FAIL: undeclared PipeWire socket not reported"; exit 1; }
sed -i 's|  dangerous_permissions: \[\]|  dangerous_permissions:\n    - --filesystem=xdg-run/pipewire-0|' "$pw/flatpark.yml"
out="$($AUDIT "$pw/flatpark.yml" 2>&1)"
printf '%s' "$out" | grep -qF "pipewire-0" && { echo "FAIL: declared PipeWire socket still reported"; exit 1; }
rm -rf "$pw"

# catalog.stars_repo: a build/packaging-repo source_url warns until it says
# which repository's stars count; a malformed value is a hard failure.
st="$(mktemp -d)"
cp "$F/good/flatpark.yml" "$F/good/manifest.yml" "$F/good/com.example.App.svg" "$st/"
sed -i 's|^name: Example App|name: Example App\nsource_url: https://github.com/someone/app-release|' "$st/flatpark.yml"
out="$($AUDIT "$st/flatpark.yml" 2>&1)"; rc=$?
assert_eq "$rc" "0"
printf '%s' "$out" | grep -qF "looks like a build/packaging repo" || { echo "FAIL: build-repo source_url without stars_repo not reported"; exit 1; }
printf 'catalog:\n  stars_repo: upstream/app\n' >> "$st/flatpark.yml"
out="$($AUDIT "$st/flatpark.yml" 2>&1)"
printf '%s' "$out" | grep -qF "build/packaging repo" && { echo "FAIL: declared stars_repo still reported"; exit 1; }
sed -i 's|  stars_repo: upstream/app|  stars_repo: none|' "$st/flatpark.yml"
$AUDIT "$st/flatpark.yml" >/dev/null 2>&1 || { echo "FAIL: stars_repo: none rejected"; exit 1; }
sed -i 's|  stars_repo: none|  stars_repo: https://github.com/upstream/app|' "$st/flatpark.yml"
if $AUDIT "$st/flatpark.yml" >/dev/null 2>&1; then echo "FAIL: malformed stars_repo accepted"; exit 1; fi
rm -rf "$st"

# Regression: every shipping registry app must pass (no hard fail)
for d in "$ROOT"/registry/*/flatpark.yml; do
  $AUDIT "$d" >/dev/null 2>&1 || { echo "FAIL: audit hard-failed on shipping app $d"; $AUDIT "$d"; exit 1; }
done

echo "ok test_audit_descriptor"
