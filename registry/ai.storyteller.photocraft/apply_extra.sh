#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the official Linux build as a .tar.gz with a single version-stamped top
# directory (photocraft-<ver>-linux-<arch>/) holding bin/photocraft,
# bin/photocraft-cli and a share/ tree. Rename that directory to a stable path
# the wrappers exec across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=photocraft-x86_64.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

# --no-same-owner: the tarball records uid/gid 1001, and on a system-wide
# install Flatpak runs apply_extra as root with every capability dropped, so
# restoring that owner fails and aborts the unpack.
tar --no-same-owner -xzf "$archive"
app_dir="$(find . -maxdepth 1 -type d -name 'photocraft-*' | sort | head -n1)"
[ -n "$app_dir" ] || { echo "no photocraft-* directory in tarball" >&2; exit 1; }

rm -rf photocraft
mv "$app_dir" photocraft

for b in photocraft photocraft-cli; do
  [ -x "photocraft/bin/$b" ] || { echo "photocraft/bin/$b not found in tarball" >&2; exit 1; }
done

rm -f "$archive"
