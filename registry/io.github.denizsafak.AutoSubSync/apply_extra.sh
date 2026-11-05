#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# Linux tarball is a PyInstaller one-dir bundle with no top-level directory:
# the AutoSubSync launcher and its _internal/ tree (Python, PyQt6/Qt 6 and
# the sync engines with their own static ffmpeg/ffprobe, alass and lapse)
# sit at the archive root. Unpack into a staging directory and move it to a
# fixed path so the wrapper works across updates.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f autosubsync.tar.gz ] || { echo "missing extra-data: autosubsync.tar.gz" >&2; exit 1; }

rm -rf stage autosubsync
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every
# capability dropped, and restoring the archive's uid/gid would abort it.
bsdtar --no-same-owner -xf autosubsync.tar.gz -C stage

# Accept either the current flat layout or a single wrapping directory, in
# case upstream adds one later.
if [ -x stage/AutoSubSync ]; then
    mv stage autosubsync
else
    top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
    [ -n "$top" ] && [ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] \
        || { echo "unexpected tarball layout" >&2; exit 1; }
    mv "$top" autosubsync
    rm -rf stage
fi

[ -x autosubsync/AutoSubSync ] || { echo "AutoSubSync launcher missing after unpack" >&2; exit 1; }
[ -d autosubsync/_internal ]   || { echo "AutoSubSync _internal/ missing after unpack" >&2; exit 1; }

rm -f autosubsync.tar.gz
