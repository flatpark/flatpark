#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Wave as an electron-builder .deb: a plain FHS tree with the whole app under
# /opt/Wave (the Chromium binary, app.asar, libffmpeg.so, ANGLE and SwiftShader
# libs, plus resources/app.asar.unpacked/dist/bin holding the Go backend
# `wavesrv.x64` and the per-platform `wsh` helpers) alongside icons and a
# .desktop. Unpack the .deb's data member and keep just the app directory at a
# stable path the wrapper execs: /app/extra/waveterm.
#
# The desktop file, icon and AppStream metainfo are shipped by the manifest at
# *build* time — extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f waveterm.deb ] || { echo "missing extra-data: waveterm.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage waveterm
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf waveterm.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the launcher out of the package's own .desktop Exec= rather than
# hardcoding it. electron-builder names the binary after the build config, and a
# rename between releases would otherwise ship an install nobody can start — the
# com.tldraw.Offline lesson (flatpark#130). The Exec line looks like
#   Exec=/opt/Wave/waveterm --enable-features ... %U
# so take the first field and strip the directory.
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n1)"
[ -n "$desktop" ] || { echo "no .desktop in the .deb" >&2; exit 1; }
exec_path="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
[ -n "$exec_path" ] || { echo "no Exec= in $desktop" >&2; exit 1; }
app_dir="stage${exec_path%/*}"
launcher="${exec_path##*/}"
[ -x "$app_dir/$launcher" ] || { echo "launcher $exec_path not found in the .deb" >&2; exit 1; }

mv "$app_dir" waveterm
rm -rf stage waveterm.deb

# The wrapper execs a stable name; link it to whatever the .desktop pointed at,
# so an upstream rename changes only the symlink target.
[ "$launcher" = waveterm ] || ln -sf "$launcher" waveterm/waveterm
[ -x waveterm/waveterm ] || { echo "waveterm launcher missing after stage" >&2; exit 1; }

# The Go backend and the wsh helpers are executed directly by the app; the .deb
# carries the exec bits, but assert it rather than discovering it at first run.
[ -x waveterm/resources/app.asar.unpacked/dist/bin/wavesrv.x64 ] \
    || { echo "wavesrv backend missing after stage" >&2; exit 1; }
