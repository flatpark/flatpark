#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships Avash
# as a Tauri .deb whose payload is two binaries in usr/bin: avash-ui (the
# WebKitGTK front end, web assets embedded) and avash-rdp (the RDP sidecar).
# Tauri runs a sidecar from the directory of the current executable, so the two
# must stay side by side: stage usr/bin whole at /app/extra/avash.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f avash.deb ] || { echo "missing extra-data: avash.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage avash
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf avash.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the launcher out of the package's own .desktop Exec= rather than
# hardcoding it, so a rename between releases fails here, loudly, instead of
# shipping an install nobody can start (flatpark#130).
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n1)"
[ -n "$desktop" ] || { echo "no .desktop in the .deb" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
launcher="${launcher##*/}"
[ -x "stage/usr/bin/$launcher" ] || { echo "launcher $launcher not found in the .deb" >&2; exit 1; }
[ -x stage/usr/bin/avash-rdp ] || { echo "avash-rdp sidecar not found in the .deb" >&2; exit 1; }

mv stage/usr/bin avash
rm -rf stage avash.deb

[ "$launcher" = avash-ui ] || ln -sf "$launcher" avash/avash-ui
[ -x avash/avash-ui ] || { echo "avash-ui launcher missing after stage" >&2; exit 1; }
