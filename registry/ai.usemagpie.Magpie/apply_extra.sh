#!/bin/sh
set -eu

# The official Linux release is a single Wails/GTK/WebKitGTK executable.
# extra-data is stored under /app/extra; only set its executable bit here.
extra_root="${EXTRA_ROOT:-/app/extra}"
case "$(uname -m)" in
  x86_64) payload=magpie-linux-amd64 ;;
  aarch64) payload=magpie-linux-arm64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
[ -s "$extra_root/$payload" ] || { echo "missing extra-data: $payload" >&2; exit 1; }
chmod 755 "$extra_root/$payload"
