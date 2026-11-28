#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Hydra's Linux build as an electron-builder .deb with the whole app under
# /opt/Hydra: the Electron launcher, resources/app.asar, and the tools Hydra
# runs itself (umu-run, legendary, ludusavi, 7zzs, the torrent addon). Keep that
# directory, unmodified, at /app/extra/hydra.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f hydra.deb ] || { echo "missing extra-data: hydra.deb" >&2; exit 1; }

rm -rf stage hydra launcher
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with no capabilities.
bsdtar -xOf hydra.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The .deb's own desktop entry names the launcher (Exec=/opt/Hydra/hydralauncher
# %U); read the app directory and the launcher name from it rather than
# hardcoding either, so an upstream rename fails here instead of shipping an
# app that can't start.
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n1)"
[ -n "$desktop" ] || { echo "no desktop entry in hydra.deb" >&2; exit 1; }
exe="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
case "$exe" in
  /opt/*/*) ;;
  *) echo "unexpected Exec= in the .deb's desktop entry: $exe" >&2; exit 1 ;;
esac
appdir="stage$(dirname "$exe")"
launcher="$(basename "$exe")"
[ -x "$appdir/$launcher" ] || { echo "launcher $exe not found in hydra.deb" >&2; exit 1; }
[ -f "$appdir/resources/app.asar" ] || { echo "resources/app.asar missing in hydra.deb" >&2; exit 1; }

mv "$appdir" hydra
# chrome-sandbox is unused under zypak; make sure no setuid bit is written.
chmod -R a-s hydra
printf '%s\n' "$launcher" > launcher
rm -rf stage hydra.deb
