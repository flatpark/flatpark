#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The upstream
# artifact is the official Linux tarball: one top-level folder,
# RustGIS-<version>-linux-<arch>/, holding the rustgis and rustgis-cli
# binaries beside the licence, README, desktop entry, icon and MIME file.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f rustgis.tar.gz ] || { echo "missing extra-data: rustgis.tar.gz" >&2; exit 1; }

rm -rf rustgis staging
mkdir staging
# --no-same-owner: the archive records the build user's uid, which a system
# install (root, no capabilities) cannot restore.
bsdtar --no-same-owner -xf rustgis.tar.gz -C staging

set -- staging/*/
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top-level folder in the tarball, found: $*" >&2; exit 1; }
mv "$1" rustgis
[ -x rustgis/rustgis ] || { echo "rustgis/rustgis not found in the tarball" >&2; exit 1; }
[ -x rustgis/rustgis-cli ] || { echo "rustgis/rustgis-cli not found in the tarball" >&2; exit 1; }

rm -rf staging rustgis.tar.gz
