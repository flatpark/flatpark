#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# the official Linux build as a .tar.gz with a single version-stamped top
# directory (zapfast-v<ver>-<arch>-unknown-linux-gnu/) holding the `zapfast`
# executable next to README.md, LICENSE, a packaging/ dir and contrib/.
# Rename that directory to a stable path the wrapper execs across updates, and
# record the executable's name so the wrapper never hardcodes it.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

archive=""
for f in zapfast-x86_64.tar.gz zapfast-aarch64.tar.gz; do
  if [ -f "$f" ]; then archive="$f"; break; fi
done
[ -n "$archive" ] || { echo "missing extra-data: zapfast-*.tar.gz" >&2; exit 1; }

# --no-same-owner: the release tarball records uid/gid 1001 from the build
# runner, and on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring that ownership fails and aborts the
# unpack even though every member extracted fine.
tar --no-same-owner -xzf "$archive"
app_dir="$(find . -maxdepth 1 -type d -name 'zapfast-*' | sort | head -n1)"
[ -n "$app_dir" ] || { echo "no zapfast-* directory in tarball" >&2; exit 1; }

rm -rf zapfast
mv "$app_dir" zapfast

bin="$(find zapfast -maxdepth 1 -type f -perm -u+x | sort | head -n1)"
[ -n "$bin" ] && [ -x "$bin" ] || { echo "zapfast executable not found in tarball" >&2; exit 1; }

printf 'APP_BIN=%s\n' "$extra_root/${bin#./}" > app.env

rm -f "$archive"
