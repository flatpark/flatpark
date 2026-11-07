#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f voquill.deb ] || { echo "missing extra-data: voquill.deb" >&2; exit 1; }
mkdir stage
# Keep Tauri's binaries and sibling resource tree together, including both engines.
# System installs run as root without capabilities, so do not restore ownership.
bsdtar -xOf voquill.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
set -- stage/usr/share/applications/*.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "expected one upstream desktop entry" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=//p' "$1")"
case "$launcher" in ''|*[!a-zA-Z0-9_.-]*) echo "unsupported upstream launcher: $launcher" >&2; exit 1;; esac
[ -x "stage/usr/bin/$launcher" ] || { echo "upstream launcher missing: $launcher" >&2; exit 1; }
[ -x stage/usr/bin/rust-transcription-cpu ] || { echo "CPU transcription engine missing" >&2; exit 1; }
[ -x stage/usr/bin/rust-transcription-gpu ] || { echo "GPU transcription engine missing" >&2; exit 1; }
[ -d stage/usr/lib ] || { echo "Tauri resource tree missing" >&2; exit 1; }
mv stage/usr voquill
# The app-id launcher gives GTK windows a stable desktop class.
ln -s "$launcher" voquill/bin/com.voquill.desktop
mkdir helpers
for archive in libxdo3.deb xdotool.deb libgtk-layer-shell0.deb; do
    [ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }
    bsdtar -xOf "$archive" 'data.tar*' | bsdtar --no-same-owner -xf - -C helpers
    rm "$archive"
done
[ -x helpers/usr/bin/xdotool ] || { echo "xdotool missing" >&2; exit 1; }
rm -r stage
rm voquill.deb
