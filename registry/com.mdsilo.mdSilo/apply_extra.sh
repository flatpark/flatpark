#!/bin/sh
set -eu
# Flatpak runs this offline in /app/extra, including as root without capabilities.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f mdsilo.deb ] || { echo "missing extra-data: mdsilo.deb" >&2; exit 1; }
rm -rf stage mdsilo
mkdir stage
bsdtar -xOf mdsilo.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
# Read the launcher from the vendor's desktop entry, so an upstream rename is
# either followed automatically or rejected rather than silently mispackaged.
set -- stage/usr/share/applications/*.desktop
[ "$#" = 1 ] && [ -f "$1" ] || { echo "expected one mdSilo desktop entry" >&2; exit 1; }
launcher=$(sed -n 's/^Exec=\([^ ]*\).*$/\1/p' "$1")
case "$launcher" in ''|*[!a-zA-Z0-9._-]*) echo "unexpected mdSilo launcher: $launcher" >&2; exit 1 ;; esac
[ -x "stage/usr/bin/$launcher" ] || { echo "mdSilo executable missing: $launcher" >&2; exit 1; }
# Retain the usr tree for any resources alongside the executable.
mv stage/usr mdsilo
# GTK and WebKit use argv[0] for window grouping and the MPRIS application id.
ln -s "bin/$launcher" mdsilo/com.mdsilo.mdSilo
rm -rf stage mdsilo.deb
