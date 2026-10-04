#!/bin/sh
set -eu

# The .deb unpack below is a pipeline. Enable pipefail when the runtime shell
# supports it so a failure in either bsdtar process cannot leave a partial
# installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. Three payloads:
#
#   crealityprint.AppImage  upstream's release AppImage — a type-2 AppImage, an
#                           ELF stub with a SquashFS appended. Never executed
#                           or FUSE-mounted; the filesystem is unpacked
#                           directly. Its AppDir holds bin/CrealityPrint,
#                           resources/ (profiles, printer definitions, web UI,
#                           shaders) and usr/lib/ with the handful of libraries
#                           the vendor bundles.
#   appimage-tools.tar.xz   appimage-offset (prints where the SquashFS begins)
#                           and unsquashfs, from flatpark/prebuilt.
#   libdeflate0.deb         Debian's libdeflate. CrealityPrint links
#                           libdeflate.so.0 directly and neither the AppImage
#                           nor the runtime carries it.
#
# The AppDir is staged whole at /app/extra/creality; libdeflate at
# /app/extra/deps/lib. The desktop file, icon and AppStream metainfo are shipped
# by the manifest at *build* time — extra-data is fetched later on the user's
# machine, so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in crealityprint.AppImage appimage-tools.tar.xz libdeflate0.deb; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

# --no-same-owner throughout: on a system-wide install Flatpak runs apply_extra
# as root with every capability dropped, so restoring an archive's recorded
# uid/gid fails and aborts the unpack even though every member extracted fine.
# unsquashfs never chowns, and -no-xattrs keeps it from setting security
# xattrs it has no capability for.
rm -rf creality deps stage appimage-tools
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
[ -x "$tools/appimage-offset" ] && [ -x "$tools/unsquashfs" ] \
    || { echo "appimage-tools stack incomplete" >&2; exit 1; }

offset="$("$tools/appimage-offset" crealityprint.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "appimage-offset did not return a number: '$offset'" >&2; exit 1 ;;
esac
"$tools/unsquashfs" -no-xattrs -o "$offset" -d creality crealityprint.AppImage

[ -x creality/bin/CrealityPrint ] || { echo "bin/CrealityPrint missing after unpack" >&2; exit 1; }
[ -d creality/resources/profiles ] || { echo "resources/profiles missing after unpack" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container; pipe its data member into a second bsdtar for the inner archive.
mkdir -p stage deps/lib
bsdtar -xOf libdeflate0.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
# -a, and the -e test, because the loader looks up the SONAME link
# (libdeflate.so.0), not necessarily the regular file behind it.
find stage/usr/lib -maxdepth 3 \( -type f -o -type l \) -name 'libdeflate.so.*' \
    -exec cp -a {} deps/lib/ \;
[ -e deps/lib/libdeflate.so.0 ] || { echo "libdeflate.so.0 not found in libdeflate0.deb" >&2; exit 1; }

# Drop the archives and the extractor now that the trees are staged —
# otherwise they sit on the user's disk for the life of the install.
rm -rf stage appimage-tools crealityprint.AppImage appimage-tools.tar.xz libdeflate0.deb
