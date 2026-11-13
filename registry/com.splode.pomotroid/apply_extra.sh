#!/bin/sh
set -eu
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f pomotroid.deb ] || { echo "missing extra-data: pomotroid.deb" >&2; exit 1; }
rm -rf stage pomotroid
mkdir stage
# System installs run as root without capabilities: never restore ownership.
bsdtar -xOf pomotroid.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
set -- stage/usr/share/applications/*.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "expected exactly one desktop entry" >&2; exit 1; }
binary=$(sed -n 's/^Exec=//p' "$1")
# Accept one bare executable name; fail rather than guessing if the format changes.
case "$binary" in ''|*[!A-Za-z0-9._-]*) echo "unsupported desktop launcher: $binary" >&2; exit 1;; esac
[ -x "stage/usr/bin/$binary" ] || { echo "launcher missing: $binary" >&2; exit 1; }
mkdir pomotroid
mv stage/usr pomotroid/usr
ln -s "$binary" pomotroid/usr/bin/com.splode.pomotroid
rm -rf stage pomotroid.deb
