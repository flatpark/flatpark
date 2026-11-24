#!/usr/bin/env bash
# Resolve the latest Ladybird .deb for Ubuntu 24.04 (noble).
#
# Ladybird ships Linux builds through its own apt repository, not as files on
# download.ladybird.org. The noble Packages index names each .deb with its
# pool path, size and sha256, so the pin needs no download. The release date
# comes from upstream's release manifest when it lists the same version.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

repo="https://apt.ladybird.org"

# Prints "version filename size sha256" for the newest ladybird entry.
entry() {
    curl -fsSL "$repo/dists/noble/main/binary-$1/Packages" | awk '
        /^Package: /  { p = $2 }
        /^Version: /  { v = $2 }
        /^Filename: / { f = $2 }
        /^Size: /     { s = $2 }
        /^SHA256: /   { h = $2 }
        /^$/          { if (p == "ladybird") print v, f, s, h; p = "" }
        END           { if (p == "ladybird") print v, f, s, h }
    ' | sort -V | tail -n1
}

read -r v_amd f_amd s_amd h_amd < <(entry amd64)
read -r v_arm f_arm s_arm h_arm < <(entry arm64)
[ -n "${v_amd:-}" ] && [ -n "${f_amd:-}" ] && [ -n "${f_arm:-}" ] \
    || { echo "ladybird not found in the noble Packages index" >&2; exit 1; }
[ "$v_amd" = "$v_arm" ] \
    || { echo "amd64 ($v_amd) and arm64 ($v_arm) are at different versions" >&2; exit 1; }

# 2026.47.7-1~ubuntu24.04 -> 2026.47.7; a later Debian revision (-2) is kept so
# a rebuilt package is still picked up.
version="${v_amd%%~*}"
version="${version%-1}"
upstream="${version%%-*}"

date="$(curl -fsSL https://download.ladybird.org/releases.json \
    | jq -r --arg v "$upstream" '.releases[] | select(.version == $v) | .published' \
    | head -n1 | cut -c1-10)"

echo "resolved Ladybird $version (${date:-no date})" >&2
jq -n --arg v "$version" --arg d "$date" \
    --arg ua "$repo/$f_amd" --arg sa "$s_amd" --arg ha "$h_amd" \
    --arg ub "$repo/$f_arm" --arg sb "$s_arm" --arg hb "$h_arm" \
    '{version:$v}
     + (if $d != "" then {releaseDate:$d} else {} end)
     + {releaseUrl:("https://github.com/LadybirdBrowser/ladybird/releases/tag/" + ($v | split("-")[0])),
        sources:[
          {arch:"x86_64",  filename:"ladybird.deb", url:$ua, size:($sa|tonumber), sha256:$ha},
          {arch:"aarch64", filename:"ladybird.deb", url:$ub, size:($sb|tonumber), sha256:$hb}
        ]}'
