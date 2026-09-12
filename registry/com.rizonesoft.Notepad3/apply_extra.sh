#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. One pinned
# artifact arrives here and is unpacked to a stable path the wrapper expects:
#
#   notepad3.zip -> /app/extra/notepad3/   upstream's official x64 portable zip
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.
#
# bsdtar (libarchive) reads the zip directly; the runtime has no unzip. The zip
# carries no unix uid/gid members, but --no-same-owner is kept anyway: a
# system-wide install runs apply_extra as root with every capability dropped,
# and restoring any ownership the archive might record would abort the unpack.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f notepad3.zip ] || { echo "missing extra-data: notepad3.zip" >&2; exit 1; }

rm -rf notepad3
mkdir notepad3
bsdtar --no-same-owner -xf notepad3.zip -C notepad3

# The zip is flat - Notepad3.exe, the portable-mode Notepad3.ini, minipath.exe,
# np3encrypt.exe, Docs/, Favorites/, Themes/, grepWin/ and the lng/ catalogues
# all sit at the archive root. Not a name the payload owns is hardcoded beyond
# the launcher itself, which the wrapper reads from a stable, renamed path.
[ -f notepad3/Notepad3.exe ] || { echo "Notepad3.exe not found in notepad3.zip" >&2; exit 1; }
[ -f notepad3/Notepad3.ini ] || { echo "Notepad3.ini not found in notepad3.zip" >&2; exit 1; }

rm -f notepad3.zip
