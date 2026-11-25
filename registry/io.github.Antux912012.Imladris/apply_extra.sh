#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's Flatpak
# /app tree tarball carries bin/imladris, optional bundled llama-server,
# libraries, and desktop/AppStream/schema assets built with --prefix=/app.
# Stage the binary at /app/extra/imladris, unmodified.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f imladris-flatpak.tar.gz ] || { echo "missing extra-data: imladris-flatpak.tar.gz" >&2; exit 1; }

rm -rf stage imladris bin lib share
mkdir stage

if command -v bsdtar >/dev/null 2>&1; then
    bsdtar --no-same-owner -xf imladris-flatpak.tar.gz -C stage
elif command -v tar >/dev/null 2>&1; then
    tar --no-same-owner -xzf imladris-flatpak.tar.gz -C stage
else
    echo "Neither bsdtar nor tar found" >&2
    exit 1
fi

[ -f stage/bin/imladris ] || { echo "imladris binary not found in Flatpak archive" >&2; exit 1; }

mv stage/bin/imladris imladris
chmod +x imladris

if [ -d stage/bin ] && [ -n "$(ls -A stage/bin 2>/dev/null)" ]; then
    mkdir -p bin
    cp -a stage/bin/* bin/
    chmod +x bin/* 2>/dev/null || true
fi

if [ -d stage/lib ] && [ -n "$(ls -A stage/lib 2>/dev/null)" ]; then
    mkdir -p lib
    cp -a stage/lib/* lib/
fi

if [ -d stage/share ] && [ -n "$(ls -A stage/share 2>/dev/null)" ]; then
    mkdir -p share
    cp -a stage/share/* share/
fi

rm -rf stage imladris-flatpak.tar.gz
