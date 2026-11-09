#!/bin/sh
set -eu
# Offline whole-tree extraction in KDE Platform 6.11. The release contract is
# extra/{bin,include,lib,share}; flatten exactly once into /app/extra.
cd "${EXTRA_ROOT:-/app/extra}"
[ -f vlc.tar.zst ] || { echo 'missing extra-data: vlc.tar.zst' >&2; exit 1; }
rm -rf .vlc-stage
mkdir .vlc-stage
bsdtar --no-same-owner -xf vlc.tar.zst -C .vlc-stage
[ "$(find .vlc-stage -mindepth 1 -maxdepth 1 -printf '%f\n')" = extra ] || {
  echo 'unexpected VLC archive root' >&2; exit 1;
}
for entry in .vlc-stage/extra/* .vlc-stage/extra/.[!.]* .vlc-stage/extra/..?*; do
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  case ${entry##*/} in bin|include|lib|share) ;; *) echo 'unexpected payload entry' >&2; exit 1;; esac
  [ -d "$entry" ] && [ ! -L "$entry" ] || exit 1
done
[ -x .vlc-stage/extra/bin/vlc-nightly ] && [ -x .vlc-stage/extra/bin/vlc.bin ]
[ -d .vlc-stage/extra/lib/vlc/plugins ] && [ -f .vlc-stage/extra/share/vlc/build/inputs.json ]
for name in bin include lib share; do
  [ -d ".vlc-stage/extra/$name" ] || exit 1
  rm -rf "./$name"
  mv ".vlc-stage/extra/$name" "./$name"
done
rmdir .vlc-stage/extra .vlc-stage
rm vlc.tar.zst
