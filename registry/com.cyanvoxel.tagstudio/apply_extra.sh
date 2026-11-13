#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f tagstudio.tar.gz ] || { echo "missing extra-data: tagstudio.tar.gz" >&2; exit 1; }
[ -f libxkbcommon-x11-0.deb ] || { echo "missing extra-data: libxkbcommon-x11-0.deb" >&2; exit 1; }
rm -rf stage tagstudio support
rm -f tagstudio-launcher
mkdir stage
# System installations run as root with no capabilities: don't restore ownership.
bsdtar --no-same-owner -xf tagstudio.tar.gz -C stage
# Locate the PyInstaller directory by its accompanying _internal tree rather
# than assuming a versioned top directory or executable name.
internal="$(find stage -type d -name _internal)"
[ -n "$internal" ] && [ "$(printf '%s\n' "$internal" | wc -l)" -eq 1 ] || {
    echo "expected one PyInstaller _internal directory" >&2; exit 1;
}
root="${internal%/_internal}"
launcher="$(find "$root" -maxdepth 1 -type f -executable)"
[ -n "$launcher" ] && [ "$(printf '%s\n' "$launcher" | wc -l)" -eq 1 ] || {
    echo "expected one executable beside _internal" >&2; exit 1;
}
name="${launcher##*/}"
mv "$root" tagstudio
# Keep our stable launcher link outside the unmodified vendor directory.
ln -s "tagstudio/$name" tagstudio-launcher
mkdir -p stage/deb support
bsdtar --no-same-owner -xf libxkbcommon-x11-0.deb -C stage/deb
set -- stage/deb/data.tar.*
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "Debian data archive missing" >&2; exit 1; }
bsdtar --no-same-owner -xf "$1" -C support
[ -f support/usr/lib/x86_64-linux-gnu/libxkbcommon-x11.so.0 ] || {
    echo "X11 keyboard support library missing" >&2; exit 1;
}
rm -rf stage tagstudio.tar.gz libxkbcommon-x11-0.deb
