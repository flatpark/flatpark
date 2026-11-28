#!/bin/sh
set -eu

# Runs offline at install time. Upstream ships the Linux x86_64 build as one
# fully static executable (musl, static-PIE: no shared libraries at all), so
# there is nothing to unpack: move it to the fixed path the wrapper starts.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f msga-linux-x86_64 ] || {
  echo "missing extra-data: msga-linux-x86_64" >&2
  exit 1
}

mv -f msga-linux-x86_64 msga
chmod 755 msga
