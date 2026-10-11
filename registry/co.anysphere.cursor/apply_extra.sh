#!/bin/sh
set -eu

# The unpack below is a pipeline, and a plain `set -e` only sees the exit status
# of its LAST command — a first-stage failure part-way through would hand the
# second stage a truncated stream, which can still exit 0 and leave a partial
# tree. Flatpak verifies the extra-data digest before this script runs, so a
# corrupt download cannot get here, but a full disk mid-unpack can. /bin/sh is
# bash in org.freedesktop.Platform; the subshell probe keeps this a no-op rather
# than a hard failure on a shell without pipefail.
# shellcheck disable=SC3040
(set -o pipefail) 2> /dev/null && set -o pipefail || true

# Runs offline at install time inside org.freedesktop.Platform. Upstream ships
# Cursor as a plain FHS .deb: the whole Electron application tree lives under
# /usr/share/cursor (Chromium, the VS Code-derived app resources, the bundled
# extensions and the `cursor` CLI), plus a desktop entry, an icon and a couple of
# system files. Keep the application directory at /app/extra/cursor, the stable
# path the wrapper execs.
#
# Not staged: etc/apparmor.d and etc/sysctl.d, which configure the host's
# unprivileged-userns policy for Chromium's own sandbox — inside Flatpak that
# job belongs to zypak. The desktop files, icon, MIME definition and AppStream
# metainfo are shipped by the manifest at *build* time, because extra-data is
# fetched later on the user's machine and anything Flatpak must export cannot
# come from here.

LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

deb="cursor.deb"
[ -f "$deb" ] || { echo "missing extra-data: $deb" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage cursor
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The launcher name and its directory are read out of the .deb's own desktop
# entry rather than hardcoded, so a rename upstream cannot ship a pin nobody can
# install. Skip the URL-handler entry, which points at the same binary but only
# ever with --open-url.
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | grep -v url-handler | head -n 1 || true)"
[ -n "$desktop" ] || { echo "no desktop entry found in .deb" >&2; exit 1; }
exec_line="$(sed -n 's/^Exec=//p' "$desktop" | head -n 1)"
app_path="$(printf '%s\n' "$exec_line" | awk '{print $1}')"
app_dir="$(dirname "$app_path")"
launcher="$(basename "$app_path")"

[ -x "stage$app_dir/$launcher" ] || { echo "Cursor binary not found in .deb: $app_path" >&2; exit 1; }
# The Electron app resolves its resources next to the executable, so the whole
# application directory moves as one.
mv "stage$app_dir" cursor
rm -rf stage "$deb"
[ -x "cursor/$launcher" ] || { echo "Cursor binary missing after stage" >&2; exit 1; }
[ -d cursor/resources/app ] || { echo "application resources not found in .deb" >&2; exit 1; }

# The .deb records chrome-sandbox setuid. Chromium goes through zypak here, so
# that helper is never used, and a system-wide install would otherwise write a
# setuid-root binary into the deploy tree. Clear the bits explicitly rather than
# via a tar option, which would put every mode at the mercy of the umask
# apply_extra happens to run under.
chmod -R a-s cursor

# Record the launcher name for the wrapper, which cannot read the .deb itself.
printf '%s\n' "$launcher" > cursor-launcher
