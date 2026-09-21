#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. UpNote ships the
# desktop app as a Debian package: a plain FHS tree with the full official
# Electron application under /opt/UpNote, plus an icon and desktop metadata.
# Keep only the official application tree, at the stable path the wrapper
# executes: /app/extra/upnote. The exported desktop file, icon and AppStream
# metainfo are shipped by the manifest at build time because extra-data is
# fetched later on the user's machine.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

deb="upnote-amd64.deb"
[ -f "$deb" ] || {
  echo "missing extra-data: $deb" >&2
  exit 1
}

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree. Keep an ar/tar fallback so the script is easy to verify on Debian hosts.
rm -rf stage upnote app.env
mkdir stage
if command -v bsdtar >/dev/null 2>&1; then
  # --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
  # every capability dropped, so restoring the archive's recorded uid/gid fails and
  # aborts the unpack even though every member extracted fine.
  bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage
else
  member="$(ar t "$deb" | grep '^data.tar' | head -n 1)"
  [ -n "$member" ] || { echo "data.tar member not found in .deb" >&2; exit 1; }
  case "$member" in
    *.tar.xz) ar p "$deb" "$member" | tar --no-same-owner -xJ -C stage ;;
    *.tar.gz) ar p "$deb" "$member" | tar --no-same-owner -xz -C stage ;;
    *.tar.zst) ar p "$deb" "$member" | tar --no-same-owner --zstd -x -C stage ;;
    *.tar) ar p "$deb" "$member" | tar --no-same-owner -x -C stage ;;
    *) echo "unsupported data archive: $member" >&2; exit 1 ;;
  esac
fi

# Locate the application tree through the Electron layout rather than through
# upstream's install path or binary name: both /opt/UpNote and the executable
# inside it are names upstream can change between releases, and pin refreshes
# are automated, so nothing the payload owns may be hardcoded here.
asar="$(find stage -type f -name app.asar -print 2>/dev/null | head -n 1)"
[ -n "$asar" ] || { echo "no app.asar in the .deb: upstream layout changed" >&2; exit 1; }
resources="$(dirname "$asar")"
[ "$(basename "$resources")" = "resources" ] || {
  echo "unexpected layout: app.asar is not in a resources/ directory ($asar)" >&2
  exit 1
}
appdir="$(dirname "$resources")"

# The Electron binary is the largest executable ELF next to resources/; the
# crashpad handler and the bundled .so files are the other ELF candidates.
app_bin=""
app_size=0
for f in "$appdir"/*; do
  [ -f "$f" ] && [ -x "$f" ] || continue
  case "${f##*/}" in
    *.so | *.so.* | *crashpad* | *sandbox*) continue ;;
  esac
  LC_ALL=C head -c 4 "$f" 2>/dev/null | grep -q 'ELF' || continue
  size="$(wc -c <"$f")"
  [ "$size" -gt "$app_size" ] || continue
  app_bin="$f"
  app_size="$size"
done
[ -n "$app_bin" ] || { echo "no Electron binary found in $appdir" >&2; exit 1; }
bin_name="${app_bin##*/}"

mv "$appdir" upnote
rm -rf stage "$deb"
[ -x "upnote/$bin_name" ] || {
  echo "UpNote binary missing after stage" >&2
  exit 1
}

# The wrapper reads the resolved binary name from here.
printf 'APP_BIN=%s\n' "$extra_root/upnote/$bin_name" >app.env
