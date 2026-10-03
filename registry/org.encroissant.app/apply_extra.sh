#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. Upstream's Tauri .deb
# is a plain FHS tree: the binary under usr/bin plus a resource tree under
# usr/lib/en-croissant (the move and capture sounds).
#
# The tree is staged whole, keeping the usr/bin + usr/lib layout, because Tauri
# finds its resources relative to the executable: its Linux resource dir is the
# first of <exe dir>/../lib/<name> (only if it exists), $APPDIR/usr/lib/<name>,
# or /usr/lib/<name>. Staged at /app/extra/en-croissant/usr/bin, the first branch
# resolves inside /app/extra. The binary's name is read from the vendor's own
# .desktop Exec line, and a `launch` symlink gives the wrapper a fixed entry
# point.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || { echo "missing extra-data: app.deb" >&2; exit 1; }

rm -rf stage en-croissant
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
[ -d "stage/usr/lib/$binary" ] || {
  echo "resource tree usr/lib/$binary not found in .deb" >&2
  exit 1
}

mkdir en-croissant
mv stage/usr en-croissant/usr
ln -s "$binary" en-croissant/usr/bin/launch
rm -rf stage app.deb
