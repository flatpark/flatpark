#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_enrich: SKIP (no node)"; exit 0; }
[ -d "$ROOT/site/node_modules/yaml" ] && [ -d "$ROOT/site/node_modules/fast-xml-parser" ] \
    || { echo "test_enrich: SKIP (site deps not installed)"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
registry="$tmp/registry"
app="$registry/io.flatpark.TestOne"
mkdir -p "$app"

cat > "$app/io.flatpark.TestOne.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="red"/></svg>
EOF
cat > "$app/io.flatpark.TestOne.yml" <<'EOF'
id: io.flatpark.TestOne
runtime: org.freedesktop.Platform
runtime-version: "26.08"
sdk: org.freedesktop.Sdk
command: test-one
finish-args:
  - --share=network
  - --socket=wayland
  - --device=dri
EOF
cat > "$app/io.flatpark.TestOne.metainfo.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>io.flatpark.TestOne</id>
  <name>Test One</name>
  <summary>First test app</summary>
  <project_license>MIT</project_license>
  <developer id="io.flatpark"><name>FlatPark Test Dev</name><name xml:lang="zh-Hans">FlatPark 测试开发者</name></developer>
  <url type="homepage">https://example.org/</url>
  <description>
    <p>A test application for FlatPark.</p>
    <p>Run <code>test-one --help</code> for usage.</p>
    <p>Features:</p>
    <ul>
      <li>Feature alpha</li>
      <li>Optional cap: <code>flatpak override --user --filesystem=home io.flatpark.TestOne</code></li>
    </ul>
  </description>
  <description xml:lang="zh-Hans">
    <p>一个用于 FlatPark 的测试应用。</p>
    <ul><li>特性 alpha</li></ul>
  </description>
  <screenshots><screenshot type="default"><caption>Main</caption><caption xml:lang="zh-Hans">主界面</caption><image>https://example.org/shot.png</image></screenshot></screenshots>
  <releases>
    <release version="1.0" date="2026-01-01">
      <description><p>First release.</p></description>
      <description xml:lang="zh-Hans"><p>首个版本。</p></description>
    </release>
  </releases>
</component>
EOF
# A single flatpark.yml carries both the registry fields (id/name/summary/build)
# and developer metadata (website/maintainer) that enrich.mjs reads.
cat > "$app/flatpark.yml" <<'EOF'
id: io.flatpark.TestOne
name: Test One
summary: First test app
build:
  manifest: io.flatpark.TestOne.yml
catalog:
  category: Utilities
website: https://example.org/
maintainer:
  github: testuser
  email: test@example.org
packaging:
  - kind: seeded-config
    detail:
      en: Turns off the in-app updater on first launch.
      zh-Hans: 首次启动时关闭应用内更新器。
EOF

# The listing date ("Recently added" sort) is read out of git, so the fixture
# registry has to be a real repo for that field to be exercised at all.
git -C "$registry" init -q
git -C "$registry" add -A
git -C "$registry" -c user.name=test -c user.email=test@example.org -c commit.gpgsign=false \
    commit -qm "add test app"

data="$tmp/data"
REGISTRY_DIR="$registry" DATA_DIR="$data" "$ROOT/scripts/gen-apps-json.sh"
FLATPARK_DATA_DIR="$data" node "$ROOT/site/tools/enrich.mjs"

out="$data/apps/io.flatpark.TestOne.json"
assert_file "$out"
# permissions mapped from finish-args
assert_contains "$out" "\"label\": \"Network access\""
assert_contains "$out" "\"label\": \"Wayland display\""
assert_contains "$out" "\"label\": \"GPU acceleration\""
# metainfo-derived fields
assert_contains "$out" "\"FlatPark Test Dev\""
assert_contains "$out" "A test application for FlatPark."
# description is parsed into ordered blocks: paragraphs + list items
assert_contains "$out" "\"type\": \"list\""
assert_contains "$out" "Feature alpha"
# inline <code> inside <p> and <li> is kept as a distinct run (rendered as code),
# with the surrounding prose preserved as its own text runs around it
assert_contains "$out" "\"code\": \"test-one --help\""
assert_contains "$out" "\"text\": \"Run \""
assert_contains "$out" "\"text\": \" for usage.\""
assert_contains "$out" "\"code\": \"flatpak override --user --filesystem=home io.flatpark.TestOne\""
assert_contains "$out" "\"text\": \"Optional cap: \""
assert_contains "$out" "\"version\": \"1.0\""
assert_contains "$out" "\"label\": \"MIT\""
assert_contains "$out" "https://example.org/shot.png"
# Permissions and sections are emitted as stable keys next to their English
# text: the site translates the key and falls back to the text, so both have
# to survive. A label without its key would silently pin the panel to English.
assert_contains "$out" "\"key\": \"share.network\""
assert_contains "$out" "\"key\": \"socket.wayland\""
assert_contains "$out" "\"key\": \"device.dri\""
assert_contains "$out" "\"section\": \"utilities\""
# listing date: the commit that first added the app dir, independent of the
# release date that drives "updated" (2026-01-01 here)
assert_ok node -e "
  const a = JSON.parse(require('fs').readFileSync('$out','utf8')).added;
  if (!/^\d{4}-\d{2}-\d{2}T/.test(a || '')) throw new Error('bad added: ' + a);
"
# AppStream ships translations inline as xml:lang siblings. FlatPark renders
# app content in the source language, so every one of them must be absent: a
# leaked translated <p> concatenates onto the English prose, and a translated
# <name> or <caption> makes the field an array, which renders as empty.
assert_contains "$out" "\"caption\": \"Main\""
assert_contains "$out" "First release."
if grep -q "测试开发者\|一个用于\|特性 alpha\|主界面\|首个版本" "$out"; then
    echo "FAIL: xml:lang translation leaked into source-language content"
    exit 1
fi
# flatpark.yml-derived maintainer
assert_contains "$out" "\"github\": \"testuser\""
# enrichment must strip the private source-path fields
if grep -q "_manifest\|_srcDir" "$out"; then echo "FAIL: enriched file still has _ fields"; exit 1; fi
assert_ok node -e "JSON.parse(require('fs').readFileSync('$out','utf8'))"
# packaging transparency: declared seeded-config -> level adapted, detail kept per locale
assert_ok node -e "
const a = JSON.parse(require('fs').readFileSync('$out','utf8'));
if (a.packaging.level !== 'adapted') throw new Error('level ' + a.packaging.level);
const i = a.packaging.items[0];
if (i.kind !== 'seeded-config' || i.detail['zh-Hans'] !== '首次启动时关闭应用内更新器。') throw new Error(JSON.stringify(i));
"
echo "test_enrich: PASS"
