#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the official Linux build as a .tar.gz with a single version-stamped top
# directory (wordcraft-<ver>-linux-<arch>/) holding bin/wordcraft,
# bin/wordcraft-cli and a share/ tree. Rename that directory to a stable path
# the wrappers exec across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=wordcraft-x86_64.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

# --no-same-owner: the tarball records a non-root owner, and on a system-wide
# install Flatpak runs apply_extra as root with every capability dropped, so
# restoring that owner fails and aborts the unpack.
tar --no-same-owner -xzf "$archive"
app_dir="$(find . -maxdepth 1 -type d -name 'wordcraft-*' | sort | head -n1)"
[ -n "$app_dir" ] || { echo "no wordcraft-* directory in tarball" >&2; exit 1; }

rm -rf wordcraft
mv "$app_dir" wordcraft

for b in wordcraft wordcraft-cli; do
  [ -x "wordcraft/bin/$b" ] || { echo "wordcraft/bin/$b not found in tarball" >&2; exit 1; }
done

rm -f "$archive"
