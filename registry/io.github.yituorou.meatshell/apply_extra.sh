#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the Linux x86_64 build as a tarball whose single top-level directory is named
# after the release (meatshell-v<version>-linux-x86_64/) and holds the
# self-contained `meatshell` binary next to its README/CHANGELOG, the icon and a
# .desktop file. Unpack it and keep just the binary at a stable path the wrapper
# execs: /app/extra/meatshell. The desktop file, icon and AppStream metainfo are
# shipped by the manifest at *build* time — extra-data is fetched later on the
# user's machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f meatshell.tar.gz ] || { echo "missing extra-data: meatshell.tar.gz" >&2; exit 1; }

rm -rf stage meatshell
mkdir stage
# --no-same-owner: the tarball records the GitHub runner's uid/gid (1001), and on
# a system-wide install Flatpak runs apply_extra as root with every capability
# dropped, so restoring that ownership fails and aborts the unpack even though
# every member extracted fine.
tar --no-same-owner -xzf meatshell.tar.gz -C stage

# The top directory carries the version, so never hardcode it — find the binary
# instead. Upstream renaming the directory between releases must not break the
# unpack.
bin="$(find stage -mindepth 2 -maxdepth 2 -type f -name meatshell -print -quit)"
[ -n "$bin" ] || { echo "meatshell binary not found in tarball" >&2; exit 1; }

mv "$bin" meatshell
chmod +x meatshell
rm -rf stage meatshell.tar.gz
[ -x meatshell ] || { echo "meatshell binary missing after stage" >&2; exit 1; }

# The bundled Noto Sans CJK face (extra-data too) only has to be moved into the
# directory /app/etc/fonts/fonts.conf points the font database at.
mkdir -p fonts
mv NotoSansCJK-Regular.ttc fonts/NotoSansCJK-Regular.ttc
