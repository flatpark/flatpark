#!/bin/sh
set -eu

# Runs offline at install time, inside org.gnome.Platform. On a system-wide
# install Flatpak runs it as root with every capability dropped, so every
# extraction uses --no-same-owner: restoring the archive's recorded uid/gid
# fails there and aborts an otherwise fine unpack.
#
# Two downloads land beside this script:
#   ffmpeg-full.tar.xz     flatpark/prebuilt's FFmpeg, which the viewer runs as
#                          a child process to decode H.264/H.265 and audio.
#   uu-remote-linux.tar.gz upstream's release, a single version-stamped
#                          top-level directory holding the viewer and the host.
#
# Only the viewer is exposed as an entry point (see the manifest); the host
# binary stays in the tree because the viewer's QR sign-in runs it as
# `uuremote-server login`.

cd /app/extra

[ -f ffmpeg-full.tar.xz ] || { echo "missing extra-data: ffmpeg-full.tar.xz" >&2; exit 1; }
[ -f uu-remote-linux.tar.gz ] || { echo "missing extra-data: uu-remote-linux.tar.gz" >&2; exit 1; }

# The stack keeps one top-level directory named after itself, so a plain
# extract puts ffmpeg-full/bin and ffmpeg-full/lib exactly where the launcher
# expects them.
rm -rf ffmpeg-full
bsdtar --no-same-owner -xf ffmpeg-full.tar.xz
[ -x ffmpeg-full/bin/ffmpeg ] || { echo "ffmpeg missing after unpacking ffmpeg-full.tar.xz" >&2; exit 1; }
rm -f ffmpeg-full.tar.xz

# The release's top-level directory carries the version and the architecture,
# both of which an automated pin refresh can change. Find it instead of
# hardcoding a name that upstream may rename.
rm -rf stage viewer
mkdir stage
bsdtar --no-same-owner -xf uu-remote-linux.tar.gz -C stage
top=""
for d in stage/*/; do
    [ -d "$d" ] || continue
    [ -n "$top" ] && { echo "expected one top-level directory in the release tarball, found more" >&2; exit 1; }
    top="${d%/}"
done
[ -n "$top" ] || { echo "expected a directory in the release tarball" >&2; exit 1; }
mv "$top" viewer

# Fail the update check rather than shipping a launcher that points at nothing.
[ -x viewer/uuremote-viewer ] || { echo "uuremote-viewer not found in the release tarball" >&2; exit 1; }
# The viewer starts `uuremote-server login` for QR sign-in; without the sibling
# binary its sign-in button only reports that the binary is missing.
[ -x viewer/uuremote-server ] || { echo "uuremote-server not found in the release tarball (needed for QR sign-in)" >&2; exit 1; }

rm -rf stage uu-remote-linux.tar.gz
