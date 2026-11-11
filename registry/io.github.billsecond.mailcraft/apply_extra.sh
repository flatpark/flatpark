#!/bin/sh
set -eu

# Runs offline at install time. The release also ships a .flatpak bundle,
# which is an OSTree image this runtime cannot unpack, and an AppImage.
# This package uses the official tar.gz. The top directory is named for the
# version and the architecture, so it is moved to a stable path.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f mailcraft.tar.gz ] || { echo "missing extra-data: mailcraft.tar.gz" >&2; exit 1; }
rm -rf mailcraft stage
mkdir stage
bsdtar --no-same-owner --no-xattrs -xf mailcraft.tar.gz -C stage

set -- stage/mailcraft-*-linux-*/bin/mailcraft
[ -x "$1" ] || { echo "mailcraft not found in the archive" >&2; exit 1; }
src=$(dirname "$(dirname "$1")")
[ -x "$src/bin/mailcraft-cli" ] || { echo "mailcraft-cli not found in the archive" >&2; exit 1; }
mv "$src" mailcraft
rm -rf stage mailcraft.tar.gz
chmod +x mailcraft/bin/mailcraft mailcraft/bin/mailcraft-cli
