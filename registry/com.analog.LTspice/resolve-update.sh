#!/usr/bin/env bash
set -euo pipefail

base="https://ltspice.analog.com/software"
metadata="$(curl -fsSL --retry 3 "$base/LTspice.json")"
version="$(jq -er '[.Downloads[] | select(.Filename == "LTspice64.msi") | .Version] | if length == 1 then .[0] else error("expected one x64 MSI") end' <<<"$metadata")"
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "invalid LTspice version: $version" >&2; exit 1; }

# Analog Devices publishes a rolling URL, including installer/model refreshes
# between program releases. Include its Last-Modified timestamp so those also
# trigger a checksum refresh, even when the file size has stayed the same.
headers="$(curl -fsSI --retry 3 "$base/LTspice64.msi")"
modified="$(sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' <<<"$headers" | tr -d '\r' | tail -n1)"
[ -n "$modified" ] || { echo "MSI has no Last-Modified header" >&2; exit 1; }
stamp="$(date -u -d "$modified" +%Y%m%d%H%M%S)"
release_date="$(date -u -d "$modified" +%Y-%m-%d)"
jq -n --arg v "$version-$stamp" --arg d "$release_date" --arg u "$base/LTspice64.msi" \
  '{version:$v, releaseDate:$d, sources:[{filename:"LTspice64.msi", url:$u}]}'
