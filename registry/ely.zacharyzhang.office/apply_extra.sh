#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# lays the suite out under /opt/ely-office: one directory per app (ely-doc,
# ely-table, ely-show, ely-pdf, ely-mark, ely-tree, ely-mail), each with bin/
# and the few libraries linuxdeploy bundled in lib/ (found through RUNPATH
# $ORIGIN/../lib), and one LibreOffice kernel in libreoffice/ that ElyDoc,
# ElyTable and ElyShow share. Each of those three finds the kernel through
# bin/libreoffice, a symlink the .deb points at the absolute
# /opt/ely-office/libreoffice; inside the sandbox that path does not exist, so
# the tree is kept whole at /app/extra/ely-office and the three links are
# pointed at ../../libreoffice instead. The wrapper starts
# /app/extra/ely-office/<app>/bin/<app>.
#
# /usr/bin, the .desktop files, icons and the systemd user unit from the .deb
# are dropped: the manifest ships the desktop files, icons and metainfo at
# build time, and nothing Flatpak exports can come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ely-office.deb ] || { echo "missing extra-data: ely-office.deb" >&2; exit 1; }

rm -rf stage ely-office
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring recorded owners would abort the unpack.
# Only ./opt is unpacked.
bsdtar -xOf ely-office.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage ./opt
for app in ely-doc ely-table ely-show ely-pdf ely-mark ely-tree ely-mail; do
  [ -x "stage/opt/ely-office/$app/bin/$app" ] || { echo "$app not found in .deb" >&2; exit 1; }
done
[ -d stage/opt/ely-office/libreoffice/program ] || { echo "bundled LibreOffice not found in .deb" >&2; exit 1; }
mv stage/opt/ely-office ely-office
rm -rf stage ely-office.deb

for app in ely-doc ely-table ely-show; do
  [ -x "ely-office/$app/bin/ely-lok-worker" ] || { echo "$app has no ely-lok-worker" >&2; exit 1; }
  ln -sfn ../../libreoffice "ely-office/$app/bin/libreoffice"
  [ -d "ely-office/$app/bin/libreoffice/program" ] || { echo "$app/bin/libreoffice does not resolve" >&2; exit 1; }
done

# GSSAPI libraries the bundled LibreOffice's libcurl links against (see the
# manifest). --strip-components=1 drops the archive's top-level directory,
# leaving lib/ at the root of krb5-gss/.
[ -f krb5-gss.tar.xz ] || { echo "missing extra-data: krb5-gss.tar.xz" >&2; exit 1; }
rm -rf krb5-gss
mkdir krb5-gss
tar --no-same-owner --strip-components=1 -xJf krb5-gss.tar.xz -C krb5-gss
[ -e krb5-gss/lib/libgssapi_krb5.so.2 ] || { echo "krb5-gss.tar.xz has no lib/libgssapi_krb5.so.2" >&2; exit 1; }
rm -f krb5-gss.tar.xz
