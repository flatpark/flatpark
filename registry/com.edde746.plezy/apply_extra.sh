#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.freedesktop.Platform. Upstream's .deb
# carries the whole application under opt/plezy: the Flutter binary, its data
# directory, a lib/ directory with the bundled libmpv/ffmpeg/GTK stack, and the
# plezy.sh launcher that points the loader and GTK at that lib/ directory.
# Stage it at /app/extra/plezy, the same layout plezy.sh expects.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f app.deb ] || {
  echo "missing extra-data: app.deb" >&2
  exit 1
}

rm -rf stage plezy
mkdir stage
# --no-same-owner is required because a system-wide apply_extra runs as root with
# every capability dropped and cannot restore archive ownership.
bsdtar -xOf app.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -f stage/opt/plezy/plezy.sh ] && [ -x stage/opt/plezy/plezy ] || {
  echo "unexpected .deb layout: opt/plezy/plezy.sh or opt/plezy/plezy missing" >&2
  exit 1
}
mv stage/opt/plezy plezy
rm -rf stage app.deb

# The crash reporter's helper ships without the executable bit; the app spawns
# it at start-up. Upstream's own Flatpak build sets the same mode.
if [ -f plezy/lib/crashpad_handler ]; then
  chmod 755 plezy/lib/crashpad_handler
fi

# The GTK module caches, when the release fills them in, name each module by the
# absolute path it had on the release builder. Point those entries at the staged
# copies, as upstream's own Flatpak build does.
for cache in plezy/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache:loaders \
             plezy/lib/gtk-3.0/3.0.0/immodules.cache:immodules; do
  file=${cache%%:*}
  dir=${cache##*:}
  [ -s "$file" ] || continue
  sed -i "s|^\"[^\"]*/\\([^\"/]*\\.so\\)\"|\"$extra_root/${file%/*}/$dir/\\1\"|" "$file"
done
