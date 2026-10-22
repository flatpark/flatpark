#!/usr/bin/env bash
# Resolve the latest google-chrome-stable from Google's apt repository.
#
# The resolver only discovers URLs and release metadata. FlatPark's
# update-pins.mjs downloads each package and computes its sha256 and size.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

repo_root="https://dl.google.com/linux/chrome/deb"

# Prints "<Version> <Filename>" of google-chrome-stable for one Debian arch.
resolve() {
    curl -fsSL "$repo_root/dists/stable/main/binary-$1/Packages" | awk '
        BEGIN { RS=""; FS="\n" }
        {
            package = version = filename = ""
            for (i = 1; i <= NF; i++) {
                split($i, kv, ": ")
                if (kv[1] == "Package") package = kv[2]
                if (kv[1] == "Version") version = kv[2]
                if (kv[1] == "Filename") filename = kv[2]
            }
            if (package == "google-chrome-stable") { print version, filename; exit }
        }'
}

read -r amd64_version amd64_file < <(resolve amd64)
read -r arm64_version arm64_file < <(resolve arm64)

[ -n "${amd64_file:-}" ] && [ -n "${arm64_file:-}" ] \
    || { echo "failed to resolve google-chrome-stable" >&2; exit 1; }
# Both arches have to move together; wait until Google publishes both.
[ "$amd64_version" = "$arm64_version" ] \
    || { echo "amd64 ($amd64_version) and arm64 ($arm64_version) differ" >&2; exit 1; }

version="${amd64_version%-1}"
echo "resolved Chrome $amd64_version" >&2
jq -n --arg v "$version" --arg x "$repo_root/$amd64_file" --arg a "$repo_root/$arm64_file" \
    '{version:$v, sources:[
      {filename:"chrome.deb", arch:"x86_64", url:$x},
      {filename:"chrome.deb", arch:"aarch64", url:$a}
    ]}'
