#!/usr/bin/env bash
# Dead-link check for a PR: only links the PR itself introduced can fail it.
#
# Checks every app the PR touches (any file), then sorts each broken link:
#   - the app is new in this PR, or the URL appears on an added line of the
#     PR's diff for that app  -> the PR brought it in: error, exit 1;
#   - otherwise the link was already there on the base and rotted upstream
#     -> a warning only. The daily link-check workflow tracks those in its
#     ci-alert issue, so an unrelated edit to the app is not blocked by them.
#
# Usage: scripts/check-links-pr.sh <base-ref> [head-ref]
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
need git
need node
base="${1:?usage: check-links-pr.sh <base-ref> [head-ref]}"
head="${2:-HEAD}"

ids="$("$ROOT/scripts/changed-apps.sh" --any-change "$base" "$head" | tr '\n' ' ')"
if [ -z "${ids// /}" ]; then
    log "no app changes; skipping link check"
    exit 0
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
LINK_CHECK_JSON_OUT="$tmp/report.json" "$ROOT/scripts/check-links.sh" $ids && exit 0
[ -s "$tmp/report.json" ] || die "check-links failed before it produced a report"

# Per app: "new" if it did not exist on the base, else the PR's added lines.
for id in $ids; do
    if git -C "$ROOT" cat-file -e "$base:registry/$id/flatpark.yml" 2>/dev/null; then
        git -C "$ROOT" diff "$base" "$head" -- "registry/$id/" \
            | sed -n 's/^+\([^+]\)/\1/p' > "$tmp/added.$id"
    else
        echo new > "$tmp/new.$id"
    fi
done

node - "$tmp" <<'EOF'
const { readFileSync, existsSync } = require('node:fs');
const { join } = require('node:path');
const dir = process.argv[2];
const { results } = JSON.parse(readFileSync(join(dir, 'report.json'), 'utf8'));
let introduced = 0;
for (const r of results.filter((x) => !x.ok)) {
  const isNew = existsSync(join(dir, `new.${r.app}`));
  const addedFile = join(dir, `added.${r.app}`);
  const added = existsSync(addedFile) ? readFileSync(addedFile, 'utf8') : '';
  // The metainfo carries URLs XML-escaped.
  const hit = isNew || added.includes(r.url) || added.includes(r.url.replaceAll('&', '&amp;'));
  const what = `${r.app} [${r.type}] ${r.status || r.error} ${r.url}`;
  if (hit) {
    introduced++;
    console.log(`::error title=Broken link added by this PR::${what}`);
  } else {
    console.log(`::warning title=Broken link already on the base branch::${what} (not from this PR; tracked by the daily link-check)`);
  }
}
process.exit(introduced > 0 ? 1 : 0);
EOF
