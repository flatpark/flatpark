#!/bin/sh
set -eu

# Keep the official jpackage tree, including its Java runtime, unmodified.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f projectlibre.deb ] || { echo 'missing extra-data: projectlibre.deb' >&2; exit 1; }
mkdir -p stage
# The runtime reads both the ar container and its compressed data member.
# System installs run as root without capabilities: never restore ownership.
bsdtar -xOf projectlibre.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
# Read the install root from upstream's desktop entry rather than a versioned path.
set -- stage/opt/*/lib/*-ProjectLibre.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo 'expected one ProjectLibre desktop entry' >&2; exit 1; }
launcher="$(sed -n 's/^Exec=//p' "$1")"
case "$launcher" in
    /opt/*/bin/ProjectLibre) ;;
    *) echo "unexpected ProjectLibre launcher: $launcher" >&2; exit 1 ;;
esac
app_root="stage${launcher%/bin/ProjectLibre}"
[ -x "stage$launcher" ] && [ -f "$app_root/lib/runtime/lib/server/libjvm.so" ] \
    && [ -f "$app_root/lib/app/ProjectLibre.cfg" ] \
    || { echo 'ProjectLibre launcher or bundled runtime missing' >&2; exit 1; }
mv "$app_root" projectlibre
rm -rf stage projectlibre.deb
