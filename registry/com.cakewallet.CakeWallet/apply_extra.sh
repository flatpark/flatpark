#!/bin/sh
set -eu

# Runs offline inside the runtime at install time. The official archive has a
# versioned top directory; keep the extracted app at one stable path so the
# launcher works after updates.
extra_root="${EXTRA_ROOT:-/app/extra}"
archive="$extra_root/cake-wallet.tar.xz"
[ -f "$archive" ] || { echo "missing extra-data: cake-wallet.tar.xz" >&2; exit 1; }

stage="$(mktemp -d "$extra_root/.cake-wallet-stage.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
for helper in zenity.deb zenity-common.deb; do
  [ -f "$extra_root/$helper" ] || { echo "missing extra-data: $helper" >&2; exit 1; }
done
bsdtar --no-same-owner -xf "$archive" -C "$stage"

entries="$(find "$stage" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')"
top="$(find "$stage" -mindepth 1 -maxdepth 1 -type d -print)"
[ "$entries" -eq 1 ] && [ -n "$top" ] || {
  echo "expected one top-level directory in cake-wallet.tar.xz" >&2
  exit 1
}
[ -x "$top/cake_wallet" ] || { echo "cake_wallet binary not found in archive" >&2; exit 1; }
[ -f "$top/lib/libapp.so" ] || { echo "Flutter app library not found in archive" >&2; exit 1; }
[ -f "$top/data/flutter_assets/AssetManifest.bin" ] || {
  echo "Flutter assets not found in archive" >&2
  exit 1
}

rm -rf "$extra_root/cake_wallet"
mv "$top" "$extra_root/cake_wallet"
rm -f "$archive"

# The app's Linux picker invokes zenity. Unpack the pinned Debian helper and
# common data without running maintainer scripts or modifying the app payload.
mkdir -p "$stage/helper"
for helper in zenity.deb zenity-common.deb; do
  bsdtar -xOf "$extra_root/$helper" 'data.tar*' | bsdtar --no-same-owner -xf - -C "$stage/helper"
done
[ -x "$stage/helper/usr/bin/zenity" ] || { echo "zenity binary not found" >&2; exit 1; }
rm -rf "$extra_root/tools"
mv "$stage/helper/usr" "$extra_root/tools"
rm -f "$extra_root/zenity.deb" "$extra_root/zenity-common.deb"
