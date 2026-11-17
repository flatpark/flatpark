#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f platform-tools.zip ] || { echo "missing extra-data: platform-tools.zip" >&2; exit 1; }
rm -rf stage platform-tools
mkdir stage
# System-wide installs run as root without capabilities; do not restore owners.
bsdtar --no-same-owner -xf platform-tools.zip -C stage
top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] && [ -n "$top" ] || {
    echo "expected one platform-tools directory" >&2; exit 1;
}
mv "$top" platform-tools
for tool in adb fastboot etc1tool hprof-conv make_f2fs make_f2fs_casefold mke2fs sqlite3; do
    [ -x "platform-tools/$tool" ] || { echo "missing executable: $tool" >&2; exit 1; }
done
[ -f platform-tools/source.properties ] && [ -f platform-tools/NOTICE.txt ] || {
    echo "missing version or license notices" >&2; exit 1;
}
rm -rf stage platform-tools.zip
