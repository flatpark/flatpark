#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Stoat for Linux as an Electron Forge zip (MakerZIP): one top-level directory,
# Stoat-linux-x64/, holding the Electron app as packaged (the launcher binary,
# resources/app.asar, libffmpeg.so, SwiftShader). Keep that directory at a
# stable path the wrapper execs: /app/extra/app.
#
# Neither the directory name nor the launcher name is written down here: pin
# refreshes are automated, and both are names upstream can change between
# releases, so they are read out of the artifact instead. The zip carries no
# .desktop file, so the launcher is the one executable next to
# resources/app.asar that is not one of Chromium's own helpers. A `launch`
# symlink next to it gives the wrapper a fixed entry point.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.zip ] || {
  echo "missing extra-data: app.zip" >&2
  exit 1
}

rm -rf stage app
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root with
# every capability dropped and cannot restore archive ownership.
bsdtar --no-same-owner -xf app.zip -C stage

# Exactly one application directory is expected at the top of the zip.
count=$(find stage -mindepth 1 -maxdepth 1 -type d | wc -l)
[ "$count" -eq 1 ] || {
  echo "expected exactly one top-level directory in the zip, found $count" >&2
  exit 1
}
appdir=$(find stage -mindepth 1 -maxdepth 1 -type d)
[ -f "$appdir/resources/app.asar" ] || {
  echo "resources/app.asar missing in $appdir" >&2
  exit 1
}

launcher=""
for f in "$appdir"/*; do
  [ -f "$f" ] && [ -x "$f" ] || continue
  case "${f##*/}" in
    chrome-sandbox|chrome_crashpad_handler|*.so|*.so.*) continue ;;
  esac
  [ -z "$launcher" ] || {
    echo "more than one launcher candidate in $appdir: $launcher, ${f##*/}" >&2
    exit 1
  }
  launcher="${f##*/}"
done
[ -n "$launcher" ] || { echo "no launcher executable found in $appdir" >&2; exit 1; }

mv "$appdir" app
ln -sf "$launcher" app/launch
rm -rf stage app.zip
[ -x app/launch ] || { echo "launcher missing after stage" >&2; exit 1; }
