#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f tastytrade.deb ] || { echo 'missing tastytrade.deb' >&2; exit 1; }
rm -rf stage app
mkdir stage
bsdtar -xOf tastytrade.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
# The vendor desktop entry identifies the executable under /opt.
desktop=stage/usr/share/applications/tastytrade.desktop
[ -f "$desktop" ] || { echo 'missing vendor desktop entry' >&2; exit 1; }
exec_path=$(sed -n 's/^Exec="\(\/opt\/[^\"]*\)".*/\1/p' "$desktop")
case "$exec_path" in /opt/*/*) ;; *) echo 'invalid desktop Exec' >&2; exit 1;; esac
appdir="stage$(dirname "$exec_path")"
launcher=$(basename "$exec_path")
[ -x "$appdir/$launcher" ] && [ -f "$appdir/resources/app.asar" ] || { echo 'missing app executable or resources' >&2; exit 1; }
mv "$appdir" app
chmod -R a-s app
printf '%s\n' "$launcher" > launcher
rm -rf stage tastytrade.deb
