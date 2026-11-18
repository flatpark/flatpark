#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Upstream ships
# Drosophila as a single standalone executable, downloaded as `drosophila`.
# It is moved to a fixed path; /app/bin/drosophila is a relative symlink to it
# (see the manifest for why it is not a wrapper script).

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f drosophila ] || { echo "missing extra-data: drosophila" >&2; exit 1; }

# Fail on a release that is no longer a bare ELF executable (an archive, say),
# instead of shipping something the symlink can't run.
magic="$(head -c 4 drosophila | od -An -tx1 | tr -d ' \n')"
[ "$magic" = "7f454c46" ] || { echo "drosophila download is not an ELF executable" >&2; exit 1; }

rm -rf stage
mkdir stage
mv drosophila stage/drosophila
chmod 755 stage/drosophila
rm -rf drosophila
mv stage drosophila
