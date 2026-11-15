#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# carries the binary at usr/bin/flectar-mail and the PDF preview library at
# usr/lib/flectar-mail/libpdfium.so; the binary looks for that library at
# ../lib/flectar-mail relative to itself, so the usr tree is staged as is at
# /app/extra/flectar-mail, unmodified. The desktop entry, icons and metainfo
# are shipped by the manifest at build time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f flectar-mail.deb ] || { echo "missing extra-data: flectar-mail.deb" >&2; exit 1; }

rm -rf deb flectar-mail
mkdir deb
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf flectar-mail.deb -C deb
data=$(ls deb/data.tar.* 2>/dev/null | head -n1)
[ -n "$data" ] || { echo "data.tar.* missing from flectar-mail.deb" >&2; exit 1; }
mkdir deb/data
bsdtar --no-same-owner -xf "$data" -C deb/data ./usr/bin ./usr/lib
[ -x deb/data/usr/bin/flectar-mail ] || { echo "usr/bin/flectar-mail missing after unpack" >&2; exit 1; }
[ -f deb/data/usr/lib/flectar-mail/libpdfium.so ] || { echo "usr/lib/flectar-mail/libpdfium.so missing after unpack" >&2; exit 1; }
mv deb/data/usr flectar-mail
rm -rf deb flectar-mail.deb
