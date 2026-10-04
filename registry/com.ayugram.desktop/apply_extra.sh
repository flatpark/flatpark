#!/bin/sh
set -eu

# Runs offline at install time. Unpacks the flatpark/ayugram-release tarball
# (upstream's `cmake --install` tree under usr/) and keeps only the binary at a
# stable path the wrapper expects: /app/extra/AyuGram. The desktop file, D-Bus
# service, icon and AppStream metainfo are shipped by the manifest at *build*
# time — extra-data is fetched later on the user's machine, so anything Flatpak
# must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f ayugram.tar.zst ] || { echo "missing extra-data: ayugram.tar.zst" >&2; exit 1; }

# The runtime ships tar + zstd; extract just the binary.
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
zstd -dc ayugram.tar.zst | tar --no-same-owner -xf - usr/bin/AyuGram
[ -f usr/bin/AyuGram ] || { echo "AyuGram binary not found in tarball" >&2; exit 1; }
mv usr/bin/AyuGram AyuGram
rm -rf usr ayugram.tar.zst
chmod +x AyuGram
