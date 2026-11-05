#!/usr/bin/env bash
# The upstream-manifest diff reports a new permission or helper module and
# stays quiet for an omission the descriptor has accepted.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
CHECK=(node "$ROOT/scripts/check-upstream-manifests.mjs")
AUDIT=(node "$ROOT/scripts/audit-descriptor.mjs")

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

app="$tmp/registry/com.example.App"
mkdir -p "$app"

cat >"$app/flatpark.yml" <<'EOF'
id: com.example.App
name: Example
summary: A test app
source_url: https://github.com/example/app
build:
  manifest: com.example.App.yml
upstream:
  manifest: packaging/com.example.App.yml
  accept_missing_permissions:
    - --share=network
  accept_missing_modules: []
EOF

cat >"$app/com.example.App.yml" <<'EOF'
id: com.example.App
finish-args:
  - --socket=wayland
  - --device=dri
modules:
  - name: helper
    sources:
      - type: archive
        url: https://example.com/helper-1.tar.gz
        sha256: aaaa
  - name: app
    sources:
      - type: extra-data
        url: https://example.com/app-1.tar.gz
EOF

cat >"$tmp/upstream.yml" <<'EOF'
id: com.example.App
finish-args:
  - --device=dri
  - --socket=wayland
  - --share=network
  - --socket=cups
modules:
  - name: helper
    sources:
      - type: archive
        url: https://example.com/helper-2.tar.gz
        sha256: bbbb
  - name: cups-client
    sources:
      - type: archive
        url: https://example.com/cups.tar.gz
  - name: app
    sources:
      - type: dir
        path: ../..
      - type: git
        url: https://example.com/translations.git
EOF

run() {
  "${CHECK[@]}" --registry "$tmp/registry" --app com.example.App --upstream-file "$tmp/upstream.yml" >"$tmp/out" 2>"$tmp/err"
  echo $?
}

rc="$(run)"
assert_eq "$rc" "1"
grep -qF 'missing-permission --socket=cups' "$tmp/out" || { echo "FAIL: cups permission not reported"; cat "$tmp/out"; exit 1; }
grep -qF 'missing-permission --share=network' "$tmp/out" && { echo "FAIL: accepted network permission was reported"; exit 1; }
grep -qF 'missing-module cups-client' "$tmp/out" || { echo "FAIL: cups-client module not reported"; exit 1; }
grep -qF 'module-source helper' "$tmp/out" || { echo "FAIL: helper archive move not reported"; exit 1; }
grep -qF 'module-source app' "$tmp/out" && { echo "FAIL: the app module archive was compared"; exit 1; }
grep -qF 'extra-permission' "$tmp/out" && { echo "FAIL: shared permissions were reported as extra"; exit 1; }

# Recording the remaining differences makes the check quiet.
cat >"$app/flatpark.yml" <<'EOF'
id: com.example.App
name: Example
summary: A test app
source_url: https://github.com/example/app
build:
  manifest: com.example.App.yml
upstream:
  manifest: packaging/com.example.App.yml
  accept_missing_permissions:
    - --share=network
    - --socket=cups
  accept_missing_modules:
    - cups-client
EOF
# And the helper tarball is the one upstream pins.
sed -i 's/helper-1/helper-2/' "$app/com.example.App.yml"
rc="$(run)"
assert_eq "$rc" "0"
grep -qF 'ok com.example.App' "$tmp/out" || { echo "FAIL: expected a quiet result"; cat "$tmp/out"; exit 1; }

# A package with no upstream: block is not checked.
mkdir -p "$tmp/registry/com.example.Other"
cat >"$tmp/registry/com.example.Other/flatpark.yml" <<'EOF'
id: com.example.Other
name: Other
summary: Not followed
build:
  manifest: com.example.Other.yml
EOF
"${CHECK[@]}" --registry "$tmp/registry" --app com.example.Other >"$tmp/out"
assert_eq "$?" "0"
grep -qF 'no package names an upstream manifest' "$tmp/out" || { echo "FAIL: unconfigured app was checked"; cat "$tmp/out"; exit 1; }

# The descriptor gate rejects a path that could leave the upstream repo.
fix="$(mktemp -d)"
cp "$ROOT/tests/fixtures/audit/good/flatpark.yml" "$ROOT/tests/fixtures/audit/good/manifest.yml" "$ROOT/tests/fixtures/audit/good/com.example.App.svg" "$fix/"
cat >>"$fix/flatpark.yml" <<'EOF'
source_url: https://github.com/example/app
upstream:
  manifest: ../outside.yml
EOF
out="$("${AUDIT[@]}" "$fix/flatpark.yml" 2>&1)"
rc=$?
rm -rf "$fix"
assert_eq "$rc" "1"
printf '%s' "$out" | grep -qF 'upstream.manifest' || { echo "FAIL: bad manifest path not rejected"; printf '%s\n' "$out"; exit 1; }

echo "ok test_upstream_manifest"
