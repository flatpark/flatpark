#!/bin/sh
set -eu

# FlatPark fetches one architecture-specific portable ZIP at install time. Its
# root is the complete electron-builder application tree, so stage it at the
# stable path used by the wrapper without changing the upstream files.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=""
for candidate in opentubex-*.zip; do
    [ -f "$candidate" ] || continue
    [ -z "$archive" ] || { echo "multiple OpenTubeX archives found" >&2; exit 1; }
    archive="$candidate"
done
[ -n "$archive" ] || { echo "missing OpenTubeX extra-data archive" >&2; exit 1; }

rm -rf stage opentubex
mkdir stage
bsdtar --no-same-owner -xf "$archive" -C stage
[ -x stage/opentubex ] || { echo "OpenTubeX launcher not found in archive" >&2; exit 1; }
[ -f stage/resources/app.asar ] || { echo "OpenTubeX app.asar not found in archive" >&2; exit 1; }

mv stage opentubex
rm -f "$archive"

# Deno runtime (yt-dlp's JS engine), shipped as extra-data for the same reason
# as the app payload: a built-in module would bake its ~130 MB binary into the
# OSTree commit and R2. The official zip holds a single `deno` executable; stage
# it at a stable path that opentubex-wrapper adds to PATH.
deno_zip=""
for candidate in deno-*.zip; do
    [ -f "$candidate" ] || continue
    [ -z "$deno_zip" ] || { echo "multiple Deno archives found" >&2; exit 1; }
    deno_zip="$candidate"
done
[ -n "$deno_zip" ] || { echo "missing Deno extra-data archive" >&2; exit 1; }

rm -f deno
bsdtar --no-same-owner -xf "$deno_zip"
[ -f deno ] || { echo "deno binary not found in archive" >&2; exit 1; }
chmod 0755 deno
rm -f "$deno_zip"
