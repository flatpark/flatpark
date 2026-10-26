#!/bin/sh
set -eu
# Both downloads are official binaries, unpacked offline at install time.
cd "${EXTRA_ROOT:-/app/extra}"
for archive in uad-ng.tar.gz platform-tools.zip; do
    [ -s "$archive" ] || { echo "missing extra-data: $archive" >&2; exit 1; }
done
rm -rf stage uad-ng platform-tools
mkdir stage
bsdtar --no-same-owner -xf uad-ng.tar.gz -C stage
# Discover the sole executable, without depending on its release filename.
binary="$(find stage -type f -perm /111)"
[ -n "$binary" ] && [ "$(printf '%s\n' "$binary" | wc -l)" -eq 1 ] || {
    echo "expected exactly one UAD-ng executable in the tarball" >&2; exit 1;
}
mv "$binary" uad-ng
bsdtar --no-same-owner -xf platform-tools.zip
[ -x uad-ng ] && [ -x platform-tools/adb ] || {
    echo "UAD-ng or ADB executable missing from the downloads" >&2; exit 1;
}
rm -rf stage uad-ng.tar.gz platform-tools.zip
