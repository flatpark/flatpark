#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# is a linuxdeploy AppDir laid out under /opt/ely-office/ely-pdf: bin/ holds
# ely-pdf, ely-pdf-worker, lib/ the libraries
# linuxdeploy bundled (found through RUNPATH $ORIGIN/../lib). The binary looks
# for its helpers next to itself, so the tree is kept whole at
# /app/extra/ely-pdf; the wrapper starts /app/extra/ely-pdf/bin/ely-pdf.
#
# The desktop file, icon and metainfo are shipped by the manifest at build
# time; nothing Flatpak exports can come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ely-pdf.deb ] || { echo "missing extra-data: ely-pdf.deb" >&2; exit 1; }

rm -rf stage ely-pdf
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring recorded owners would abort the unpack.
bsdtar -xOf ely-pdf.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/ely-office/ely-pdf/bin/ely-pdf ] || { echo "ely-pdf not found in .deb" >&2; exit 1; }
mv stage/opt/ely-office/ely-pdf ely-pdf
rm -rf stage ely-pdf.deb
