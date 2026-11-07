#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# Linux tarball has no top directory: the tracedraw and tracedraw-cli binaries
# sit at its root. Move them to a stable path the wrappers exec across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=tracedraw.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf stage tracedraw
mkdir stage
# --no-same-owner: the tarball records uid 1001, and a system-wide install runs
# this as root with every capability dropped, so restoring it would abort.
tar --no-same-owner -xzf "$archive" -C stage

for b in tracedraw tracedraw-cli; do
  [ -x "stage/$b" ] || { echo "$b binary not found in the tarball" >&2; exit 1; }
done

mv stage tracedraw
rm -f "$archive"
