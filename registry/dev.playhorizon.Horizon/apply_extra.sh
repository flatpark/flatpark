#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The official
# Linux launcher tarball holds a single self-contained binary,
# horizon-launcher, at its top level (no directory around it). It is kept at
# /app/extra/horizon-launcher, a fixed path the wrapper starts.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# build time: extra-data arrives later, so nothing Flatpak exports can come
# from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f horizon-launcher.tar.gz ] || { echo "missing extra-data: horizon-launcher.tar.gz" >&2; exit 1; }

rm -rf stage horizon-launcher
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, and the archive records uid 1001; restoring
# it would abort the unpack.
bsdtar --no-same-owner -xf horizon-launcher.tar.gz -C stage

# The binary sits at the top level today; accept one wrapping directory too,
# so a layout change still unpacks, and fail if there isn't exactly one.
bin="$(find stage -maxdepth 2 -type f -name horizon-launcher)"
[ -n "$bin" ] && [ "$(printf '%s\n' "$bin" | wc -l)" -eq 1 ] || {
  echo "expected exactly one horizon-launcher binary in the tarball" >&2
  exit 1
}
mv "$bin" horizon-launcher
chmod 755 horizon-launcher

rm -rf stage horizon-launcher.tar.gz
