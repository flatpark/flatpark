#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The tarball is
# upstream's portable build of the Rust rewrite (0.2.0+): one versioned top
# directory holding usr/lib/mark-shot/mark-shot (a single executable that
# links only libraries the runtime has) and usr/lib/mark-shot/media (its
# FFmpeg-based recorder, loaded relative to the executable). Rename it to a
# stable path so the wrapper can exec it across updates. Nothing is patched.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f mark-shot.tar.gz ] || { echo "missing extra-data: mark-shot.tar.gz" >&2; exit 1; }

# Also clear what the 0.1.x (Qt AppImage) layout left behind on an update.
rm -rf stage mark-shot usr tools squashfs-root appimage-tools
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf mark-shot.tar.gz -C stage

# The top directory carries the version and the arch; match it, and insist on
# exactly one.
set -- stage/mark-shot-native-*-linux-*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one mark-shot-native-* directory in the tarball" >&2; exit 1; }
mv "$1" mark-shot
[ -x mark-shot/usr/lib/mark-shot/mark-shot ] || { echo "no usr/lib/mark-shot/mark-shot in the tarball" >&2; exit 1; }
[ -f mark-shot/usr/lib/mark-shot/media/libmarkshot-media.so ] || { echo "no media runtime in the tarball" >&2; exit 1; }

rm -rf stage mark-shot.tar.gz
