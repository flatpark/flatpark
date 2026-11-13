#!/usr/bin/env bash
# Resolve the newest stable GitHub release and pin its official Linux x64 tarball.
set -euo pipefail

repo="rotki/rotki"
release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases/latest")"
tag="$(jq -r '.tag_name' <<<"$release")"
version="${tag#v}"
date="$(jq -r '.published_at // empty' <<<"$release" | cut -c1-10)"
url="$(jq -r --arg n "rotki-linux_x64-${tag}.tar.xz" \
  '.assets[] | select(.name == $n) | .browser_download_url' <<<"$release")"
sha256="$(jq -r --arg n "rotki-linux_x64-${tag}.tar.xz" \
  '.assets[] | select(.name == $n) | .digest | sub("^sha256:"; "")' <<<"$release")"
size="$(jq -r --arg n "rotki-linux_x64-${tag}.tar.xz" \
  '.assets[] | select(.name == $n) | .size' <<<"$release")"

[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || {
  echo "unexpected release tag: $tag" >&2; exit 1;
}
[[ -n "$date" && -n "$url" && "$sha256" =~ ^[0-9a-f]{64}$ && "$size" =~ ^[0-9]+$ ]] || {
  echo "release $tag has no complete Linux x64 tarball pin" >&2; exit 1;
}

jq -n --arg v "$version" --arg d "$date" --arg u "$url" \
  --arg h "$sha256" --argjson s "$size" --arg rel "https://github.com/$repo/releases/tag/$tag" \
  '{version:$v, releaseDate:$d, releaseUrl:$rel, sources:[{filename:"rotki.tar.xz",url:$u,sha256:$h,size:$s}]}'
