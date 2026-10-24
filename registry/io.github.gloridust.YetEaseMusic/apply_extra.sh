#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# official Linux tarball has one versioned top directory holding a relocatable
# Flutter bundle under bundle/ (the launcher, bundle/lib with the Flutter
# engine and the Rust core, bundle/data with flutter_assets), plus install.sh,
# icons and a desktop entry meant for a per-user install. Only bundle/ is kept,
# at a fixed path; the wrapper, desktop entry, icon and metainfo are installed
# by the manifest at build time, because anything Flatpak must export cannot
# come from here.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=yetease-music-linux.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf stage bundle
mkdir stage
# --no-same-owner: the tarball records the build machine's uid/gid (1001), and a
# system-wide install runs apply_extra as root with every capability dropped, so
# restoring that ownership would abort the unpack.
bsdtar --no-same-owner -xf "$archive" -C stage

# The top directory carries the version; match it instead of naming it.
top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ -n "$top" ] && [ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || { echo "expected one top-level directory" >&2; exit 1; }
[ -d "$top/bundle/data/flutter_assets" ] || { echo "Flutter assets not found in archive" >&2; exit 1; }
[ -d "$top/bundle/lib" ] || { echo "Flutter library directory not found in archive" >&2; exit 1; }
mv "$top/bundle" bundle

# The launcher is named after the Flutter project and is the only executable
# file at the top of the bundle. Read it out of the archive rather than
# hardcoding it, since pin refreshes are merged without a human, and record it
# for the wrapper.
launcher=
for candidate in bundle/*; do
  [ -f "$candidate" ] && [ -x "$candidate" ] || continue
  [ -z "$launcher" ] || { echo "more than one executable at the top of bundle/" >&2; exit 1; }
  launcher="${candidate#bundle/}"
done
[ -n "$launcher" ] || { echo "no executable found at the top of bundle/" >&2; exit 1; }
printf '%s\n' "$launcher" > yetease-launcher

rm -rf stage "$archive"
