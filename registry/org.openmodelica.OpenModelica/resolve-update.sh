#!/usr/bin/env bash
# Resolve the current official OpenModelica release and its Trixie packages.
# The release archive keeps versioned package URLs immutable. This prints only
# JSON on stdout, logs on stderr and touches no files.
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing command: $1" >&2; exit 1; }; }
need curl; need gzip; need jq; need awk

api="https://openmodelica.org/api/linux.json"
version="$(curl -fsSL "$api" | jq -r '.version.release')"
[ -n "$version" ] && [ "$version" != null ] || { echo "failed to resolve official release" >&2; exit 1; }

github="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
    "https://api.github.com/repos/OpenModelica/OpenModelica/releases/tags/v$version")"
date="$(jq -r '.published_at' <<<"$github" | cut -c1-10)"
release_url="$(jq -r '.html_url' <<<"$github")"

base="https://build.openmodelica.org/omc/builds/linux/releases/$version"
packages="$(curl -fsSL "$base/dists/trixie/release/binary-amd64/Packages.gz" | gzip -dc)"

field() {
    local package="$1" name="$2"
    awk -v wanted="$package" -v field="$name" '
      BEGIN { RS=""; FS="\n" }
      {
        package=""
        for (i=1; i<=NF; i++) if ($i ~ /^Package: /) package=substr($i,10)
        if (package == wanted)
          for (i=1; i<=NF; i++) if ($i ~ ("^" field ": ")) { print substr($i,length(field)+3); exit }
      }
    ' <<<"$packages"
}

sources='[]'
for spec in \
    omc.deb:omc \
    omc-common.deb:omc-common \
    libomc.deb:libomc \
    libomcsimulation.deb:libomcsimulation \
    omedit.deb:omedit \
    libomplot.deb:libomplot \
    libomsimulator.deb:libomsimulator \
    libomsensplugin.deb:libomsensplugin \
    omlibrary.deb:omlibrary
do
    filename="${spec%%:*}"
    package="${spec#*:}"
    path="$(field "$package" Filename)"
    [ -n "$path" ] || { echo "package not found: $package" >&2; exit 1; }
    sources="$(jq -c --arg f "$filename" --arg u "$base/$path" \
        '. + [{filename:$f,url:$u}]' <<<"$sources")"
done

echo "resolved OpenModelica $version ($date), ${sources@Q}" >&2
jq -n --arg v "$version" --arg d "$date" --arg r "$release_url" --argjson s "$sources" \
    '{version:$v, releaseDate:$d, releaseUrl:$r, sources:$s}'
