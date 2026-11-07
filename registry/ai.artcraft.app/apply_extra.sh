#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships
# the official Linux build as a .tar.gz with a single version-stamped top
# directory (artcraft-<ver>-linux-<arch>/) holding bin/artcraft and a share/ tree.
# Rename that directory to a stable path the wrappers exec across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=artcraft.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

tar --no-same-owner -xzf "$archive"
app_dir="$(find . -maxdepth 1 -type d -name 'artcraft-*' | sort | head -n1)"
[ -n "$app_dir" ] || { echo "no artcraft-* directory in tarball" >&2; exit 1; }

rm -rf artcraft
mv "$app_dir" artcraft

[ -x "artcraft/bin/artcraft" ] || { echo "artcraft/bin/artcraft not found in tarball" >&2; exit 1; }

rm -f "$archive"
