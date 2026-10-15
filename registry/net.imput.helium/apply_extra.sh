#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=""
for candidate in helium-*.tar.xz; do
    [ -f "$candidate" ] || continue
    [ -z "$archive" ] || { echo "multiple Helium archives found" >&2; exit 1; }
    archive="$candidate"
done
[ -n "$archive" ] || { echo "missing Helium extra-data archive" >&2; exit 1; }

rm -rf stage helium
mkdir stage
# The runtime ships bsdtar. --no-same-owner is required for system installs,
# where apply_extra runs as root without CAP_CHOWN.
bsdtar --no-same-owner --strip-components 1 -xf "$archive" -C stage
[ -x stage/helium ] || { echo "helium binary not found in Helium archive" >&2; exit 1; }

mv stage helium
rm -f "$archive"
