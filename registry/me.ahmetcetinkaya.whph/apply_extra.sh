#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships WHPH for
# Linux as a Flutter release bundle in a tarball: the whph binary with lib/
# (libapp.so, the Flutter engine and plugins) and data/ (flutter_assets, ICU)
# beside it, plus share/ with icons, desktop file and metainfo. Flutter finds
# lib/ and data/ relative to the executable, so the tree is staged whole at
# /app/extra/whph.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f whph.tar.gz ] || { echo "missing extra-data: whph.tar.gz" >&2; exit 1; }

rm -rf whph
mkdir whph
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf whph.tar.gz -C whph
rm -f whph.tar.gz

[ -x whph/whph ] || { echo "whph binary missing after unpack" >&2; exit 1; }
[ -f whph/lib/libapp.so ] && [ -d whph/data/flutter_assets ] \
    || { echo "Flutter bundle incomplete after unpack" >&2; exit 1; }
