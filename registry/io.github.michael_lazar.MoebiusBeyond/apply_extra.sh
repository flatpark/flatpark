#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f moebius.deb ] || { echo 'missing moebius.deb' >&2; exit 1; }
rm -rf stage moebius
mkdir stage
bsdtar -xOf moebius.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
# The upstream desktop entry identifies the executable under /opt.
set -- stage/usr/share/applications/*.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo 'expected one desktop entry' >&2; exit 1; }
exec_line=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$1")
case "$exec_line" in /opt/*/*) ;; *) echo 'unexpected desktop Exec' >&2; exit 1 ;; esac
appdir=$(dirname "$exec_line")
launcher=$(basename "$exec_line")
case "$appdir" in /opt/*/*|*..*) echo 'unexpected app directory' >&2; exit 1 ;; esac
[ -x "stage$appdir/$launcher" ] && [ -f "stage$appdir/resources/app.asar" ] || { echo 'app binary or resources missing' >&2; exit 1; }
mv "stage$appdir" moebius
chmod -R a-s moebius
printf '%s\n' "$launcher" > launcher
rm -rf stage moebius.deb
