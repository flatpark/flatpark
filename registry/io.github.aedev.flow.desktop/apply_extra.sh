#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. Upstream's Tauri .deb
# is a plain FHS tree: the binary under usr/bin plus a resource tree under
# usr/lib/<product name> (the integrity sidecar script). The product name is
# "Flow Beta" for prerelease builds and "Flow" for stable ones, so neither it
# nor the binary name is written down here.
#
# The tree is staged whole, keeping the usr/bin + usr/lib layout, because Tauri
# finds its resources relative to the executable: its Linux resource dir is the
# first of <exe dir>/../lib/<name> (only if it exists), $APPDIR/usr/lib/<name>,
# or /usr/lib/<name>. Staged at /app/extra/flow/usr/bin, the first branch
# resolves inside /app/extra. The binary name is read from the vendor's own
# .desktop Exec line, and a symlink named after the app id gives the wrapper a
# fixed entry point.
#
# The symlink's name becomes the program name, and with it the window class and
# the id WebKitGTK uses for its MPRIS player
# (org.mpris.MediaPlayer2.<id>.Sandboxed.*). Flow sets no GApplication id, so a
# name without dots makes WebKit hash the executable path into
# org.webkit.app-<hash>. Flatpak only lets the app own MPRIS names under its
# own id, so media controls would never see the player.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }

rm -rf stage flow
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
[ -n "$(find stage/usr/lib -mindepth 1 -maxdepth 1 -type d)" ] || {
  echo "no resource tree under usr/lib in .deb" >&2
  exit 1
}

mkdir flow
mv stage/usr flow/usr
ln -s "$binary" flow/usr/bin/io.github.aedev.flow.desktop
rm -rf stage app.deb
