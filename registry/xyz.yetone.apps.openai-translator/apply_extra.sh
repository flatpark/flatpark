#!/bin/sh
set -eu
# Preserve Tauri's usr/bin + usr/lib resource layout from the official .deb.
# shellcheck disable=SC3040
(set -o pipefail) 2>/dev/null && set -o pipefail || true
cd "${EXTRA_ROOT:-/app/extra}"
[ -f nextai.deb ] || { echo "missing extra-data: nextai.deb" >&2; exit 1; }
rm -rf stage nextai
mkdir stage
bsdtar -xOf nextai.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
# Read the launch name from upstream so a rename fails clearly or follows it.
set -- stage/usr/share/applications/*.desktop
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "expected one desktop entry" >&2; exit 1; }
launcher=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$1")
case "$launcher" in ''|*[!a-zA-Z0-9._-]*) echo "unexpected launcher: $launcher" >&2; exit 1;; esac
[ -x "stage/usr/bin/$launcher" ] || { echo "missing executable: $launcher" >&2; exit 1; }
mv stage/usr nextai
# argv[0] gives GTK a stable class matching the exported desktop entry.
ln -s "$launcher" nextai/bin/xyz.yetone.apps.openai-translator
rm -rf stage nextai.deb
