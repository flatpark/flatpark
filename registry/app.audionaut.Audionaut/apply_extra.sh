#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# carries a single self-contained binary at usr/bin/audionaut (plus its desktop
# entry, icon and MIME definition, which the manifest ships at build time).
# Stage the binary at /app/extra/audionaut, unmodified.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f audionaut.deb ] || { echo "missing extra-data: audionaut.deb" >&2; exit 1; }

rm -rf deb audionaut
mkdir deb
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf audionaut.deb -C deb
data=$(ls deb/data.tar.* 2>/dev/null | head -n1)
[ -n "$data" ] || { echo "data.tar.* missing from audionaut.deb" >&2; exit 1; }
mkdir deb/data
bsdtar --no-same-owner -xf "$data" -C deb/data ./usr/bin/audionaut
[ -f deb/data/usr/bin/audionaut ] || { echo "usr/bin/audionaut missing after unpack" >&2; exit 1; }
mv deb/data/usr/bin/audionaut audionaut
chmod 755 audionaut
rm -rf deb audionaut.deb
