#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The official
# WPS Office .deb installs the suite to opt/kingsoft/wps-office/ and its
# launcher scripts (wps, et, wpp, wpspdf, misc) to usr/bin/. Each launcher
# looks for office6/ next to itself before falling back to /opt, so the
# launchers go into the suite directory and the suite needs no path changes.
# The desktop entries, icons, MIME types and metainfo are shipped by the
# manifest at build time: nothing exported can come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f wps-office.deb ] || { echo "missing extra-data: wps-office.deb" >&2; exit 1; }

rm -rf stage wps-office
mkdir stage
# The runtime has no ar/dpkg; bsdtar reads the .deb's ar container directly.
# Only the suite and its launchers are unpacked; the rest of the package is
# desktop integration for a host install (menus, MIME, templates, a browser
# plugin directory).
# --no-same-owner: a system-wide install runs this as root with no capabilities.
bsdtar -xOf wps-office.deb 'data.tar*' |
    bsdtar --no-same-owner -xf - -C stage './opt/kingsoft/wps-office' './usr/bin'

[ -x stage/opt/kingsoft/wps-office/office6/wps ] || {
    echo "office6/wps not found in .deb" >&2; exit 1; }
mv stage/opt/kingsoft/wps-office wps-office
for bin in wps et wpp wpspdf; do
    [ -f "stage/usr/bin/$bin" ] || { echo "usr/bin/$bin not found in .deb" >&2; exit 1; }
    mv "stage/usr/bin/$bin" wps-office/
done

# A plugin for the Peony file manager, loaded only by Peony itself; it links
# the host's Qt and libpeony, neither of which exists here.
rm -f wps-office/office6/libpeony-wpsprint-menu-plugin.so

rm -rf stage wps-office.deb
