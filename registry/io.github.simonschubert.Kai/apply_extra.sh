#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Kai as a jpackage tarball: Kai/bin/Kai (the native launcher), Kai/lib/app
# (jars + Kai.cfg), Kai/lib/runtime (a jlink'd Java runtime). The launcher
# finds lib/app/Kai.cfg relative to itself, so the tree is staged whole at
# /app/extra/kai.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f kai.tar.gz ] || { echo "missing extra-data: kai.tar.gz" >&2; exit 1; }

rm -rf stage kai
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf kai.tar.gz -C stage

top="$(find stage -mindepth 1 -maxdepth 1 -type d | head -n1)"
[ -n "$top" ] && [ -x "$top/bin/Kai" ] || { echo "no bin/Kai launcher in the tarball" >&2; exit 1; }
[ -f "$top/lib/app/Kai.cfg" ] || { echo "no lib/app/Kai.cfg in the tarball" >&2; exit 1; }
[ -f "$top/lib/runtime/lib/server/libjvm.so" ] || { echo "no bundled Java runtime in the tarball" >&2; exit 1; }

mv "$top" kai
rm -rf stage kai.tar.gz
