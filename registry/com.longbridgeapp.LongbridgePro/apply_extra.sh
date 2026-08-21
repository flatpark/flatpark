#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships
# Longbridge Pro as a .deb holding a single self-contained application binary.
# Flatpak-exported metadata (desktop entry, icon, AppStream) is installed by the
# manifest at build time; extra-data stages the proprietary app binary and the
# two Noto faces into /app/extra.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f longbridgepro.deb ] || { echo "missing extra-data: longbridgepro.deb" >&2; exit 1; }

# The app's whole font set. /app/share/fonts/fonts.conf — which the wrapper
# points FONTCONFIG_FILE at — declares this directory and nothing else, so a
# missing face here means a tofu UI rather than a fallback.
rm -rf fonts
mkdir fonts
for face in NotoSans-Regular.ttf NotoSansCJK-Regular.ttc; do
    [ -f "$face" ] || { echo "missing extra-data: $face" >&2; exit 1; }
    mv "$face" fonts/
done

rm -rf stage longbridge
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf longbridgepro.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Where the binary sits inside the .deb is upstream's to change, and they have:
# 0.19.0 shipped /usr/local/bin/longbridge, 0.19.1 moved it to
# /usr/lib/longbridge-desktop/longbridge behind a /usr/bin symlink. Read the
# path out of the .desktop file in the same .deb instead of naming it here, so
# the next move lands as a pin refresh rather than a failed install.
desktop=""
for candidate in stage/usr/share/applications/*.desktop; do
    [ -f "$candidate" ] || continue
    [ -z "$desktop" ] || { echo "more than one .desktop file in .deb; cannot resolve the binary" >&2; exit 1; }
    desktop="$candidate"
done
[ -n "$desktop" ] || { echo "no .desktop file in .deb to resolve the binary from" >&2; exit 1; }

exec_path="$(sed -n 's/^Exec=//p' "$desktop" | head -n1 \
    | sed -e 's/[[:space:]]*%[a-zA-Z].*$//' -e 's/^"//' -e 's/"$//')"
case "$exec_path" in
    /*)  target="stage$exec_path" ;;
    */*) echo "Exec= is neither absolute nor a bare name: $exec_path" >&2; exit 1 ;;
    "")  echo "no Exec= line in the .deb's .desktop file" >&2; exit 1 ;;
    *)   target="stage/usr/bin/$exec_path" ;;
esac
# /usr/bin holds a relative symlink into /usr/lib in 0.19.1; follow it so the
# real binary gets staged rather than a link that dangles once stage/ is gone.
target="$(readlink -f "$target" 2>/dev/null || true)"
[ -n "$target" ] && [ -x "$target" ] || { echo "Longbridge binary not found in .deb (Exec=$exec_path)" >&2; exit 1; }
mv "$target" longbridge
rm -rf stage longbridgepro.deb
[ -x longbridge ] || { echo "Longbridge binary missing after stage" >&2; exit 1; }
