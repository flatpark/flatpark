#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The tarball is the
# official Linux build: a flat archive (no top directory) with the single
# mygo-music executable, its desktop entry and icons. Unpack it into a fixed
# directory the wrapper execs across updates. The desktop entry, icon and
# metainfo are shipped by the manifest at build time instead.
# The vendor's bytes run unmodified.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f mygo-music.tar.gz ] || { echo "missing extra-data: mygo-music.tar.gz" >&2; exit 1; }

rm -rf stage app
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf mygo-music.tar.gz -C stage

# Tolerate a future archive that wraps the files in one top directory.
if [ -f stage/mygo-music ]; then
  mv stage app
else
  top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
  [ -n "$top" ] && [ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || { echo "unexpected archive layout" >&2; exit 1; }
  mv "$top" app
  rm -rf stage
fi
[ -x app/mygo-music ] || { echo "mygo-music binary not found in the tarball" >&2; exit 1; }

rm -f mygo-music.tar.gz
