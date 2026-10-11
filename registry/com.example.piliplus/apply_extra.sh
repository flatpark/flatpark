#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform.
# Upstream's official Linux release is a relocatable Flutter bundle:
# the executable piliplus next to lib/ and data/.
#
# Unpack the archive into bundle/ so the layout is clean and isolated.
# Flatpak exports desktop, icon, and metainfo at build time.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive="piliplus.tar.gz"
[ -f "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }

rm -rf bundle
mkdir -p bundle
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
tar --no-same-owner -xzf "$archive" -C bundle
rm -f "$archive"

[ -f bundle/piliplus ] || { echo "piliplus binary missing after unpack" >&2; exit 1; }
chmod 755 bundle/piliplus
[ -d bundle/data/flutter_assets ] || { echo "flutter assets missing after unpack" >&2; exit 1; }
[ -d bundle/lib ] || { echo "flutter libraries missing after unpack" >&2; exit 1; }
