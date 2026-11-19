#!/bin/sh
# Unpacks the official Linux editor zip on the user's machine at install time.
# The zip holds a single self-contained binary at its root, named
# redot.linuxbsd.editor.<arch> (x86_64 or arm64). It is moved to a fixed path
# so the wrapper keeps working across updates and on both arches.
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f redot.zip ] || { echo "missing extra-data: redot.zip" >&2; exit 1; }

rm -rf stage redot
mkdir stage
# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring recorded owners would fail.
bsdtar --no-same-owner -xf redot.zip -C stage

# Match the editor binary by pattern rather than by arch suffix, and fail the
# update check if the layout changes (none, or more than one).
set -- stage/redot.linuxbsd.editor.*
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "expected exactly one redot.linuxbsd.editor.* in the zip, found: $*" >&2; exit 1; }

mkdir redot
mv "$1" redot/redot
chmod 755 redot/redot

rm -rf stage redot.zip
