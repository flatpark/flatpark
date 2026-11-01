#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the official Linux build as a .tar.gz with one version-stamped top directory
# holding the photoncam binary. The archive also carries Apple extended
# attributes; restoring them fails when apply_extra runs as root with every
# capability dropped.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=photoncam.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf photoncam staging
mkdir staging
bsdtar --no-same-owner --no-xattrs -xf "$archive" -C staging

set -- staging/*/
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top-level folder in the tarball, found: $*" >&2; exit 1; }
[ -x "$1/photoncam" ] || { echo "photoncam not found in the tarball" >&2; exit 1; }

mv "$1" photoncam
rm -rf staging "$archive"
[ -x photoncam/photoncam ]
