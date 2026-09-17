#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The payload is
# upstream's `Gifkino-flatpark-x86_64.tar.xz`: the /app tree out of the very
# flatpak-builder run that produces their own Gifkino.flatpak bundle, published
# as a release asset for this package (their docs/release.md writes the contract
# down). Contents sit at the archive root — bin/, lib/, share/ — with the
# gifkino binary next to the ffmpeg, ffprobe and gifsicle programs the editor
# drives over pipes, and the .po catalogs under share/gifkino/po. No GTK: the
# tree was built against org.gnome.Platform 50 and takes GTK 4, libadwaita,
# glib, cairo and pango from this runtime, the same as upstream's own bundle.
#
# Stage it whole at a stable path the wrapper execs: /app/extra/gifkino. The
# desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f gifkino-app.tar.xz ] || { echo "missing extra-data: gifkino-app.tar.xz" >&2; exit 1; }

rm -rf gifkino
mkdir gifkino
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf gifkino-app.tar.xz -C gifkino

# Which file is the launcher? The tree's own desktop entry says so in its Exec
# line, and that is upstream's to rename; reading it here rather than writing
# the name into this script or the wrapper keeps an automated pin refresh from
# shipping an app nobody can start (com.tldraw.Offline learned that the hard
# way, flatpark#130).
desktop="$(set -- gifkino/share/applications/*.desktop; echo "$1")"
[ -f "$desktop" ] || { echo "no desktop entry in the app tree to read the launcher from" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
[ -n "$launcher" ] || { echo "no Exec= in $desktop" >&2; exit 1; }
[ -x "gifkino/bin/$launcher" ] || { echo "launcher '$launcher' from the desktop entry is not executable in the app tree" >&2; exit 1; }
# Beside the tree, not inside it: the upstream tree stays exactly as shipped.
printf '%s\n' "$launcher" > launcher

# The editor greys out video import without ffmpeg/ffprobe and skips the -O3
# export pass without gifsicle, so a tree that lost them is a failed install,
# not a degraded one. The catalogs are what the wrapper points GIFKINO_PO_DIR at.
for helper in ffmpeg ffprobe gifsicle; do
    [ -x "gifkino/bin/$helper" ] || { echo "helper missing from the app tree: $helper" >&2; exit 1; }
done
[ -d gifkino/share/gifkino/po ] || { echo "share/gifkino/po missing from the app tree" >&2; exit 1; }

rm -f gifkino-app.tar.xz
