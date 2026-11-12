#!/bin/sh
set -eu

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
for f in pomatez.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
# System installs run as root with no capabilities: never restore ownership.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
offset="$("$tools/appimage-offset" pomatez.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "invalid AppImage offset: '$offset'" >&2; exit 1 ;;
esac
rm -rf app
"$tools/unsquashfs" -q -no-xattrs -o "$offset" -d app pomatez.AppImage >/dev/null

# Read the vendor's launcher name so automated updates tolerate a rename.
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' app/AppRun)"
case "$name" in
    ''|*/*|*'
'*) echo "ambiguous or invalid launcher in AppRun" >&2; exit 1 ;;
esac
[ -x "app/$name" ] || { echo "launcher '$name' missing in AppImage" >&2; exit 1; }
[ -f app/resources/app.asar ] || { echo "resources/app.asar missing" >&2; exit 1; }
# Keep this record beside the vendor's unmodified tree.
printf '%s\n' "$name" > launcher
rm -rf pomatez.AppImage appimage-tools.tar.xz appimage-tools
