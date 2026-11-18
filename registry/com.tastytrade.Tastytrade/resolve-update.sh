#!/usr/bin/env bash
set -euo pipefail
base=https://download.tastytrade.com/desktop-2.0
metadata=$(curl -fsSL "$base/latest-linux.yml")
version=$(sed -n 's/^version: *//p' <<< "$metadata")
date=$(sed -n "s/^releaseDate: *'\{0,1\}\([0-9-]*\).*/\1/p" <<< "$metadata")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ && "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo 'invalid release metadata' >&2; exit 1; }
amd="$base/tastytrade-linux-amd64-$version.deb"
arm="$base/tastytrade-linux-arm64-$version.deb"
# Report each download's size so FlatPark notices same-version replacements
# that change size. The vendor's x86 feed provides SHA-512, not the SHA-256
# accepted by update-pins; no arm64 checksum feed was found. Same-size
# replacements therefore cannot be detected by this resolver.
size_of() {
  local size
  size=$(curl -fsSIL "$1" | awk '
    /^HTTP\// { size="" }
    tolower($1) == "content-length:" { gsub("\r", "", $2); size=$2 }
    END { print size }
  ')
  [[ "$size" =~ ^[1-9][0-9]*$ ]] || { echo "missing or invalid Content-Length for $1" >&2; return 1; }
  printf '%s' "$size"
}
amd_size=$(size_of "$amd")
arm_size=$(size_of "$arm")
jq -n --arg v "$version" --arg d "$date" --arg amd "$amd" --arg arm "$arm" \
  --argjson amd_size "$amd_size" --argjson arm_size "$arm_size" \
  '{version:$v,releaseDate:$d,sources:[{filename:"tastytrade.deb",arch:"x86_64",url:$amd,size:$amd_size},{filename:"tastytrade.deb",arch:"aarch64",url:$arm,size:$arm_size}]}'
