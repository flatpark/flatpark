#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's official
# Linux tarball is flat, with no top directory: the mygo-cloudmusic executable
# (a Go binary that loads GTK 3 and the rest from the runtime at start), its
# desktop entry and two copies of the icon. Only the executable is kept, at a
# fixed path; the desktop entry, icon and metainfo are installed by the
# manifest at build time, because anything Flatpak must export cannot come
# from here.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=mygo-cloudmusic.tar.gz
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf stage app
mkdir stage app
# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring the archive's ownership could abort it.
bsdtar --no-same-owner -xf "$archive" -C stage

# The executable is named in the archive's own desktop entry; read it from
# there rather than hardcoding it, since pin refreshes are merged without a
# human.
entry="$(find stage -maxdepth 2 -name '*.desktop' -type f)"
[ -n "$entry" ] && [ "$(printf '%s\n' "$entry" | wc -l)" -eq 1 ] || { echo "expected one desktop entry in the archive" >&2; exit 1; }
bin="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$entry" | head -n1)"
case "$bin" in
  ''|*/*) echo "unexpected Exec= in $entry: $bin" >&2; exit 1 ;;
esac
src="$(dirname "$entry")/$bin"
[ -f "$src" ] && [ -x "$src" ] || { echo "executable $bin not found in the archive" >&2; exit 1; }
mv "$src" app/mygo-cloudmusic

rm -rf stage "$archive"
