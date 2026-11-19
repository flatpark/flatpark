#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream .deb
# (x86_64 or arm64, same layout) is a plain FHS tree whose payload lives under
# /opt/nyaterm:
#
#   /opt/nyaterm/nyaterm                  the GPUI window
#   /opt/nyaterm/nyaterm-rdp-helper       RDP session process
#   /opt/nyaterm/nyaterm-vnc-helper       VNC session process
#   /opt/nyaterm/nyaterm-mcp              MCP server for AI clients
#   /opt/nyaterm/nyaterm-android-helper   Android screen sessions, with the
#                                         adb/ and android-libs/ it loads
#
# Stage that whole tree at a stable path, /app/extra/nyaterm. Keeping the
# programs side by side is load-bearing: the window starts the helpers from its
# own directory.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f nyaterm.deb ] || { echo "missing extra-data: nyaterm.deb" >&2; exit 1; }

rm -rf stage nyaterm
mkdir stage
# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf nyaterm.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

for exe in nyaterm nyaterm-rdp-helper nyaterm-vnc-helper; do
  [ -x "stage/opt/nyaterm/$exe" ] || { echo "$exe not found in .deb (opt/nyaterm)" >&2; exit 1; }
done

mv stage/opt/nyaterm nyaterm
rm -rf stage nyaterm.deb

# The bundled Noto faces come as the noto-fonts prebuilt stack (extra-data
# too). Unpacking it leaves them in /app/extra/noto-fonts/share/fonts, the
# directory /app/etc/fonts/fonts.conf points fontconfig at.
[ -f noto-fonts.tar.xz ] || { echo "missing extra-data: noto-fonts.tar.xz" >&2; exit 1; }
rm -rf noto-fonts
bsdtar --no-same-owner -xf noto-fonts.tar.xz
rm -f noto-fonts.tar.xz
[ -s noto-fonts/share/fonts/NotoSansCJK-Regular.ttc ] || { echo "NotoSansCJK-Regular.ttc not found in noto-fonts.tar.xz" >&2; exit 1; }
