#!/usr/bin/env bash
# Update resolver for WPS Office (International Edition, wps.com).
#
# wps.com's Linux page takes its download links from
#   https://global.wps.com/activity/seo-api/v1/seo-engine-api/channel_config
# whose downloadUrl.linux.debUrl is a fixed, unversioned URL. The URL is read
# from that endpoint, so a move is followed, and the version is read from the
# .deb itself: its ar container starts with debian-binary and a small
# control.tar.gz, and the first 256 KiB is enough to read control's Version
# field ("12.1.2.29182.AK.preread.sw"; the four-part number is kept).
# Prints
#   { "version": "12.1.2.29182", "releaseDate": "2026-10-08",
#     "sources": [ { "filename": "wps-office.deb", "url": "..." } ] }
# and logs to stderr. releaseDate is the object's Last-Modified date.
# Only an amd64 .deb (and an x86_64 .rpm of the same build) is published, so
# only x86_64 is packaged.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq; need python3

config="https://global.wps.com/activity/seo-api/v1/seo-engine-api/channel_config?domain=www.wps.com"
url="$(curl -fsSL "$config" | jq -r '.downloadUrl.linux.debUrl // empty')"
case "$url" in
    https://*.wpscdn.com/*.deb) ;;
    *) echo "unexpected Linux .deb URL from $config: '$url'" >&2; exit 1 ;;
esac

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL -r 0-262143 -D "$tmp/headers" -o "$tmp/head.bin" "$url"

raw="$(python3 -I - "$tmp/head.bin" <<'PY'
import io, sys, tarfile
b = open(sys.argv[1], "rb").read()
if b[:8] != b"!<arch>\n":
    sys.exit("not a .deb (ar) archive")
o = 8
while o + 60 <= len(b):
    name = b[o:o+16].decode().strip().rstrip("/"); size = int(b[o+48:o+58]); o += 60
    if name.startswith("control.tar"):
        t = tarfile.open(fileobj=io.BytesIO(b[o:o+size]))
        control = t.extractfile("./control").read().decode()
        fields = dict(l.split(":", 1) for l in control.splitlines() if ":" in l and not l[0].isspace())
        if fields.get("Package", "").strip() != "wps-office":
            sys.exit("control is not for package wps-office")
        if fields.get("Architecture", "").strip() != "amd64":
            sys.exit("control is not for amd64")
        print(fields.get("Version", "").strip()); sys.exit(0)
    o += size + (size & 1)
sys.exit("no control.tar in the first 256 KiB")
PY
)"

version="$(grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' <<<"$raw" || true)"
[ -n "$version" ] || { echo "failed to parse WPS Office version from '$raw'" >&2; exit 1; }

lm="$(grep -i '^last-modified:' "$tmp/headers" | tail -n1 | cut -d' ' -f2- | tr -d '\r')"
date=""
[ -n "$lm" ] && date="$(date -u -d "$lm" +%Y-%m-%d 2>/dev/null || true)"

echo "resolved WPS Office $version ($raw, ${date:-no date}): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end) + {sources:[{filename:"wps-office.deb", url:$u}]}'
