#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=""
for candidate in brave-origin-*.zip; do
    [ -f "$candidate" ] || continue
    [ -z "$archive" ] || { echo "multiple Brave Origin archives found" >&2; exit 1; }
    archive="$candidate"
done
[ -n "$archive" ] || { echo "missing Brave Origin extra-data archive" >&2; exit 1; }

rm -rf stage brave
mkdir stage
# The runtime ships bsdtar. --no-same-owner is required for system installs,
# where apply_extra runs as root without CAP_CHOWN.
bsdtar --no-same-owner -xf "$archive" -C stage
[ -x stage/brave ] || { echo "brave launcher not found in Brave Origin archive" >&2; exit 1; }

mv stage brave
rm -f "$archive"
