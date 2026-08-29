#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree whose payload lives under /opt/fluxdown:
#
#   /opt/fluxdown/fluxdown-desktop   the GPUI window
#   /opt/fluxdown/fluxdown-agent     tray / notification / local API service
#   /opt/fluxdown/fluxdownd          the download engine
#   /opt/fluxdown/fluxdown_nmh       browser native-messaging relay (unused here)
#   /opt/fluxdown/flux_down          compatibility launcher script
#
# Stage that whole tree at a stable path, /app/extra/fluxdown. Keeping the
# programs side by side is load-bearing: the window locates and starts
# fluxdown-agent next to its own executable, and the agent does the same for
# fluxdownd.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time - extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f fluxdown.deb ] || { echo "missing extra-data: fluxdown.deb" >&2; exit 1; }

rm -rf stage fluxdown
mkdir stage
# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf fluxdown.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

for exe in fluxdown-desktop fluxdown-agent fluxdownd; do
  [ -x "stage/opt/fluxdown/$exe" ] || { echo "$exe not found in .deb (opt/fluxdown)" >&2; exit 1; }
done

mv stage/opt/fluxdown fluxdown
rm -rf stage fluxdown.deb

# The bundled Noto Sans CJK face (extra-data too) only has to be moved into the
# directory /app/etc/fonts/fonts.conf points fontconfig at.
mkdir -p fonts
mv NotoSansCJK-Regular.ttc fonts/NotoSansCJK-Regular.ttc
