#!/bin/sh
set -eu

# Runs offline at install time inside org.kde.Platform. Three pinned artifacts
# arrive here and are unpacked into stable paths the wrapper expects:
#
#   heidisql.tgz        -> /app/extra/heidisql/        upstream's official qt6 build
#   libqt6pas.deb       -> /app/extra/qt6pas/lib/      the Lazarus Qt6 C bindings
#   sql-clients.tar.xz  -> /app/extra/sql-clients/     libmariadb, libpq, libsybdb, sshpass
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.
#
# --no-same-owner everywhere: on a system-wide install Flatpak runs apply_extra
# as root with every capability dropped, so restoring the uid recorded in an
# archive fails and aborts the unpack even though every member extracted fine.
# Upstream's tarball records uid 1001 (its CI runner), which trips exactly that.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in heidisql.tgz libqt6pas.deb sql-clients.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

# Upstream's tarball is flat - the binary, the functions-*.ini reference files,
# locale/ and the icon all sit at the archive root - and the binary looks for
# those resources next to itself, so give it a directory of its own.
rm -rf heidisql
mkdir heidisql
tar --no-same-owner -xzf heidisql.tgz -C heidisql
[ -x heidisql/heidisql ] || { echo "heidisql binary not found in heidisql.tgz" >&2; exit 1; }
[ -d heidisql/locale ] || { echo "locale/ not found in heidisql.tgz" >&2; exit 1; }
rm -f heidisql.tgz

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (inner data.tar compression is auto-detected). Only the library itself is
# kept - the .deb also carries headers-free docs and a changelog.
rm -rf qt6pas usr
bsdtar -xOf libqt6pas.deb 'data.tar*' | bsdtar --no-same-owner -xf -
mkdir -p qt6pas/lib
find usr -name 'libQt6Pas.so.6*' -exec mv {} qt6pas/lib/ \;
rm -rf usr
[ -e qt6pas/lib/libQt6Pas.so.6 ] || { echo "libQt6Pas.so.6 not found in libqt6pas.deb" >&2; exit 1; }
rm -f libqt6pas.deb

# FlatPark's prebuilt SQL client stack (see the manifest). The archive's single
# top-level directory is the stack name, so it unpacks straight to
# sql-clients/lib/... and sql-clients/bin/sshpass.
rm -rf sql-clients
tar --no-same-owner -xJf sql-clients.tar.xz -C .
for f in sql-clients/lib/libmariadb.so.3 sql-clients/lib/libpq.so.5 \
         sql-clients/lib/libsybdb.so.5 sql-clients/bin/sshpass; do
    [ -e "$f" ] || { echo "sql-clients.tar.xz did not yield $f" >&2; exit 1; }
done
rm -f sql-clients.tar.xz
