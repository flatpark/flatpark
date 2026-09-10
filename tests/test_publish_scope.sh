#!/usr/bin/env bash
# publish-scope.sh: only a diff that cannot touch the repo or the discovery
# files answers "site"; everything else answers "full". Runs the real script
# from a throwaway git repo (scripts/ + config/ copied in, so ROOT resolves
# there).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v git >/dev/null || { echo "test_publish_scope: SKIP (no git)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cp -r "$ROOT/scripts" "$ROOT/config" "$tmp/"
app="$tmp/registry/io.flatpark.TestOne"; mkdir -p "$app"
cat > "$app/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: First test app
build:
  manifest: io.flatpark.TestOne.yml
  branch: stable
  mode: extra-data
catalog:
  category: Finance
  tags:
    - Trading
EOF
cat > "$app/io.flatpark.TestOne.yml" <<'EOF'
id: io.flatpark.TestOne
modules:
  - name: main
    sources:
      - type: extra-data
        url: https://example.org/app-1.0.deb
        sha256: aaaa
EOF
printf '<component/>\n' > "$app/io.flatpark.TestOne.metainfo.xml"
mkdir -p "$tmp/site/src" "$tmp/docs"
printf 'hello\n' > "$tmp/site/src/index.astro"
printf 'docs\n' > "$tmp/docs/README.md"
printf 'featured:\n  - io.flatpark.TestOne\n' > "$tmp/config/featured.yml"

g() { git -C "$tmp" -c user.name=t -c user.email=t@t "$@"; }
g init -q
g add -A
g commit -qm base
base="$(g rev-parse HEAD)"
scope() { "$tmp/scripts/publish-scope.sh" "$base" HEAD 2>/dev/null; }
snap() { g add -A; g commit -qm "$1"; }
reset() { g reset -q --hard "$base"; g clean -qfd; }

# --- site scope: nothing here reaches the published bytes -------------------

# 1. site source edit only
printf 'hello world\n' > "$tmp/site/src/index.astro"
snap site-edit
assert_eq "$(scope)" "site"

# 2. catalog-only descriptor edit (the developer-approved shield flip)
reset
printf '  upstream_approved: true\n' >> "$app/flatpark.yml"
snap shield-flip
assert_eq "$(scope)" "site"

# 3. display-only registry assets (metainfo, icon) — no rebuild, so no repo work
reset
printf '<component><name>Test One</name></component>\n' > "$app/io.flatpark.TestOne.metainfo.xml"
printf 'PNG\n' > "$app/io.flatpark.TestOne.png"
snap display-assets
assert_eq "$(scope)" "site"

# 4. the homepage's curated list is a site input
reset
printf 'featured: []\n' > "$tmp/config/featured.yml"
snap featured-edit
assert_eq "$(scope)" "site"

# 5. docs never trigger the workflow, but may ride along with a site push
reset
printf 'notes\n' > "$tmp/docs/notes.md"
printf 'more\n' >> "$tmp/site/src/index.astro"
snap docs-and-site
assert_eq "$(scope)" "site"

# --- full scope -------------------------------------------------------------

# 6. build-relevant app change
reset
sed -i 's/app-1.0.deb/app-1.1.deb/' "$app/io.flatpark.TestOne.yml"
snap pin-bump
assert_eq "$(scope)" "full"

# 7. publish tooling
reset
printf '\n# touched\n' >> "$tmp/scripts/sync-r2.sh"
snap tooling-edit
assert_eq "$(scope)" "full"

# 8. repo-wide config
reset
printf '\n# touched\n' >> "$tmp/config/flatpark.conf"
snap conf-edit
assert_eq "$(scope)" "full"

# 9. new app -> needs a built ref and an uploaded .flatpakref
reset
two="$tmp/registry/io.flatpark.TestTwo"; mkdir -p "$two"
sed 's/TestOne/TestTwo/g; s/Test One/Test Two/' "$app/flatpark.yml" > "$two/flatpark.yml"
sed 's/TestOne/TestTwo/g' "$app/io.flatpark.TestOne.yml" > "$two/io.flatpark.TestTwo.yml"
snap add-app
assert_eq "$(scope)" "full"

# 10. de-list -> summary regen + stale refs dropped from R2
reset
g rm -rq registry/io.flatpark.TestOne
g commit -qm delist
assert_eq "$(scope)" "full"

# 11. rename -> the .flatpakref Title changes
reset
sed -i 's/^name: Test One$/name: Test Uno/' "$app/flatpark.yml"
snap rename
assert_eq "$(scope)" "full"

echo "test_publish_scope: PASS"
