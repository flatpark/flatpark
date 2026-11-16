#!/bin/sh
set -eu

archive=/app/extra/sunvox.zip
staging=/app/extra/.sunvox-staging
destination=/app/extra/sunvox

if [ ! -f "$archive" ]; then
  echo "SunVox archive is missing: $archive" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64) linux_dir=linux_x86_64 ;;
  aarch64) linux_dir=linux_arm64 ;;
  *) echo "Unsupported SunVox architecture: $(uname -m)" >&2; exit 1 ;;
esac

rm -rf "$staging"
mkdir -p "$staging"
trap 'rm -rf "$staging"; rm -f "$archive"' EXIT

# Keep shared curves, instruments, effects, examples and license with the Linux binary.
bsdtar --no-same-owner -xf "$archive" -C "$staging" \
  sunvox/curves sunvox/instruments sunvox/effects sunvox/examples \
  sunvox/docs/license "sunvox/sunvox/$linux_dir"

binary="$staging/sunvox/sunvox/$linux_dir/sunvox"
if [ ! -x "$binary" ]; then
  echo "SunVox executable is missing or not executable: $binary" >&2
  exit 1
fi

rm -rf "$destination"
mv "$staging/sunvox" "$destination"
