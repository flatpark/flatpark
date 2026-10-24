#!/bin/sh
set -eu

# Runs offline at install time. The upstream package is a Debian archive: the
# Tauri binary and the bundled CLI live in usr/bin, and the desktop backend
# plus remote helpers live in usr/lib/Cline. Tauri resolves its resource
# directory as "<exe>/../lib/Cline", so that relative layout has to survive
# the move into /app/extra. The desktop file, icon and AppStream metainfo are
# installed by the manifest at build time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f cline.deb ] || { echo "missing extra-data: cline.deb" >&2; exit 1; }

rm -rf stage cline
mkdir stage
# The Platform runtime has no ar/dpkg. bsdtar reads the .deb ar container and
# the inner data.tar*. --no-same-owner: a system install runs apply_extra as
# root with every capability dropped, so restoring the archive's uid/gid fails
# even though the members themselves extracted.
bsdtar -xOf cline.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/usr/bin/cline-app ] || { echo "cline-app not found in .deb" >&2; exit 1; }
[ -f stage/usr/bin/cline-cli ] || { echo "cline-cli not found in .deb" >&2; exit 1; }
[ -f stage/usr/lib/Cline/bin/desktop-backend/index.js ] || { echo "desktop backend not found in .deb" >&2; exit 1; }

mkdir -p cline
mv stage/usr cline/usr
rm -rf stage cline.deb
chmod +x cline/usr/bin/cline-app cline/usr/bin/cline-cli
