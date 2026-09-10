#!/usr/bin/env bash
# Decide how much of a publish a push actually needs. Prints "site" when the
# diff provably cannot change the OSTree repo or the discovery files, and
# "full" otherwise.
#
# A "site" scope lets the publish workflow skip its expensive half — the
# flatpak toolchain, the signing key, the repo cache, the R2 pull (minutes of
# rclone on a catalog-sized object store) and the R2 push — and go straight to
# rebuilding the site and deploying Pages. That half is skippable only when the
# published bytes are untouched, so the rule here is deliberately one-sided:
# anything not known to be repo-neutral answers "full".
#
# Repo-neutral (site-only): site/**, config/featured.yml, docs, tests, other
# workflows, and the registry edits that already do not trigger a rebuild
# (catalog/policy fields, metainfo, icons, screenshots — see changed-apps.sh).
#
# Repo-affecting (full), in the order checked below:
#   1. the publish tooling itself (scripts/, config/flatpark.conf, publish.yml)
#   2. a build-relevant app change (changed-apps.sh)
#   3. an app added or de-listed — a new app needs its ref built and its
#      .flatpakref uploaded; a de-list needs the summary regenerated and the
#      stale refs dropped from R2 (changed-apps.sh ignores both by design)
#   4. a renamed app — `name:` is baked into the .flatpakref as Title
#
# Usage: publish-scope.sh <base-ref> [head-ref]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
load_config "$ROOT"
need git
base="${1:?usage: publish-scope.sh <base-ref> [head-ref]}"
head="${2:-HEAD}"

full() { log "full publish: $1"; printf 'full\n'; exit 0; }
changed() { git -C "$ROOT" diff --name-only "$base" "$head" -- "$@"; }
oneline() { tr '\n' ' ' | sed 's/ $//'; }

tooling="$(changed scripts/ config/flatpark.conf .github/workflows/publish.yml | oneline)"
if [ -n "$tooling" ]; then
    full "publish tooling changed ($tooling)"
fi

ids="$("$ROOT/scripts/changed-apps.sh" "$base" "$head" | oneline)"
if [ -n "$ids" ]; then
    full "build-relevant app change ($ids)"
fi

added_removed="$(git -C "$ROOT" diff --name-only --diff-filter=AD "$base" "$head" \
                   -- 'registry/*/flatpark.yml' | oneline)"
if [ -n "$added_removed" ]; then
    full "app added or de-listed ($added_removed)"
fi

# `name:` at column 0 is the descriptor's app name (read-descriptor.mjs is a
# line scanner, so nested name: keys are indented and never match here).
descriptor_name() {
    { git -C "$ROOT" show "$1:$2" 2>/dev/null || true; } | sed -n 's/^name: *//p'
}
while IFS= read -r file; do
    [ -n "$file" ] || continue
    if [ "$(descriptor_name "$base" "$file")" != "$(descriptor_name "$head" "$file")" ]; then
        full "app renamed ($file) — its .flatpakref Title changes"
    fi
done < <(changed 'registry/*/flatpark.yml')

log "site-only publish: nothing in this diff can change the repo or discovery files"
printf 'site\n'
