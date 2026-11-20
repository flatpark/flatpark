#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The official
# Linux tarball holds one versioned directory (fableflight-v<ver>-linux-<arch>/)
# with two self-contained binaries: fablegame, the simulator with its assets
# built in, and fableflight-mcp, the stdio bridge for AI copilots. Both are
# moved to the fixed directory /app/extra/fableflight that the wrappers use.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# build time: extra-data arrives later, so nothing Flatpak exports can come
# from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f fableflight.tar.gz ] || { echo "missing extra-data: fableflight.tar.gz" >&2; exit 1; }

rm -rf stage fableflight
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, and the archive records uid 1001; restoring
# it would abort the unpack.
bsdtar --no-same-owner -xf fableflight.tar.gz -C stage

# The versioned directory name changes every release, so find the simulator
# binary instead of naming the directory, and fail unless there is exactly one.
game="$(find stage -maxdepth 2 -type f -name fablegame)"
[ -n "$game" ] && [ "$(printf '%s\n' "$game" | wc -l)" -eq 1 ] || {
  echo "expected exactly one fablegame binary in the tarball" >&2
  exit 1
}
mv "$(dirname "$game")" fableflight
chmod 755 fableflight/fablegame
[ -f fableflight/fableflight-mcp ] && chmod 755 fableflight/fableflight-mcp

rm -rf stage fableflight.tar.gz
