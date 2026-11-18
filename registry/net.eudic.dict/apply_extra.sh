#!/bin/sh
set -eu

# Flatpak runs this offline in /app/extra; only this directory is writable.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f eudic.deb ] || { echo 'Missing Eudic deb' >&2; exit 1; }
mkdir stage
# bsdtar reads both the Debian archive and its compressed data member offline.
bsdtar -xOf eudic.deb 'data.tar*' | bsdtar --no-same-owner --no-same-permissions -xf - -C stage
app=stage/usr/share/eusoft-eudic
[ -x "$app/eudic" ] && [ -d "$app/lib" ] && \
    [ -d "$app/gstreamer-1.0" ] && \
    [ -x "$app/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner" ] || {
    echo 'Unexpected Eudic deb layout' >&2
    exit 1
}
mv "$app" eudic
rm -rf stage eudic.deb
