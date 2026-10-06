#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships Strata
# as a plain release tarball: one top-level directory holding the single
# `strata` binary next to its licenses, desktop entry, icon and D-Bus service
# files. Only the binary is needed at run time - the desktop entry, icon and
# AppStream metainfo are shipped by the manifest at build time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

for f in strata.tar.gz poppler-glib.tar.xz; do
    [ -f "$f" ] || { echo "missing extra-data: $f" >&2; exit 1; }
done

rm -rf stage strata
mkdir stage
# --no-same-owner: on a system-wide install apply_extra runs as root with every
# capability dropped, so restoring the recorded runner uid/gid would fail.
bsdtar --no-same-owner -xf strata.tar.gz -C stage

bin="$(find stage -mindepth 2 -maxdepth 2 -type f -name strata -print | head -n1)"
[ -n "$bin" ] && [ -x "$bin" ] || { echo "no strata binary in release tarball" >&2; exit 1; }

mkdir -p strata/bin strata/share/strata
mv "$bin" strata/bin/strata

# Strata looks for <exe_dir>/../share/strata/install-source.toml - the marker
# its own AUR packages install - to learn that a package manager owns the
# binary. With it present the Updates settings show who installed Strata and
# how to update it, and in-place self-update is refused instead of trying to
# overwrite a read-only /app/extra.
cat > strata/share/strata/install-source.toml <<'MARKER'
manager = "Flatpak"
update_command = "flatpak update io.github.lgse.Strata"
MARKER

rm -rf stage strata.tar.gz

# The prebuilt archive has one top-level poppler-glib/ directory holding lib/.
rm -rf poppler-glib
bsdtar --no-same-owner -xf poppler-glib.tar.xz
[ -e poppler-glib/lib/libpoppler-glib.so.8 ] || { echo "libpoppler-glib.so.8 not found in poppler-glib.tar.xz" >&2; exit 1; }
rm -f poppler-glib.tar.xz
