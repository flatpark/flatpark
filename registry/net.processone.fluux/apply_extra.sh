#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream's Linux
# tarball is one directory holding the Tauri binary, a .desktop file and the
# icons. The binary is the whole application (it keeps no resource directory),
# and it links only libraries that org.gnome.Platform ships (webkit2gtk-4.1,
# gtk-3, libsoup-3); the tray library it dlopens is built into /app/lib by the
# manifest.
#
# The tarball's top directory is renamed to a fixed path so the wrapper works
# across updates. The launcher's name is read from the tarball's own .desktop
# Exec= line rather than written down here, so an upstream rename fails the
# update check instead of shipping an app that cannot start. A symlink named
# after the app id gives the wrapper a fixed entry point; the program name it
# is started under is what the toolkit may derive the window class from, and
# the MPRIS player name for WebKitGTK, so it stays a dotted id.
#
# The desktop entry, icon and AppStream metainfo are shipped by the manifest at
# *build* time: extra-data is fetched later on the user's machine, so anything
# Flatpak must export cannot come from here.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f fluux.tar.gz ] || { echo "missing extra-data: fluux.tar.gz" >&2; exit 1; }

rm -rf stage fluux
mkdir stage
# --no-same-owner: a system-wide install runs this as root with every capability
# dropped, and restoring the archive's recorded uid/gid would abort the unpack.
bsdtar --no-same-owner -xf fluux.tar.gz -C stage

top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ -n "$top" ] && [ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || {
  echo "expected one top-level directory in the tarball" >&2
  exit 1
}

desktop="$(find "$top" -maxdepth 1 -name '*.desktop')"
[ -n "$desktop" ] && [ "$(printf '%s\n' "$desktop" | wc -l)" -eq 1 ] || {
  echo "expected exactly one .desktop file in the tarball" >&2
  exit 1
}
binary="$(sed -n 's/^Exec=//p' "$desktop" | head -n 1 | sed 's/ %[A-Za-z]*$//; s:.*/::')"
[ -n "$binary" ] && [ -x "$top/$binary" ] || {
  echo "launcher '$binary' from $desktop not found in the tarball" >&2
  exit 1
}

mv "$top" fluux
ln -s "$binary" fluux/net.processone.fluux
rm -rf stage fluux.tar.gz
