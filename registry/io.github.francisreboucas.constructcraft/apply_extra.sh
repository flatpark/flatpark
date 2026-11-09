#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the official Linux build as a .tar.gz with a single version-stamped top
# directory holding constructcraft, ccad and a sample project. Rename that
# directory to a stable path the wrappers exec across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=constructcraft.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

# --no-same-owner: release archives often record a non-root uid, and on a
# system-wide install Flatpak runs apply_extra as root with every capability
# dropped, so restoring that owner fails and aborts the unpack.
mkdir stage
tar --no-same-owner -xzf "$archive" -C stage

set -- stage/*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "tarball does not contain exactly one directory" >&2; exit 1; }
top=$1
[ -x "$top/constructcraft" ] || { echo "constructcraft not found in tarball" >&2; exit 1; }
[ -x "$top/ccad" ] || { echo "ccad not found in tarball" >&2; exit 1; }

rm -rf constructcraft
mv "$top" constructcraft
rm -rf stage "$archive"
[ -x constructcraft/constructcraft ]
[ -x constructcraft/ccad ]
