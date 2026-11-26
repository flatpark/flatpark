#!/bin/sh
set -eu

# Runs offline at install time inside org.freedesktop.Platform. The official .deb
# is an FHS tree rooted at opt/wechat/; keep that directory as /app/extra/wechat/,
# where the wrapper expects it. Desktop file, icon and metainfo come from the
# manifest at build time.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

[ -f wechat.deb ] || { echo "missing extra-data: wechat.deb" >&2; exit 1; }

# The Platform has no ar/dpkg; bsdtar reads the .deb ar container directly.
# --no-same-owner: a system-wide install runs this as root with capabilities
# dropped, so restoring recorded ownership would abort the unpack.
bsdtar -xOf wechat.deb 'data.tar*' | bsdtar --no-same-owner -xf - ./opt/wechat
rm -rf wechat
mv opt/wechat wechat
rmdir opt
[ -x wechat/wechat ] || { echo "wechat binary not found in .deb" >&2; exit 1; }

# Route WeChatAppEx (embedded Chromium) through /app/bin/weixin-appex, which
# adds --no-sandbox; see that wrapper.
appex=wechat/RadiumWMPF/runtime/WeChatAppEx
[ -x "$appex" ] || { echo "WeChatAppEx not found in .deb" >&2; exit 1; }
mv "$appex" "$appex.bin"
ln -s /app/bin/weixin-appex "$appex"

rm -f wechat.deb
