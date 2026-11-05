#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. The payload is
# upstream's `Leaf-<version>-flatpark-x86_64.tar.xz`: the /app tree out of the
# same flatpak build that produces their own Leaf .flatpak bundle, published as
# a release asset for this package (flatpark#994). Contents sit at the archive
# root: bin/leaf, and share/ with the gettext catalogs, the bundled Hunspell
# dictionaries and the app's own action icons. No GTK: GTK 4, libadwaita, glib,
# cairo and pango come from this runtime, as they do for upstream's bundle.
#
# Stage it whole at a stable path the wrapper execs: /app/extra/leaf. Leaf finds
# share/locale, share/hunspell and share/icons relative to its own executable,
# so the tree works from there as shipped. The desktop file, icon and AppStream
# metainfo are shipped by the manifest at *build* time: extra-data is fetched
# later on the user's machine, so anything Flatpak must export cannot come from
# here.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f leaf-app.tar.xz ] || { echo "missing extra-data: leaf-app.tar.xz" >&2; exit 1; }

rm -rf leaf
mkdir leaf
# --no-same-owner: on a system-wide install Flatpak runs apply_extra as root
# with every capability dropped, so restoring the archive's recorded uid/gid
# fails and aborts the unpack even though every member extracted fine.
bsdtar --no-same-owner -xf leaf-app.tar.xz -C leaf

# Which file is the launcher? The tree's own desktop entry says so in its Exec
# line, and that is upstream's to rename; reading it here rather than writing
# the name into the wrapper keeps an automated pin refresh from shipping an app
# nobody can start (flatpark#130).
desktop="$(set -- leaf/share/applications/*.desktop; echo "$1")"
[ -f "$desktop" ] || { echo "no desktop entry in the app tree to read the launcher from" >&2; exit 1; }
launcher="$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$desktop" | head -n1)"
[ -n "$launcher" ] || { echo "no Exec= in $desktop" >&2; exit 1; }
[ -x "leaf/bin/$launcher" ] || { echo "launcher '$launcher' from the desktop entry is not executable in the app tree" >&2; exit 1; }
# Beside the tree, not inside it: the upstream tree stays exactly as shipped.
printf '%s\n' "$launcher" > launcher

# Without the catalogs every locale but English falls back to source strings,
# and without the dictionaries spelling review has no language to check.
[ -d leaf/share/locale ] || { echo "share/locale missing from the app tree" >&2; exit 1; }
[ -d leaf/share/hunspell ] || { echo "share/hunspell missing from the app tree" >&2; exit 1; }

rm -f leaf-app.tar.xz
