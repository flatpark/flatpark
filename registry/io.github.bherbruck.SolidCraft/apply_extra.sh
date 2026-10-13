#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the official Linux build as a .tar.gz with a single version-stamped top
# directory (solidcraft-<ver>-linux-<arch>/) holding bin/solidcraft,
# bin/solidcraft-cli and a share/ tree. Rename that directory to a stable path
# the wrappers exec across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=solidcraft.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

# --no-same-owner: the tarball records a non-root owner (uid 1001),
# and on a system-wide install Flatpak runs apply_extra as root with every
# capability dropped, so restoring that owner fails and aborts the unpack.
tar --no-same-owner -xzf "$archive"
app_dir="$(find . -maxdepth 1 -type d -name 'solidcraft-*' | sort | head -n1)"
[ -n "$app_dir" ] || { echo "no solidcraft-* directory in tarball" >&2; exit 1; }

rm -rf solidcraft
mv "$app_dir" solidcraft

for b in solidcraft solidcraft-cli; do
  [ -x "solidcraft/bin/$b" ] || { echo "solidcraft/bin/$b not found in tarball" >&2; exit 1; }
done

rm -f "$archive"
