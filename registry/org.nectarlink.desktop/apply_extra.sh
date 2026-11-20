#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The tarball is
# upstream's portable build: one versioned top directory holding the
# nectarlink-desktop executable, its own Qt 6 (lib/, plugins/, qml/ and a
# qt.conf that points at them) and the dlopen'd FFmpeg adapters. Rename it to a
# stable path so the wrapper can exec it across updates. Nothing is patched.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f nectarlink.tar.gz ] || { echo "missing extra-data: nectarlink.tar.gz" >&2; exit 1; }
[ -f krb5-gss.tar.xz ] || { echo "missing extra-data: krb5-gss.tar.xz" >&2; exit 1; }

# GSSAPI libraries the bundled libQt6Network links against (see the manifest).
# --strip-components=1 drops the archive's single top-level directory, leaving
# lib/ at the root of krb5-gss/; the wrapper points LD_LIBRARY_PATH there.
rm -rf krb5-gss
mkdir krb5-gss
bsdtar --no-same-owner --strip-components=1 -xf krb5-gss.tar.xz -C krb5-gss
[ -e krb5-gss/lib/libgssapi_krb5.so.2 ] || { echo "krb5-gss.tar.xz has no lib/libgssapi_krb5.so.2" >&2; exit 1; }
rm -f krb5-gss.tar.xz

rm -rf stage nectarlink
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf nectarlink.tar.gz -C stage

# The top directory carries the version (Nectarlink-<version>-linux-x86_64);
# match it, and insist on exactly one.
set -- stage/Nectarlink-*-linux-*
[ "$#" -eq 1 ] && [ -d "$1" ] || { echo "expected one Nectarlink-*-linux-* directory in the tarball" >&2; exit 1; }
mv "$1" nectarlink
[ -x nectarlink/nectarlink-desktop ] || { echo "no nectarlink-desktop in the tarball" >&2; exit 1; }
[ -f nectarlink/qt.conf ] || { echo "no qt.conf in the tarball" >&2; exit 1; }
[ -e nectarlink/lib/libQt6Core.so.6 ] || { echo "no bundled Qt in the tarball" >&2; exit 1; }

# The tarball's install.sh / uninstall.sh copy the tree into /opt or
# ~/.local; they are never run here.
rm -rf stage nectarlink.tar.gz
