#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships
# Voltius as a Tauri .deb whose payload is a single binary, usr/bin/voltius,
# with its web assets embedded, plus icons and a .desktop. Stage that binary at
# a stable path the wrapper execs: /app/extra/voltius/voltius.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f voltius.deb ] || { echo "missing extra-data: voltius.deb" >&2; exit 1; }

rm -rf stage voltius
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf voltius.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the launcher out of the package's own .desktop Exec= rather than
# hardcoding it (flatpark#130).
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n1)"
[ -n "$desktop" ] || { echo "no .desktop in the .deb" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
launcher="${launcher##*/}"
[ -x "stage/usr/bin/$launcher" ] || { echo "launcher $launcher not found in the .deb" >&2; exit 1; }

# The binary's name is also its X11/Wayland window class (StartupWMClass), so
# it is kept as-is and the wrapper execs whatever name the package used.
mkdir voltius
mv "stage/usr/bin/$launcher" "voltius/$launcher"
[ "$launcher" = voltius ] || ln -sf "$launcher" voltius/voltius
rm -rf stage voltius.deb
[ -x voltius/voltius ] || { echo "voltius launcher missing after stage" >&2; exit 1; }
