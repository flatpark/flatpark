#!/bin/sh
set -eu
# Flatpak runs this offline in /app/extra; never execute the AppImage.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f anythingllm.AppImage ] && [ -f appimage-tools.tar.xz ] || {
    echo "missing AnythingLLM AppImage or offline extractor" >&2; exit 1;
}
bsdtar --no-same-owner -xf appimage-tools.tar.xz
offset="$(appimage-tools/bin/appimage-offset anythingllm.AppImage)"
case "$offset" in ''|*[!0-9]*) echo "invalid AppImage offset" >&2; exit 1;; esac
appimage-tools/bin/unsquashfs -no-xattrs -o "$offset" -d anythingllm anythingllm.AppImage
# Resolve upstream's executable name, allowing automated updates to rename it.
launcher="$(sed -n 's|^BIN="\$APPDIR/\([^"]*\)".*|\1|p' anythingllm/AppRun)"
case "$launcher" in ''|*/*|*..*) echo "missing or unsafe AppRun launcher" >&2; exit 1;; esac
[ -x "anythingllm/$launcher" ] && [ -f anythingllm/resources/app.asar ] || {
    echo "AnythingLLM launcher or app.asar is missing" >&2; exit 1;
}
# Store launch metadata beside the unchanged vendor tree.
printf '%s\n' "$launcher" > launcher
rm -rf anythingllm.AppImage appimage-tools.tar.xz appimage-tools
