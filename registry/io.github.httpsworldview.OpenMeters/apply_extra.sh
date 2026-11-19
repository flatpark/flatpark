#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# official Linux tarball is one top-level folder,
# openmeters-<version>-x86_64-linux-gnu/, holding bin/openmeters, the licence,
# the README, a desktop entry and the icon. Keep the payload under
# /app/extra/openmeters; the wrapper, desktop entry, icon and metainfo are
# installed at build time, because they must be exported before this runs.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=openmeters.tar.xz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf openmeters staging
mkdir staging
# --no-same-owner: the archive records the build user's uid/gid, which a system
# install (root, no capabilities) cannot restore; without this the unpack
# aborts even though every member extracted.
bsdtar --no-same-owner -xf "$archive" -C staging

# The top-level folder is versioned, so read it out of the archive instead of
# hardcoding a name upstream changes every release.
set -- staging/*/
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top-level folder in the tarball, found: $*" >&2; exit 1; }
mv "$1" openmeters
[ -x openmeters/bin/openmeters ] || { echo "openmeters/bin/openmeters not found in the tarball" >&2; exit 1; }

rm -rf staging "$archive"
