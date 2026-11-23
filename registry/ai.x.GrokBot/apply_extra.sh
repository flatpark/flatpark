#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The official
# Debian package installs the Electron application tree under "/opt/Grok Bot"
# and creates the /usr/bin symlink in its postinst script. Unpack the data
# archive, locate the app directory and launcher name from the payload rather
# than hardcoding names upstream could rename, and keep the tree at a stable
# path without spaces: /app/extra/grok-bot.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f grok-bot.deb ] || { echo "missing extra-data: grok-bot.deb" >&2; exit 1; }

rm -rf stage grok-bot grok-bot-launcher
mkdir stage

# The runtime has no ar/dpkg; bsdtar reads the .deb ar container directly.
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with all capabilities dropped, so restoring uid/gid would fail with EPERM.
bsdtar -xOf grok-bot.deb 'data.tar*' | bsdtar --no-same-owner -xf - -C stage

# Find the Electron app directory under stage/opt by locating resources/app.asar.
appdir=""
count=0
for candidate in stage/opt/*; do
  [ -d "$candidate" ] || continue
  if [ -f "$candidate/resources/app.asar" ]; then
    appdir="$candidate"
    count=$((count + 1))
  fi
done
[ "$count" -eq 1 ] || {
  echo "expected 1 Electron app directory under opt/, found $count" >&2
  exit 1
}

# Read the launcher binary name from the shipped .desktop file's Exec= line
# (e.g. `Exec=grok-bot -- %U`) so automated pin refreshes survive a rename.
launcher=""
for desktop in stage/usr/share/applications/*.desktop; do
  [ -f "$desktop" ] || continue
  exec_val="$(sed -n 's/^Exec=//p' "$desktop" | head -n 1)"
  [ -n "$exec_val" ] || continue
  case "$exec_val" in
    \"*\")
      first="${exec_val#\"}"
      first="${first%%\"*}"
      ;;
    *)
      first="${exec_val%% *}"
      ;;
  esac
  launcher="$(basename "$first")"
  break
done

[ -n "$launcher" ] || { echo "could not determine launcher name from .deb desktop entry" >&2; exit 1; }
[ -x "$appdir/$launcher" ] || { echo "launcher '$launcher' not executable in $appdir" >&2; exit 1; }

mv "$appdir" grok-bot

# Clear any setuid/setgid bits (such as chrome-sandbox) so system-wide installs
# never leave a setuid binary in /app/extra; zypak handles sandboxing instead.
chmod -R a-s grok-bot

# Record the resolved launcher name beside the app tree so the upstream tree
# stays unmodified.
printf '%s\n' "$launcher" > grok-bot-launcher

rm -rf stage grok-bot.deb

[ -x "grok-bot/$launcher" ] || { echo "Grok Bot launcher missing after stage" >&2; exit 1; }
[ -f "grok-bot/resources/app.asar" ] || { echo "resources/app.asar missing after stage" >&2; exit 1; }
