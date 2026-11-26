#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
for f in bob.AppImage appimage-tools.tar.xz; do
  [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done
bsdtar --no-same-owner -xf appimage-tools.tar.xz
offset="$(appimage-tools/bin/appimage-offset bob.AppImage)"
case "$offset" in ''|*[!0-9]*) echo "invalid AppImage offset" >&2; exit 1;; esac
rm -rf bob
appimage-tools/bin/unsquashfs -q -no-xattrs -o "$offset" -d bob bob.AppImage >/dev/null

# Read the launcher name from AppRun so upstream can rename it without a
# packaging change. The wrapper runs the binary directly through zypak.
[ -f bob/AppRun ] || { echo "AppRun missing" >&2; exit 1; }
name="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' bob/AppRun)"
case "$name" in ''|*/*|*..*) echo "invalid launcher in AppRun" >&2; exit 1;; esac
[ -x "bob/$name" ] && [ -f bob/resources/app.asar ] || { echo "incomplete AppImage" >&2; exit 1; }
printf '%s\n' "$name" > launcher
rm -rf bob.AppImage appimage-tools.tar.xz appimage-tools
