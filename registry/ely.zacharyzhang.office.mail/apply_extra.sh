#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# is a linuxdeploy AppDir laid out under /opt/ely-office/ely-mail: bin/ holds
# ely-mail, lib/ the libraries linuxdeploy bundled (found through RUNPATH
# $ORIGIN/../lib), so the tree is kept whole at /app/extra/ely-mail; the
# wrapper starts /app/extra/ely-mail/bin/ely-mail.
#
# The desktop file, icon and metainfo are shipped by the manifest at build
# time; nothing Flatpak exports can come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ely-mail.deb ] || { echo "missing extra-data: ely-mail.deb" >&2; exit 1; }

rm -rf stage ely-mail
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring recorded owners would abort the unpack.
bsdtar -xOf ely-mail.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/ely-office/ely-mail/bin/ely-mail ] || { echo "ely-mail not found in .deb" >&2; exit 1; }
mv stage/opt/ely-office/ely-mail ely-mail
rm -rf stage ely-mail.deb
