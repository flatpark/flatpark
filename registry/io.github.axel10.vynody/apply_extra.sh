#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# official Linux tarball is one complete, relocatable Flutter bundle: the
# launcher at the top of bundle/, next to bundle/lib (the Flutter engine, the
# Rust audio core and its bundled FFmpeg) and bundle/data (icudtl.dat plus
# flutter_assets). Keep that payload byte-for-byte under /app/extra; the
# wrapper, desktop entry, icon and metainfo are installed by the manifest at
# build time, because extra-data is fetched later on the user's machine and
# anything Flatpak must export cannot come from here.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=vynody-linux.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf bundle
# --no-same-owner: the tarball records the build machine's uid/gid (1001), and a
# system-wide install runs apply_extra as root with every capability dropped, so
# restoring that ownership fails and aborts the unpack even though every member
# extracted fine.
tar --no-same-owner -xzf "$archive"

[ -d bundle/data/flutter_assets ] || { echo "Flutter assets not found in archive" >&2; exit 1; }
[ -d bundle/lib ] || { echo "Flutter library directory not found in archive" >&2; exit 1; }

# The launcher is named after the Flutter project and is the only executable
# file at the top of the bundle. Read it out of the archive instead of writing
# the current name into this script or the wrapper: pin refreshes are automated,
# so a rename upstream would otherwise ship a release nobody can start. Record
# it for the wrapper, which cannot inspect the payload itself.
launcher=
for candidate in bundle/*; do
  [ -f "$candidate" ] && [ -x "$candidate" ] || continue
  launcher="${candidate#bundle/}"
  break
done
[ -n "$launcher" ] || { echo "no executable found at the top of bundle/" >&2; exit 1; }
printf '%s\n' "$launcher" > vynody-launcher

rm -f "$archive"
