#!/bin/sh
set -eu
# Install the unmodified PPA payload and Ubuntu support libraries offline.
# --no-same-owner also works for system installs as root without capabilities.
cd "${EXTRA_ROOT:-/app/extra}"
mkdir -p vlc
for deb in *.deb; do
    [ -f "$deb" ] || { echo "No VLC extra-data packages found" >&2; exit 1; }
    bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C vlc
done
[ -x vlc/usr/bin/vlc ] || { echo "VLC executable missing" >&2; exit 1; }
[ -f vlc/usr/lib/x86_64-linux-gnu/vlc/plugins/gui/libqt_plugin.so ] || {
    echo "VLC Qt interface missing" >&2; exit 1;
}
[ -f vlc/usr/lib/x86_64-linux-gnu/libQt6Core.so.6 ] || {
    echo "Qt support libraries missing" >&2; exit 1;
}
rm -f ./*.deb
