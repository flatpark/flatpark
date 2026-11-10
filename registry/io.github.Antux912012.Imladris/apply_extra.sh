#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's .deb
# carries the native binary at usr/bin/imladris and desktop assets.
# Stage the binary at /app/extra/imladris, unmodified.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f imladris.deb ] || { echo "missing extra-data: imladris.deb" >&2; exit 1; }

rm -rf stage imladris
mkdir stage
# Extract data archive: use bsdtar (standard in Flatpak runtimes) or ar/tar fallback
if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xOf imladris.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
elif command -v ar >/dev/null 2>&1; then
    ar -x imladris.deb
    tar --no-same-owner -xf data.tar.* -C stage
    rm -f control.tar.* debian-binary data.tar.*
else
    echo "Neither bsdtar nor ar found" >&2
    exit 1
fi
[ -f stage/usr/bin/imladris ] || { echo "imladris binary not found in .deb" >&2; exit 1; }

mv stage/usr/bin/imladris imladris
chmod +x imladris

if [ -d stage/usr/share/imladris ]; then
    mkdir -p share/imladris
    cp -a stage/usr/share/imladris/* share/imladris/
fi

rm -rf stage imladris.deb
