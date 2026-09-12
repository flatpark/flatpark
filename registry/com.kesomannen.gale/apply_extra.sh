#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream Debian
# package is a plain FHS tree holding a single Tauri binary at usr/bin/gale plus
# its icons, .desktop file and shared-mime-info package. The whole usr tree is
# staged as-is at /app/extra/usr so that any resource directory a future release
# adds keeps resolving relative to the executable, and the wrapper launches it
# through /app/extra/bin/gale.
#
# The desktop file, icon, MIME package and AppStream metainfo are shipped by the
# manifest at *build* time - extra-data is fetched later on the user's machine,
# so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f gale.deb ] || { echo "missing extra-data: gale.deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage usr bin
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf gale.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The launcher name comes out of the package's own .desktop Exec= rather than
# being hardcoded, so a rename upstream cannot ship an app that will not start.
desktop="$(find stage/usr/share/applications -maxdepth 1 -name '*.desktop' | head -n1)"
[ -n "$desktop" ] || { echo "no .desktop in the .deb" >&2; exit 1; }
exec_name="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1 | xargs basename)"
[ -n "$exec_name" ] || { echo "no Exec= in $desktop" >&2; exit 1; }
[ -f "stage/usr/bin/$exec_name" ] || { echo "launcher $exec_name not found in the .deb" >&2; exit 1; }

mv stage/usr usr
rm -rf stage gale.deb
chmod +x "usr/bin/$exec_name"

# Stable path for the wrapper, whatever upstream calls the binary. The name of
# this symlink is also the window class the toolkit derives from argv[0], so it
# has to keep matching StartupWMClass in the exported .desktop file.
mkdir -p bin
ln -sf "../usr/bin/$exec_name" bin/gale
