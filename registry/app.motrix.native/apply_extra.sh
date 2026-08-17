#!/bin/sh
set -eu

# Runs offline at install time. Upstream ships the Electron app as a Debian
# package whose payload is a single self-contained tree under /opt. Stage that
# tree at a stable path the wrapper execs: /app/extra/motrix.
#
# Everything Electron needs (Chromium, ffmpeg, app.asar) is inside, as is the
# aria2 engine the app drives (resources/extra/linux/<arch>/aria2c) and the
# bundled plugins; only the system GTK3/NSS/CUPS/X11 stack comes from the
# runtime. The desktop file, icon and AppStream metainfo are shipped by the
# manifest at *build* time — extra-data is fetched later on the user's machine,
# so anything Flatpak must export cannot come from here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f motrix.deb ] || { echo "missing extra-data: motrix.deb" >&2; exit 1; }

rm -rf stage motrix
mkdir stage
# The Platform runtime has no ar/dpkg, but bsdtar (libarchive) reads the .deb
# ar container directly; pipe its data member into a second bsdtar to unpack the
# FHS tree (the inner data.tar compression is auto-detected).
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root with
# every capability dropped, so restoring the archive's recorded uid/gid fails and
# aborts the unpack even though every member extracted fine.
bsdtar -xOf motrix.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Read the payload directory and the launcher name out of the artifact instead
# of hardcoding them: pin refreshes are automated, and the .deb's own desktop
# entry is the authoritative answer for where electron-builder put the app and
# what it called the binary. Record the name for the wrapper to exec.
exec_line="$(sed -n 's/^Exec=//p' stage/usr/share/applications/*.desktop | head -n1)"
bin_path="${exec_line%% *}"
case "$bin_path" in
  /*) ;;
  *) echo "unexpected Exec in the .deb desktop entry: $exec_line" >&2; exit 1 ;;
esac
app_dir="$(dirname "$bin_path")"
launcher="$(basename "$bin_path")"
[ -x "stage$bin_path" ] || { echo "launcher not found in .deb: $bin_path" >&2; exit 1; }

mv "stage$app_dir" motrix
printf '%s\n' "$launcher" > motrix/.launcher

# chrome-sandbox is the SUID helper for Chromium's own sandbox on a host system.
# Chromium goes through zypak here, which redirects the SUID sandbox onto the
# Flatpak sandbox, and the helper can never be setuid inside /app anyway.
rm -f motrix/chrome-sandbox

# electron-updater metadata. Its presence is what makes the app offer in-app
# updates, which cannot work against a read-only /app — Flatpak delivers updates
# instead. Removing the descriptor turns the updater off at the source rather
# than letting it fail in front of the user.
rm -f motrix/resources/app-update.yml

# resources/bin/motrix-native-host is the browser-facing Native Messaging host
# used by the .deb and .rpm installs, where the browser can execute it directly.
# It is not reachable from outside this sandbox, and upstream's own Flatpak build
# likewise keeps it out of the Flatpak payload — the Flatpak browser bridge is a
# separate host-side companion plus an in-sandbox broker (see the metainfo).
#
# Drop that one file, never the directory: resources/bin is shared with helpers
# the app itself spawns. 2.0.0-beta.39 added motrix-finalize-fs there, and
# removing the whole directory made the main process throw ENOENT during init —
# which aborts the rest of bootstrap, so no IPC handler is ever registered and
# the app comes up as an empty window with no tray.
rm -f motrix/resources/bin/motrix-native-host

rm -rf stage motrix.deb
