#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# Linux x86_64 build is a Godot export: one self-contained executable with the
# game data (.pck) embedded, shipped in a zip next to an AppImage of the same
# executable. The zip is the plainer of the two, so this unpacks it and stages
# the executable at a stable path the wrapper execs: /app/extra/godsvg/GodSVG.
#
# The executable links only libc/libm; the windowing, GL, audio, font and D-Bus
# libraries Godot loads at run time all come from the runtime.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f godsvg.zip ] || { echo "missing extra-data: godsvg.zip" >&2; exit 1; }

# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring an archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
rm -rf unpack godsvg
mkdir unpack
bsdtar --no-same-owner -xf godsvg.zip -C unpack

# The executable is named after the release (GodSVG_v1.0-alpha17.x86_64), so
# find it rather than writing a version into this script — pin refreshes are
# automated. Exactly one regular file is expected; anything else means the
# archive changed shape and should fail the install loudly rather than stage
# the wrong file.
set -- unpack/*.x86_64
[ "$#" -eq 1 ] && [ -f "$1" ] \
    || { echo "expected exactly one *.x86_64 executable in godsvg.zip" >&2; exit 1; }

mkdir godsvg
mv "$1" godsvg/GodSVG
chmod 0755 godsvg/GodSVG

rm -rf unpack godsvg.zip
