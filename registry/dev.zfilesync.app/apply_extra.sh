#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree: usr/bin/zfilesync plus icons and a .desktop. We
# keep only the binary, at the path the wrapper expects. It is named after the
# app id because a Tauri window takes its class from argv[0], and the desktop
# file's StartupWMClass matches it. The desktop file, icon and metainfo ship in
# the manifest at build time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f zfilesync.deb ] || { echo "missing extra-data: zfilesync.deb" >&2; exit 1; }

# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with capabilities
# dropped, so restoring the recorded uid/gid would fail.
rm -rf stage dev.zfilesync.app
mkdir stage
bsdtar -xOf zfilesync.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -f stage/usr/bin/zfilesync ] || { echo "zfilesync binary not found in .deb" >&2; exit 1; }
mv stage/usr/bin/zfilesync dev.zfilesync.app
rm -rf stage zfilesync.deb
chmod +x dev.zfilesync.app
