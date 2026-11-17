#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f yt-dlp.zip ] || { echo "missing extra-data: yt-dlp.zip" >&2; exit 1; }
[ -f deno.zip ] || { echo "missing extra-data: deno.zip" >&2; exit 1; }
# Keep the official onedir bundle whole, including its Python and EJS modules.
rm -rf stage yt-dlp deno
mkdir -p stage/yt-dlp stage/deno
bsdtar --no-same-owner -xf yt-dlp.zip -C stage/yt-dlp
bsdtar --no-same-owner -xf deno.zip -C stage/deno
# Each arch names its launcher differently. Require exactly one upstream binary.
launcher=""
for candidate in stage/yt-dlp/yt-dlp*; do
    [ -f "$candidate" ] || continue
    [ -z "$launcher" ] || { echo "multiple yt-dlp launchers" >&2; exit 1; }
    launcher="$candidate"
done
[ -n "$launcher" ] || { echo "yt-dlp launcher missing" >&2; exit 1; }
ln -s "$(basename "$launcher")" stage/yt-dlp/launcher
[ -d stage/yt-dlp/_internal ] || { echo "yt-dlp bundled runtime missing" >&2; exit 1; }
[ -f stage/deno/deno ] || { echo "Deno launcher missing" >&2; exit 1; }
chmod 0755 "$launcher" stage/deno/deno
mv stage/yt-dlp yt-dlp
mv stage/deno deno
rm -rf stage yt-dlp.zip deno.zip
