#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. Upstream's Tauri .deb
# is a plain FHS tree: the binary under usr/bin (named "app" in 4.x) plus icons
# and a desktop entry under usr/share. The binary name is read from the
# vendor's own .desktop Exec line rather than written down here.
#
# The usr tree is kept whole, so Tauri's resource lookup
# (<exe dir>/../lib/<product name>) stays inside /app/extra if a later release
# adds a resource tree.
#
# A symlink named after the app id gives the wrapper a fixed entry point. Its
# name becomes the program name, and with it the window class that the desktop
# entry's StartupWMClass matches.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }

rm -rf stage telegram-drive
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root with
# every capability dropped and cannot restore archive ownership.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

desktop=$(find stage/usr/share/applications -name '*.desktop' | head -n 1)
[ -n "$desktop" ] || { echo "no .desktop in .deb" >&2; exit 1; }
binary=$(sed -n 's/^Exec=//p' "$desktop" | head -n 1 | sed 's/ %[A-Za-z]*$//; s:.*/::')
[ -n "$binary" ] && [ -x "stage/usr/bin/$binary" ] || {
  echo "launcher '$binary' from $desktop not found in usr/bin" >&2
  exit 1
}

mkdir telegram-drive
mv stage/usr telegram-drive/usr
ln -s "$binary" telegram-drive/usr/bin/com.cameronamer.telegramdrive
rm -rf stage app.deb
