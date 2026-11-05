#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Hyprlab's .deb lays
# Hylki out as usr/bin/hylki plus usr/share (message catalogues, icons, the
# desktop entry). The usr tree is kept whole: Hylki finds its translations at
# <exe dir>/../share/locale. The desktop entry, icons and metainfo the desktop
# sees are the package's own, installed at build time. Nothing in the .deb's
# maintainer scripts is needed; its apt source files under etc/ are dropped.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in hylki.deb poppler-glib.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf stage hylki poppler-glib
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's owner would abort it.
bsdtar -xOf hylki.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -f stage/usr/bin/hylki ] && [ -x stage/usr/bin/hylki ] ||
    { echo "usr/bin/hylki not found in the .deb" >&2; exit 1; }

mkdir hylki
mv stage/usr hylki/usr
rm -rf stage hylki.deb

# The prebuilt archive has one top-level poppler-glib/ directory holding lib/.
bsdtar --no-same-owner -xf poppler-glib.tar.xz
[ -e poppler-glib/lib/libpoppler-glib.so.8 ] ||
    { echo "libpoppler-glib.so.8 not found in poppler-glib.tar.xz" >&2; exit 1; }
rm -f poppler-glib.tar.xz
