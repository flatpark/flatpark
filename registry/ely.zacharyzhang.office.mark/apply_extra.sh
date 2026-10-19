#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# is a linuxdeploy AppDir laid out under /opt/ely-office/ely-mark: bin/ holds
# ely-mark and the bundled Git, lib/ the libraries
# linuxdeploy bundled (found through RUNPATH $ORIGIN/../lib). The binary looks
# for its helpers next to itself, so the tree is kept whole at
# /app/extra/ely-mark; the wrapper starts /app/extra/ely-mark/bin/ely-mark.
#
# The desktop file, icon and metainfo are shipped by the manifest at build
# time; nothing Flatpak exports can come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ely-mark.deb ] || { echo "missing extra-data: ely-mark.deb" >&2; exit 1; }

rm -rf stage ely-mark
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring recorded owners would abort the unpack.
bsdtar -xOf ely-mark.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/ely-office/ely-mark/bin/ely-mark ] || { echo "ely-mark not found in .deb" >&2; exit 1; }
mv stage/opt/ely-office/ely-mark ely-mark
rm -rf stage ely-mark.deb
