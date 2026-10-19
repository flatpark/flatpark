#!/usr/bin/env bash
# Update resolver for ElyPDF.
#
# Ely Office is published on the developer's own Forgejo/Gitea instance,
# git.zacharyzhang.com, not on GitHub, so this reads its Gitea API. One release
# carries every app of the suite; each app's Linux x86_64 build is the single
# `ely-pdf_<version>-<revision>_amd64.deb` asset.
#
# Not every release carries Linux builds (v0.1.7 shipped Windows installers
# only), so this walks the newest releases and takes the first one that has
# this app's .deb, rather than trusting the latest release.
#
# Prints JSON on stdout, logs on stderr; no hashing, no file writes.
set -euo pipefail

api="https://git.zacharyzhang.com/api/v1/repos/ZacharyZhang-NY/ElyOffice/releases?limit=20"
slug="ely-pdf"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need jq

rels="$(curl -fsSL --retry 3 --max-time 60 "$api")"

out="$(jq -c --arg slug "$slug" '
  [ .[] | select((.draft | not) and (.prerelease | not))
        | . as $r
        | ($r.assets[]
           | select(.name | test("^" + $slug + "_[0-9][0-9A-Za-z.+~]*-[0-9]+_amd64\\.deb$"))
           | {rel: $r, asset: .}) ]
  | first // empty' <<<"$rels")"

[ -n "$out" ] || { echo "no release with ${slug}_*_amd64.deb" >&2; exit 1; }

tag="$(jq -r '.rel.tag_name | ltrimstr("v")' <<<"$out")"
name="$(jq -r '.asset.name' <<<"$out")"
# The .deb revision (-1) is normally the same for every release; a re-cut of
# the same version under -2 must still count as a new version.
rev="$(sed -E 's/^.*-([0-9]+)_amd64\.deb$/\1/' <<<"$name")"
version="$tag"
[ "$rev" = 1 ] || version="$tag-$rev"

echo "resolved $slug $version: $name" >&2
jq --arg v "$version" '{
  version: $v,
  releaseDate: (.rel.published_at | .[0:10]),
  releaseUrl: .rel.html_url,
  sources: [{filename: "ely-pdf.deb", url: .asset.browser_download_url, size: .asset.size}]
}' <<<"$out"
