#!/usr/bin/env bash
# Update resolver for MyGo Music: the latest GitHub release and its official
# Linux tarballs (mygo-music-<ver>-linux-{amd64,arm64}.tar.gz).
set -euo pipefail

repo="egoist/mygo-music"

rel="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
        "https://api.github.com/repos/$repo/releases/latest")"

version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$rel")"
date="$(jq -r '.published_at' <<<"$rel" | cut -c1-10)"
asset() {
  jq -r --arg n "mygo-music-$version-linux-$1.tar.gz" \
    '.assets[] | select(.name == $n) | .browser_download_url' <<<"$rel" | head -n1
}
url="$(asset amd64)"
url_arm="$(asset arm64)"

[ -n "$version" ] && [ "$version" != "null" ] && [ -n "$url" ] && [ -n "$url_arm" ] \
  || { echo "failed to resolve MyGo Music release" >&2; exit 1; }
echo "resolved MyGo Music $version ($date): $url" >&2

jq -n --arg v "$version" --arg d "$date" --arg u "$url" --arg ua "$url_arm" \
  --arg r "https://github.com/$repo/releases/tag/v$version" \
  '{version:$v, releaseDate:$d, releaseUrl:$r,
    sources:[{filename:"mygo-music.tar.gz", arch:"x86_64", url:$u},
             {filename:"mygo-music.tar.gz", arch:"aarch64", url:$ua}]}'
