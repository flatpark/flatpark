#!/usr/bin/env bash
# Update resolver for WPS Office for Linux, mainland China edition (linux.wps.cn).
#
# linux.wps.cn's download page lists the current build, e.g.
#   <p class="version_code">版本12.1.2.29183  2026.10.12</p>
# and links the .deb at wps-linux-personal.wpscdn.cn, but only with a
# signature its page script adds at click time (?t=<now>&k=<md5>), which
# expires; the bare URL answers 403. Such a link can't be pinned as
# extra-data. Ubuntu Kylin's partner pool carries the same .deb (same sha256)
# at a versioned URL that stays put:
#   https://archive.ubuntukylin.com/software/pool/partner/wps-office_<version>_amd64.deb
# So the version and date come from linux.wps.cn, the file from the pool, and
# the control file in the pool's .deb is checked to be that wps-office build
# for linux.wps.cn. If the pool hasn't got the version linux.wps.cn announces
# yet, this fails and the app stays on its current pin until it has.
# Prints
#   { "version": "12.1.2.29183", "releaseDate": "2026-10-12",
#     "sources": [ { "filename": "wps-office.deb", "url": "..." } ] }
# and logs to stderr. Only amd64 is published.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq; need python3

page="https://linux.wps.cn/"
pool="https://archive.ubuntukylin.com/software/pool/partner"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$page" -o "$tmp/page.html"

# The deb card comes first; take the first version_code on the page.
line="$(grep -oE 'version_code">[^<]*' "$tmp/page.html" | head -n1 || true)"
version="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' <<<"$line" | head -n1 || true)"
[ -n "$version" ] || { echo "no version on $page ('$line')" >&2; exit 1; }
# The .deb link on the page must name the same build.
grep -qE "wps-office_${version//./\\.}\.[^\"']*_amd64\.deb" "$tmp/page.html" || {
    echo "$page shows $version but links no amd64 .deb of it" >&2; exit 1; }
date=""
if d="$(grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}' <<<"$line" | head -n1)"; then
    date="${d//./-}"
fi

url="$pool/wps-office_${version}_amd64.deb"
code="$(curl -sS -o "$tmp/head.bin" -w '%{http_code}' -r 0-262143 "$url")"
case "$code" in
    200|206) ;;
    *) echo "$url: HTTP $code (pool hasn't got $version from $page yet?)" >&2; exit 1 ;;
esac

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
        f = lambda k: fields.get(k, "").strip()
        if f("Package") != "wps-office":
            sys.exit("control is not for package wps-office")
        if f("Architecture") != "amd64":
            sys.exit("control is not for amd64")
        if f("Homepage").rstrip("/") != "https://linux.wps.cn":
            sys.exit("control Homepage is not linux.wps.cn: " + f("Homepage"))
        print(f("Version")); sys.exit(0)
    o += size + (size & 1)
sys.exit("no control.tar in the first 256 KiB")
PY
)"
case "$raw" in
    "$version".*|"$version") ;;
    *) echo "$url: control Version '$raw' is not $version" >&2; exit 1 ;;
esac

echo "resolved WPS Office CN $version ($raw, ${date:-no date}): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  '{version:$v} + (if $d == "" then {} else {releaseDate:$d} end) + {sources:[{filename:"wps-office.deb", url:$u}]}'
