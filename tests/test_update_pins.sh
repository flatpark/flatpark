#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
command -v node >/dev/null 2>&1 || { echo "test_update_pins: SKIP (no node)"; exit 0; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

printf 'OLD-CONTENT' > "$tmp/old.bin"
printf 'NEW-CONTENT-LONGER' > "$tmp/new.bin"
old_sha="$(sha256sum "$tmp/old.bin" | cut -d' ' -f1)"; old_size="$(wc -c < "$tmp/old.bin")"
new_sha="$(sha256sum "$tmp/new.bin" | cut -d' ' -f1)"; new_size="$(wc -c < "$tmp/new.bin")"

mk_manifest() { # <url> <sha> <size>
cat > "$tmp/manifest.yml" <<EOF
modules:
  - name: app
    sources:
      # BEGIN MANAGED EXTRA-DATA
      - type: extra-data
        filename: app.bin
        only-arches:
          - x86_64
        url: $1
        sha256: $2
        size: $3
      # END MANAGED EXTRA-DATA
EOF
}
# A complete component, not a stub: the release-writing path is expected to
# leave a valid metainfo valid, and case 5 asserts exactly that.
mk_metainfo() { # <version>
cat > "$tmp/app.metainfo.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>io.flatpark.up</id>
  <name>Up</name>
  <summary>A fixture component for the update-pins tests</summary>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT</project_license>
  <description><p>A fixture component used by the update-pins tests to exercise the release-writing path end to end.</p></description>
  <url type="homepage">https://flatpark.org</url>
  <launchable type="desktop-id">io.flatpark.up.desktop</launchable>
  <releases>
    <release version="$1" date="2026-01-01" />
  </releases>
</component>
EOF
}
RC=0; OUT=""
run() { # <resolver-json> -> sets RC/OUT (called directly, not piped, so globals stick)
  set +e
  OUT="$(printf '%s' "$1" | node "$ROOT/scripts/update-pins.mjs" "$tmp/manifest.yml" "$tmp/app.metainfo.xml")"
  RC=$?
  set -e
}

# 1) version unchanged -> exit 10, nothing rewritten (no download even attempted).
mk_manifest "file://$tmp/old.bin" "$old_sha" "$old_size"
mk_metainfo "1.0"
run "$(printf '{"version":"1.0","sources":[{"filename":"app.bin","url":"file://%s/old.bin"}]}' "$tmp")"
assert_eq "$RC" "10"

# 2) version bump -> exit 0, pins refreshed from the new source, release prepended.
run "$(printf '{"version":"2.0","releaseDate":"2026-02-02","sources":[{"filename":"app.bin","url":"file://%s/new.bin"}]}' "$tmp")"
assert_eq "$RC" "0"
assert_eq "$OUT" "2.0"
assert_contains "$tmp/manifest.yml" "url: file://$tmp/new.bin"
assert_contains "$tmp/manifest.yml" "sha256: $new_sha"
assert_contains "$tmp/manifest.yml" "size: $new_size"
assert_contains "$tmp/app.metainfo.xml" "<release version=\"2.0\" date=\"2026-02-02\">"
# No notes supplied -> an empty <description>, i.e. a slot a human can still
# fill in, rather than a self-closing tag with nowhere to put anything.
assert_contains "$tmp/app.metainfo.xml" "<description></description>"
# the new release must be first (newest-first), old one retained
first_ver="$(grep -oE 'release version="[^"]*"' "$tmp/app.metainfo.xml" | head -1)"
assert_eq "$first_ver" 'release version="2.0"'
assert_contains "$tmp/app.metainfo.xml" "<release version=\"1.0\""

# 3) re-running the same resolver is now a no-op (anchor moved to 2.0).
run "$(printf '{"version":"2.0","releaseDate":"2026-02-02","sources":[{"filename":"app.bin","url":"file://%s/new.bin"}]}' "$tmp")"
assert_eq "$RC" "10"

# 4) releaseUrl -> <url type="details">; releaseNotes written through verbatim.
run "$(printf '{"version":"3.0","releaseDate":"2026-03-03","sources":[{"filename":"app.bin","url":"file://%s/new.bin"}],"releaseUrl":"https://example.org/r/3.0","releaseNotes":"<p>Fixed:</p>\\n<ul>\\n  <li>A &amp; B</li>\\n</ul>"}' "$tmp")"
assert_eq "$RC" "0"
assert_contains "$tmp/app.metainfo.xml" '<url type="details">https://example.org/r/3.0</url>'
assert_contains "$tmp/app.metainfo.xml" "<p>Fixed:</p>"
assert_contains "$tmp/app.metainfo.xml" "<li>A &amp; B</li>"

# 5) notes that AppStream rejects are dropped; the release (and its details
#    link) still lands, so a bad upstream fragment can never block an update.
#    Needs the validator — without it the guard is a documented no-op.
if command -v appstreamcli >/dev/null 2>&1; then
  run "$(printf '{"version":"4.0","releaseDate":"2026-04-04","sources":[{"filename":"app.bin","url":"file://%s/new.bin"}],"releaseUrl":"https://example.org/r/4.0","releaseNotes":"<h2>nope</h2><p>unclosed"}' "$tmp")"
  assert_eq "$RC" "0"
  assert_contains "$tmp/app.metainfo.xml" '<release version="4.0" date="2026-04-04">'
  assert_contains "$tmp/app.metainfo.xml" '<url type="details">https://example.org/r/4.0</url>'
  grep -q '<h2>nope</h2>' "$tmp/app.metainfo.xml" && {
    echo "FAIL: invalid releaseNotes were written through"; exit 1; }
  appstreamcli validate "$tmp/app.metainfo.xml" >/dev/null 2>&1 \
    || { echo "FAIL: metainfo does not validate after the update"; exit 1; }
fi

# 6) per-arch payloads share a filename; `arch` picks the pin. Adding an aarch64
#    source next to an existing x86_64 pin creates a new record scoped to it and,
#    with no version anchor, leaves the unchanged x86_64 pin alone.
mk_manifest "file://$tmp/old.bin" "$old_sha" "$old_size"
mk_metainfo "1.0"
run "$(printf '{"sources":[{"filename":"app.bin","arch":"x86_64","url":"file://%s/old.bin"},{"filename":"app.bin","arch":"aarch64","url":"file://%s/new.bin"}]}' "$tmp" "$tmp")"
assert_eq "$RC" "0"
assert_eq "$(grep -c 'filename: app.bin' "$tmp/manifest.yml")" "2"
arm_block="$(awk '/- aarch64/{f=1} f' "$tmp/manifest.yml")"
case "$arm_block" in *"sha256: $new_sha"*) ;; *) echo "FAIL: aarch64 pin missing"; exit 1 ;; esac
x86_block="$(awk '/- x86_64/{f=1} /- aarch64/{f=0} f' "$tmp/manifest.yml")"
case "$x86_block" in *"sha256: $old_sha"*) ;; *) echo "FAIL: x86_64 pin changed"; exit 1 ;; esac

# 7) once a filename is pinned for two arches, a source without `arch` is
#    ambiguous and must fail rather than cross-pin.
run "$(printf '{"version":"9.0","sources":[{"filename":"app.bin","url":"file://%s/new.bin"}]}' "$tmp")"
assert_eq "$RC" "1"

# 8) same version, but upstream re-uploaded the payload in place: a source that
#    reports its size re-pins when the size drifts, adds no <release>, and is a
#    no-op once the pin matches again. Without `size` the version gate holds.
cp "$tmp/new.bin" "$tmp/recut.bin"
mk_manifest "file://$tmp/recut.bin" "$old_sha" "$old_size"
mk_metainfo "1.0"
run "$(printf '{"version":"1.0","sources":[{"filename":"app.bin","url":"file://%s/recut.bin"}]}' "$tmp")"
assert_eq "$RC" "10"
run "$(printf '{"version":"1.0","sources":[{"filename":"app.bin","url":"file://%s/recut.bin","size":%s}]}' "$tmp" "$new_size")"
assert_eq "$RC" "0"
assert_contains "$tmp/manifest.yml" "sha256: $new_sha"
assert_contains "$tmp/manifest.yml" "size: $new_size"
assert_eq "$(grep -c '<release ' "$tmp/app.metainfo.xml")" "1"
run "$(printf '{"version":"1.0","sources":[{"filename":"app.bin","url":"file://%s/recut.bin","size":%s}]}' "$tmp" "$new_size")"
assert_eq "$RC" "10"

# 9) same version, same size, but the source moved to another URL -> re-pinned.
run "$(printf '{"version":"1.0","sources":[{"filename":"app.bin","url":"file://%s/new.bin","size":%s}]}' "$tmp" "$new_size")"
assert_eq "$RC" "0"
assert_contains "$tmp/manifest.yml" "url: file://$tmp/new.bin"

echo "test_update_pins: PASS"
