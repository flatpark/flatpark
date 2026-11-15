#!/usr/bin/env bash
# Resolve the newest Nuvio Desktop release and its exact x86_64 .deb.
# FlatPark computes and rewrites the managed SHA-256 and size pins.
set -euo pipefail

repo=NuvioMedia/NuvioDesktop
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl
need jq

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
# Tags carry no "v" and, while upstream is in alpha, a "-alpha" suffix
# (0.1.36-alpha). GitHub doesn't flag these as prereleases, so /latest is the
# newest build; the suffix is kept in the version so it matches upstream's.
tag="$(jq -er '.tag_name | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.]+)?$"))' <<<"$release")"
date="$(jq -er '.published_at | split("T")[0]' <<<"$release")"

# Each release carries .deb, .rpm, AppImage, .flatpak, Windows and macOS
# builds; match the exact .deb name so a new flavour is never picked up.
name="Nuvio-Linux-x86_64-${tag}.deb"
url="$(jq -er --arg name "$name" \
  '[.assets[] | select(.name == $name)] | if length == 1 then .[0].browser_download_url else error("expected exactly one \($name)") end' \
  <<<"$release")"
[[ "$url" == "https://github.com/$repo/releases/download/$tag/$name" ]] || {
  echo "refusing unexpected release asset URL: $url" >&2
  exit 1
}

echo "resolved Nuvio $tag ($date)" >&2
jq -n --arg v "$tag" --arg d "$date" --arg u "$url" \
  --arg r "https://github.com/$repo/releases/tag/$tag" \
  '{version:$v, releaseDate:$d, releaseUrl:$r, sources:[
     {filename:"nuvio.deb", url:$u}
   ]}'
