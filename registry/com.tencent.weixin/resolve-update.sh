#!/usr/bin/env bash
# Update resolver for Weixin (the official WeChat Linux client).
#
# Tencent serves the current build at a fixed, unversioned URL, so the version is
# read from the .deb itself: its ar container starts with debian-binary and a
# small control.tar.xz, and the first 128 KiB is enough to read control's
# Version field. Prints
#   { "version": "4.1.13.26", "releaseDate": "2026-10-12",
#     "sources": [ { "filename": "wechat.deb", "url": "..." } ] }
# and logs to stderr. releaseDate is the object's Last-Modified date.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq; need python3

url="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL -r 0-131071 -D "$tmp/headers" -o "$tmp/head.bin" "$url"

version="$(python3 -I - "$tmp/head.bin" <<'PY'
import io, sys, tarfile
b = open(sys.argv[1], "rb").read()
if b[:8] != b"!<arch>\n":
    sys.exit("not a .deb (ar) archive")
o = 8
while o + 60 <= len(b):
    name = b[o:o+16].decode().strip().rstrip("/"); size = int(b[o+48:o+58]); o += 60
    if name.startswith("control.tar"):
        t = tarfile.open(fileobj=io.BytesIO(b[o:o+size]))
        for line in t.extractfile("./control").read().decode().splitlines():
            if line.startswith("Version:"):
                print(line.split(":", 1)[1].strip()); sys.exit(0)
        break
    o += size + (size & 1)
sys.exit("no Version in control")
PY
)"

lm="$(grep -i '^last-modified:' "$tmp/headers" | tail -n1 | cut -d' ' -f2- | tr -d '\r')"
date=""
[ -n "$lm" ] && date="$(date -u -d "$lm" +%Y-%m-%d 2>/dev/null || true)"

[ -n "$version" ] || { echo "failed to resolve Weixin version" >&2; exit 1; }
echo "resolved Weixin $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"wechat.deb", url:$u}]}'
