#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The upstream release
# tarball holds one versioned directory (zaptide-v<ver>-<arch>-linux-gnu/) with
# the native zaptide binary, data/, po/ translations and licenses/zaptide/.
# Unpack to a stable path so the wrapper works across updates, keep the license
# notices intact, and compile the shipped .po catalogues with msgfmt.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f zaptide.tar.gz ] || { echo "missing extra-data: zaptide.tar.gz" >&2; exit 1; }

rm -rf stage zaptide share
mkdir stage

# --no-same-owner: a system-wide install runs apply_extra as root with every
# capability dropped, so restoring an archive's uid/gid aborts the unpack.
bsdtar --no-same-owner -xf zaptide.tar.gz -C stage

top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] && [ -n "$top" ] || {
  echo "expected one top-level directory in zaptide.tar.gz" >&2
  exit 1
}

mv "$top" zaptide

[ -x zaptide/zaptide ] || { echo "zaptide binary not found in tarball" >&2; exit 1; }

# Upstream plans to rename the Flatpak ID to org.luminusos.ZapTide in 1.0.0
# (luminusOS/zaptide#234). Fail the unpack if the desktop entry ID changes so
# an automated pin refresh does not ship a renamed build under the old ID.
[ -f zaptide/data/dev.luminusos.ZapTide.desktop ] || {
  echo "expected data/dev.luminusos.ZapTide.desktop in tarball (app ID may have changed)" >&2
  exit 1
}

# Compile gettext message catalogues from the tarball's po/ tree so upstream
# translations are picked up automatically on every update.
if [ -f zaptide/po/LINGUAS ]; then
  for lang in $(sed 's/#.*//' zaptide/po/LINGUAS); do
    po="zaptide/po/$lang.po"
    [ -f "$po" ] || { echo "missing translation file listed in po/LINGUAS: $po" >&2; exit 1; }
    mkdir -p "share/locale/$lang/LC_MESSAGES"
    msgfmt -o "share/locale/$lang/LC_MESSAGES/zaptide.mo" "$po"
  done
fi

rm -rf stage zaptide.tar.gz
