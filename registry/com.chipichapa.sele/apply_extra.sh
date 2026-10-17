#!/bin/sh
set -eu

# Offline install-time extraction of the official Electron tarball. Preserve
# the complete app tree; no app files are patched or rebuilt. Since 3.7 the
# tarball wraps the app in a sele-linux-x64/ directory; older ones have it at
# the root, so accept either.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f sele.tar.gz ] || { echo "missing extra-data: sele.tar.gz" >&2; exit 1; }
rm -rf sele
mkdir sele
# System installs run as root with all capabilities dropped; do not chown.
tar --no-same-owner -xzf sele.tar.gz -C sele
if [ -d sele/sele-linux-x64 ]; then
    mv sele sele.unpack
    mv sele.unpack/sele-linux-x64 sele
    rm -rf sele.unpack
fi
[ -x sele/sele ] && [ -f sele/resources/app.asar ] \
    || { echo "Sele executable or resources missing from tarball" >&2; exit 1; }
rm -f sele.tar.gz
