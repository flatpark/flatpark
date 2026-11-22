#!/bin/sh
set -eu

# The unpack below is a pipeline. Enable pipefail when the runtime shell supports
# it so a failure in either bsdtar process cannot leave a partial installation.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.gnome.Platform. Upstream's Tauri .deb
# holds the app binary and its whisper.cpp sidecar (whisper-cli) in usr/bin and
# the bundled Whisper "small" model under "usr/lib/Open Speech Studio/models".
# The usr/ tree is kept whole: the app looks for whisper-cli next to its own
# executable and for the model in <exe dir>/../lib/<product name>/models.
#
# The binary name is read from the vendor's own .desktop Exec line rather than
# written down here, and a symlink named after the app id gives the wrapper a
# fixed entry point. Its name becomes the program name and with it the window
# class, which the desktop file's StartupWMClass matches. The app resolves its
# own path through /proc/self/exe, so the symlink doesn't move what it finds.
LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f open-speech-studio.deb ] || { echo "missing extra-data: open-speech-studio.deb" >&2; exit 1; }

rm -rf stage speech
mkdir stage
# The Platform runtime has no ar/dpkg. bsdtar reads the .deb and the inner
# data.tar*. --no-same-owner: a system install runs apply_extra as root with
# every capability dropped.
bsdtar -xOf open-speech-studio.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ "$(find stage/usr/share/applications -name '*.desktop' | wc -l)" -eq 1 ] || {
  echo "expected exactly one .desktop in the .deb" >&2
  exit 1
}
desktop=$(find stage/usr/share/applications -name '*.desktop')
binary=$(sed -n 's/^Exec=//p' "$desktop" | head -n 1 | sed 's/ %[A-Za-z]*$//; s:.*/::')
[ -n "$binary" ] && [ -x "stage/usr/bin/$binary" ] || {
  echo "launcher '$binary' from $desktop not found in usr/bin" >&2
  exit 1
}
[ -x stage/usr/bin/whisper-cli ] || { echo "whisper-cli not found in .deb" >&2; exit 1; }

mkdir speech
mv stage/usr speech/usr
ln -s "$binary" speech/usr/bin/org.openaec.OpenSpeechStudio
rm -rf stage open-speech-studio.deb
