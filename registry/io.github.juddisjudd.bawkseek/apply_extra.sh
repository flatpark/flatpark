#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream's
# release tarball has one version-stamped top directory holding the single
# self-contained bawkseek binary (fonts, icons and themes are embedded in it)
# alongside the desktop file, icon, LICENSE and README. Move the binary to a
# stable path so the wrapper works across updates.
#
# The bundled Noto CJK fallback arrives next to it from flatpark/prebuilt and
# unpacks into /app/extra/noto-fonts, whose share/fonts fonts.conf lists.
extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f bawkseek.tar.gz ] || { echo "missing extra-data: bawkseek.tar.gz" >&2; exit 1; }

rm -rf stage bawkseek
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root
# with every capability dropped and cannot restore archive ownership.
bsdtar --no-same-owner -xf bawkseek.tar.gz -C stage

top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ -n "$top" ] && [ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] || {
  echo "expected one top-level directory in bawkseek.tar.gz" >&2
  exit 1
}
[ -x "$top/bawkseek" ] || { echo "bawkseek binary not found in tarball" >&2; exit 1; }
mv "$top/bawkseek" bawkseek
rm -rf stage bawkseek.tar.gz

[ -f noto-fonts.tar.xz ] || { echo "missing extra-data: noto-fonts.tar.xz" >&2; exit 1; }
rm -rf noto-fonts
bsdtar --no-same-owner -xf noto-fonts.tar.xz
rm -f noto-fonts.tar.xz
[ -s noto-fonts/share/fonts/NotoSansCJK-Regular.ttc ] || {
  echo "NotoSansCJK-Regular.ttc not found in noto-fonts.tar.xz" >&2
  exit 1
}
