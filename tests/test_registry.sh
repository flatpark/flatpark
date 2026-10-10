#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
. "$ROOT/scripts/lib/common.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
reg="$tmp/registry"; mkdir -p "$reg/io.flatpark.TestOne"
cat > "$reg/io.flatpark.TestOne/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: First test app
build:
  manifest: io.flatpark.TestOne.yml
  branch: stable
  mode: extra-data-url
catalog:
  category: Finance
  tags:
    - Trading
    - Markets
    - Workstation
EOF

REGISTRY_DIR="$reg" load_config "$ROOT"
load_app "io.flatpark.TestOne"
assert_eq "$APP_NAME" "Test One"
assert_eq "$APP_BRANCH" "stable"
assert_eq "$UPDATE_MODE" "extra-data-url"
assert_eq "$MANIFEST" "$reg/io.flatpark.TestOne/io.flatpark.TestOne.yml"
assert_eq "$APP_SRC" "$reg/io.flatpark.TestOne"
assert_eq "$APP_CATEGORY" "Finance"
assert_eq "$APP_TAGS" "Trading, Markets, Workstation"

ids="$(REGISTRY_DIR="$reg" "$ROOT/scripts/scan-registry.sh" --ids)"
assert_eq "$ids" "io.flatpark.TestOne"
scan="$(REGISTRY_DIR="$reg" "$ROOT/scripts/scan-registry.sh" io.flatpark.TestOne)"
case "$scan" in
    *"io.flatpark.TestOne"*"extra-data-url"*) ;;
    *) echo "FAIL: scan output missing app/update mode: $scan"; exit 1 ;;
esac

# explicit env overrides must win over the descriptor defaults
override_scan="$(REGISTRY_DIR="$reg" APP_SRC="/tmp/flatpark-app-src" MANIFEST="/tmp/flatpark-app.yml" \
    "$ROOT/scripts/scan-registry.sh" io.flatpark.TestOne)"
case "$override_scan" in
    *"/tmp/flatpark-app.yml") ;;
    *) echo "FAIL: scan did not preserve explicit manifest override: $override_scan"; exit 1 ;;
esac
assert_eq "$APP_ARCHES" "x86_64"   # no build.arches => x86_64 only

# build.arches opts an app into aarch64; scan-registry --arch picks per arch.
mkdir -p "$reg/io.flatpark.TestArm"
cat > "$reg/io.flatpark.TestArm/flatpark.yml" <<'EOF'
id: io.flatpark.TestArm
name: Test Arm
summary: Multi-arch test app
build:
  manifest: io.flatpark.TestArm.yml
  arches:
    - aarch64
    - x86_64
  branch: stable
EOF
load_app "io.flatpark.TestArm"
assert_eq "$APP_ARCHES" "x86_64 aarch64"   # canonical order
assert_eq "$APP_BRANCH" "stable"           # keys after the list still parse
app_has_arch aarch64 || { echo "FAIL: app_has_arch aarch64"; exit 1; }
arm="$(REGISTRY_DIR="$reg" "$ROOT/scripts/scan-registry.sh" --ids --arch aarch64)"
assert_eq "$arm" "io.flatpark.TestArm"
x86="$(REGISTRY_DIR="$reg" "$ROOT/scripts/scan-registry.sh" --ids --arch x86_64 io.flatpark.TestOne io.flatpark.TestArm | tr '\n' ' ')"
assert_eq "$x86" "io.flatpark.TestOne io.flatpark.TestArm "

# inline form, and unknown arches are rejected
sed -i '/^  arches:/,/^    - x86_64/c\  arches: [x86_64, aarch64]' "$reg/io.flatpark.TestArm/flatpark.yml"
load_app "io.flatpark.TestArm"
assert_eq "$APP_ARCHES" "x86_64 aarch64"
sed -i 's/^  arches: .*/  arches: [x86_64, riscv64]/' "$reg/io.flatpark.TestArm/flatpark.yml"
if node "$ROOT/scripts/read-descriptor.mjs" "$reg/io.flatpark.TestArm/flatpark.yml" >/dev/null 2>&1; then
    echo "FAIL: unknown arch accepted"; exit 1
fi
echo "test_registry: PASS"
