#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The upstream
# artifact is the official Linux tarball (CPack): one top-level folder,
# SculptForge-<version>-linux-x86_64/, holding bin/sculptforge, bin/sculptforge-cli
# and share/. The app finds share/sculptforge next to bin/.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f sculptforge.tar.gz ] || { echo "missing extra-data: sculptforge.tar.gz" >&2; exit 1; }

rm -rf sculptforge staging
mkdir staging
# --no-same-owner: the archive records the build user's uid, which a system
# install (root, no capabilities) cannot restore.
bsdtar --no-same-owner -xf sculptforge.tar.gz -C staging

set -- staging/*/
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one top-level folder in the tarball, found: $*" >&2; exit 1; }
mv "$1" sculptforge
[ -x sculptforge/bin/sculptforge ] || { echo "sculptforge/bin/sculptforge not found in the tarball" >&2; exit 1; }
[ -x sculptforge/bin/sculptforge-cli ] || { echo "sculptforge/bin/sculptforge-cli not found in the tarball" >&2; exit 1; }

rm -rf staging sculptforge.tar.gz
