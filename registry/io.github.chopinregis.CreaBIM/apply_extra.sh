#!/bin/sh
set -eu

# Runs offline at install time. The release ships one official Linux tar.gz.
# The top directory is named for the version and the build date, so it is
# moved to a stable path.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f creabim.tar.gz ] || { echo "missing extra-data: creabim.tar.gz" >&2; exit 1; }
rm -rf creabim stage
mkdir stage
bsdtar --no-same-owner --no-xattrs -xf creabim.tar.gz -C stage

set -- stage/CreaBIM-*-linux-x64/creabim
[ -x "$1" ] || { echo "creabim not found in the archive" >&2; exit 1; }
src=$(dirname "$1")
[ -x "$src/creabim-cli" ] || { echo "creabim-cli not found in the archive" >&2; exit 1; }
mv "$src" creabim
rm -rf stage creabim.tar.gz
chmod +x creabim/creabim creabim/creabim-cli
