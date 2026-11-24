#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. OpenXplorer's
# Debian package keeps the program in opt/openxplorer (bin/openxplorer plus
# helpers) and its translations in usr/share/locale. Keep both at a stable
# path: /app/extra/openxplorer, with the translations in its share/locale,
# which the wrapper adds to XDG_DATA_DIRS. The desktop entry, icon, metainfo
# and D-Bus service file come from the manifest at build time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f openxplorer.deb ] || { echo "missing extra-data: openxplorer.deb" >&2; exit 1; }

rm -rf stage openxplorer
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# --no-same-owner: a system-wide install runs this as root with no capabilities.
bsdtar -xOf openxplorer.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
[ -x stage/opt/openxplorer/bin/openxplorer ] || { echo "openxplorer not found in .deb" >&2; exit 1; }
mv stage/opt/openxplorer openxplorer
mkdir -p openxplorer/share
if [ -d stage/usr/share/locale ]; then
  mv stage/usr/share/locale openxplorer/share/locale
fi
rm -rf stage openxplorer.deb
