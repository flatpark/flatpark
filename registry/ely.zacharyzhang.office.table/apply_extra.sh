#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# is a linuxdeploy AppDir laid out under /opt/ely-office/ely-table: bin/ holds
# ely-table and ely-lok-worker and the LibreOffice kernel, lib/ the libraries
# linuxdeploy bundled (found through RUNPATH $ORIGIN/../lib). The binary looks
# for its helpers next to itself, so the tree is kept whole at
# /app/extra/ely-table; the wrapper starts /app/extra/ely-table/bin/ely-table.
#
# The desktop file, icon and metainfo are shipped by the manifest at build
# time; nothing Flatpak exports can come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ely-table.deb ] || { echo "missing extra-data: ely-table.deb" >&2; exit 1; }

rm -rf stage ely-table
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring recorded owners would abort the unpack.
bsdtar -xOf ely-table.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/ely-office/ely-table/bin/ely-table ] || { echo "ely-table not found in .deb" >&2; exit 1; }
[ -x stage/opt/ely-office/ely-table/bin/ely-lok-worker ] || { echo "ely-lok-worker not found in .deb" >&2; exit 1; }
[ -d stage/opt/ely-office/ely-table/bin/libreoffice/program ] || { echo "bundled LibreOffice not found in .deb" >&2; exit 1; }
mv stage/opt/ely-office/ely-table ely-table
rm -rf stage ely-table.deb

# GSSAPI libraries the bundled LibreOffice's libcurl links against (see the
# manifest). --strip-components=1 drops the archive's top-level directory,
# leaving lib/ at the root of krb5-gss/.
[ -f krb5-gss.tar.xz ] || { echo "missing extra-data: krb5-gss.tar.xz" >&2; exit 1; }
rm -rf krb5-gss
mkdir krb5-gss
tar --no-same-owner --strip-components=1 -xJf krb5-gss.tar.xz -C krb5-gss
[ -e krb5-gss/lib/libgssapi_krb5.so.2 ] || { echo "krb5-gss.tar.xz has no lib/libgssapi_krb5.so.2" >&2; exit 1; }
rm -f krb5-gss.tar.xz
