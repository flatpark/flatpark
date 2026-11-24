#!/usr/bin/env bash
set -euo pipefail

url=https://getqspice.com/InstallQSPICE.exe
# The rolling URL serves Qorvo's downloader. Its timestamp identifies the
# pinned file independently of the application updates Qorvo serves to it.
headers="$(curl -fsSIL --retry 3 "$url")"
modified="$(sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' <<<"$headers" | tr -d '\r' | tail -n1)"
[[ -n "$modified" ]] || { echo 'QSPICE downloader has no Last-Modified header' >&2; exit 1; }
version="$(date -u -d "$modified" +%Y%m%d%H%M%S)"
release_date="$(date -u -d "$modified" +%Y-%m-%d)"
jq -n --arg v "$version" --arg d "$release_date" --arg u "$url" \
  '{version:$v, releaseDate:$d, sources:[{filename:"InstallQSPICE.exe", url:$u}]}'
