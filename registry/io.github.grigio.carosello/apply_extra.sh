#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships the
# Linux x86_64 build as a single native binary (`carosello`; GTK4/libadwaita
# resolve from the runtime, and the UI stylesheet has been embedded in the
# binary since v1.0.6), so there is nothing to unpack — extra-data has already
# fetched that exact file here. We just ensure it is executable at the stable
# path the wrapper expects: /app/extra/carosello. The desktop file, icon and
# AppStream metainfo are shipped by the manifest at *build* time — extra-data
# is fetched later on the user's machine, so anything Flatpak must export
# cannot come from here.
# The vendor's bytes run unmodified — nothing is patched or recompiled.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f carosello ] || {
  echo "missing extra-data: carosello" >&2
  exit 1
}

chmod +x carosello
