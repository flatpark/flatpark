#!/bin/sh
set -eu

# System-wide extra-data unpack runs offline as root with all capabilities
# dropped. Enable pipefail when the runtime shell supports it.
# shellcheck disable=SC3040
(set -o pipefail) 2>/dev/null && set -o pipefail || true

LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"
[ -f handy.deb ] || {
  echo "missing extra-data: handy.deb" >&2
  exit 1
}

rm -rf stage usr support
mkdir stage support
# Debian packages are ar containers; bsdtar can stream their data archive.
# Avoid restoring ownership because system-wide installation has no capability
# to chown files back to upstream's build user.
bsdtar -xOf handy.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

[ -x stage/usr/bin/handy ] || {
  echo "upstream .deb is missing usr/bin/handy" >&2
  exit 1
}

# Require the two upstream inference engines we want available: Vulkan for
# accelerated inference and a CPU backend for systems without Vulkan. The
# release must not accidentally switch to a CUDA-only Linux payload.
[ -f stage/usr/lib/Handy/libggml-vulkan.so ] || {
  echo "upstream .deb is missing its Vulkan transcription backend" >&2
  exit 1
}
[ -f stage/usr/lib/Handy/libggml-cpu-x64.so ] || {
  echo "upstream .deb is missing its CPU transcription backend" >&2
  exit 1
}
[ ! -e stage/usr/lib/Handy/libggml-cuda.so ] || {
  echo "upstream .deb unexpectedly contains a CUDA transcription backend" >&2
  exit 1
}

# Preserve the vendor's /usr layout: the executable's RUNPATH and Tauri resource
# lookup are relative to the installed paths (notably /usr/lib/Handy).
mv stage/usr usr

# These runtime libraries are not in GNOME 51. Unpack Debian data archives
# without preserving their owners; the wrapper adds their library directories.
for archive in libgtk-layer-shell0.deb libopenblas0-pthread.deb; do
  [ -f "$archive" ] || {
    echo "missing extra-data: $archive" >&2
    exit 1
  }
  bsdtar -xOf "$archive" 'data.tar*' | bsdtar --no-same-owner -xf - -C support
  rm "$archive"
done

[ -e support/usr/lib/x86_64-linux-gnu/libgtk-layer-shell.so.0 ] || {
  echo "Debian layer-shell package did not provide libgtk-layer-shell.so.0" >&2
  exit 1
}
[ -e support/usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblas.so.0 ] || {
  echo "Debian OpenBLAS package did not provide libopenblas.so.0" >&2
  exit 1
}
rm -rf stage handy.deb

[ -x usr/bin/handy ] || {
  echo "Handy executable missing after unpack" >&2
  exit 1
}
