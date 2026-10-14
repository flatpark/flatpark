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
# WorkBuddy AI as a plain electron-builder .deb: the whole application tree
# lives under "/opt/WorkBuddy AI" (Chromium, the app.asar bundle and its unpacked native
# modules, the bundled Node 22 and CPython 3.13 runtimes under resources/runtime
# and the agent's sandbox helpers), plus a desktop entry and icons. Keep the
# application directory at /app/extra/workbuddyai, the stable path the wrapper
# execs.
#
# Not staged: resources/apparmor-profile, which asks the host's AppArmor to let
# Chromium create unprivileged user namespaces for its own sandbox — inside
# Flatpak that job belongs to zypak. The desktop entry, icon and AppStream
# metainfo are shipped by the manifest at *build* time, because extra-data is
# fetched later on the user's machine and anything Flatpak must export cannot
# come from here.

LC_ALL=C
export LC_ALL

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

deb=""
for candidate in workbuddyai-amd64.deb workbuddyai-arm64.deb; do
  [ -f "$candidate" ] && deb="$candidate" && break
done
[ -n "$deb" ] || { echo "missing extra-data: no workbuddyai-*.deb in $extra_root" >&2; exit 1; }

# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb ar
# container directly; pipe its data member into a second bsdtar to unpack the
# tree (the inner data.tar compression is auto-detected).
rm -rf stage workbuddyai
mkdir stage
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf "$deb" 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# The launcher name and its directory are read out of the .deb's own desktop
# entry rather than hardcoded, so a rename upstream cannot ship a pin nobody can
# install. The install directory has a space in it, so the entry quotes the
# executable: take the quoted string when there is one, else the first word.
desktop="$(ls stage/usr/share/applications/*.desktop 2>/dev/null | head -n 1 || true)"
[ -n "$desktop" ] || { echo "no desktop entry found in .deb" >&2; exit 1; }
exec_line="$(sed -n 's/^Exec=//p' "$desktop" | head -n 1)"
case "$exec_line" in
  \"*) app_path="${exec_line#\"}"; app_path="${app_path%%\"*}" ;;
  *) app_path="${exec_line%% *}" ;;
esac
launcher="$(basename "$app_path")"
app_dir="$(dirname "$app_path")"

[ -x "stage$app_dir/$launcher" ] || { echo "WorkBuddy AI binary not found in .deb: $app_dir/$launcher" >&2; exit 1; }
# The Electron app resolves its resources next to the executable, so the whole
# application directory moves as one.
mv "stage$app_dir" workbuddyai
rm -rf stage "$deb"
[ -x "workbuddyai/$launcher" ] || { echo "WorkBuddy AI binary missing after stage" >&2; exit 1; }
[ -f workbuddyai/resources/app.asar ] || { echo "application resources not found in .deb" >&2; exit 1; }

# The .deb records chrome-sandbox setuid. Chromium goes through zypak here, so
# that helper is never used, and a system-wide install would otherwise write a
# setuid-root binary into the deploy tree. Clear the bits explicitly rather than
# via a tar option, which would put every mode at the mercy of the umask
# apply_extra happens to run under.
chmod -R a-s workbuddyai

# Record the launcher name for the wrapper, which cannot read the .deb itself.
printf '%s\n' "$launcher" > workbuddyai-launcher
