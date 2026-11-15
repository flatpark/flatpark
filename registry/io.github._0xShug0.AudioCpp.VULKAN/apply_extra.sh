#!/bin/sh
set -eu
[ -f audio.tar.gz ] || { echo "Missing audio.tar.gz" >&2; exit 1; }
mkdir audio
tar --no-same-owner -xzf audio.tar.gz -C audio
for binary in audiocpp_server audiocpp_cli audiocpp_gguf; do
    [ -x "audio/$binary" ] || { echo "Missing executable: $binary" >&2; exit 1; }
done
rm audio.tar.gz
