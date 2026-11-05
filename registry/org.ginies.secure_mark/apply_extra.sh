#!/bin/sh
set -eu
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
for f in securemark.AppImage appimage-tools.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
# System installations run as root without capabilities: never restore owners.
bsdtar --no-same-owner -xf appimage-tools.tar.xz
tools="$extra_root/appimage-tools/bin"
offset="$("$tools/appimage-offset" securemark.AppImage)"
case "$offset" in
    ''|*[!0-9]*) echo "invalid AppImage offset: $offset" >&2; exit 1 ;;
esac
rm -rf securemark
"$tools/unsquashfs" -no-xattrs -o "$offset" -d securemark securemark.AppImage
# AppRun is the format's stable entry point; resolve it rather than assuming
# the executable's spelling survives an upstream release.
[ -L securemark/AppRun ] && [ -x securemark/AppRun ] || {
    echo "expected executable AppRun symlink in SecureMark AppImage" >&2; exit 1;
}
rm -rf securemark.AppImage appimage-tools.tar.xz appimage-tools
