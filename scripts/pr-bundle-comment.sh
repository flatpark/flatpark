#!/usr/bin/env bash
# Post (or refresh) the "test this build" comment on a PR from the bundles a
# pr-checks run uploaded.
#
#   pr-bundle-comment.sh <run-id> <head-sha>
#
# Runs from .github/workflows/pr-test-bundles.yml on workflow_run, i.e. with
# main's code and a write token, AFTER the untrusted pr-checks run finished. So
# nothing the PR controls is executed or trusted here:
#
#   - The PR number comes from the artifact name (flatpak-bundles-<arch>-pr<N>),
#     which the PR's own workflow file could forge. It is only used once the PR
#     it names is open and its head commit is the commit the run built.
#   - App ids come from the .flatpak names inside the artifacts and must look
#     like app ids before they reach the comment.
#
# One comment per PR, found again by a hidden marker and rewritten on every
# run, so each push updates it instead of adding another.
#
# Env: GH_TOKEN, GITHUB_REPOSITORY. PR_BUNDLE_DRY_RUN=1 prints the comment
# instead of posting it (used by the tests).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
need gh; need jq; need unzip

run_id="${1:?usage: pr-bundle-comment.sh <run-id> <head-sha>}"
head_sha="${2:?usage: pr-bundle-comment.sh <run-id> <head-sha>}"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
marker='<!-- flatpark:test-bundles -->'

artifacts="$(gh api "repos/$repo/actions/runs/$run_id/artifacts" --paginate \
    --jq '.artifacts[] | select(.expired | not) | select(.name | test("^flatpak-bundles-(x86_64|aarch64)-pr[0-9]+$")) | [.id, .name, .expires_at] | @tsv')"
[ -n "$artifacts" ] || { log "run $run_id uploaded no bundles; nothing to post"; exit 0; }

pr="$(printf '%s\n' "$artifacts" | sed -n 's/.*-pr\([0-9]*\)\t.*/\1/p' | sort -u)"
[ "$(printf '%s\n' "$pr" | wc -l)" -eq 1 ] || die "run $run_id names more than one PR: $(echo $pr)"

pr_json="$(gh api "repos/$repo/pulls/$pr")"
[ "$(jq -r .state <<<"$pr_json")" = open ] || { log "PR #$pr is not open; not commenting"; exit 0; }
[ "$(jq -r .head.sha <<<"$pr_json")" = "$head_sha" ] \
    || { log "PR #$pr head is not $head_sha (a newer push, or a forged name); not commenting"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
rows=""
ids=()
expires=""
while IFS=$'\t' read -r id name exp; do
    arch="${name#flatpak-bundles-}"; arch="${arch%-pr*}"
    gh api "repos/$repo/actions/artifacts/$id/zip" > "$tmp/$id.zip"
    apps=()
    while read -r f; do
        app="${f%.flatpak}"
        [[ "$app" =~ ^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+){2,}$ ]] || continue
        apps+=("$app")
    done < <(unzip -Z1 "$tmp/$id.zip" | sed -n 's#^\([^/]*\.flatpak\)$#\1#p')
    [ "${#apps[@]}" -gt 0 ] || continue
    ids+=("${apps[@]}")
    rows+="| $arch | [$name](https://github.com/$repo/actions/runs/$run_id/artifacts/$id) | $(printf '`%s` ' "${apps[@]}")|"$'\n'
    expires="${exp%%T*}"
done <<<"$artifacts"
[ -n "$rows" ] || { log "no app bundles inside run $run_id's artifacts"; exit 0; }
mapfile -t ids < <(printf '%s\n' "${ids[@]}" | sort -u)

install_lines="$(for a in "${ids[@]}"; do printf 'flatpak install --user ./%s.flatpak\n' "$a"; done)"
run_lines="$(for a in "${ids[@]}"; do printf 'flatpak run %s\n' "$a"; done)"
uninstall_line="flatpak uninstall --user $(echo "${ids[@]}")"

body="$marker
### Test this build

Installable bundles of the apps this PR changes, built from ${head_sha:0:7} in [this run](https://github.com/$repo/actions/runs/$run_id). Downloading needs a GitHub login, and the links expire on $expires.

| Arch | Download | Apps |
|---|---|---|
$rows
Unzip the download for your machine's architecture, then:

\`\`\`
$install_lines
$run_lines
\`\`\`

The app's files are fetched from upstream during install, so it needs a network connection. If you already have this app from FlatPark, uninstall that first. A bundle is a one-off copy that never updates; when you're done testing, remove it with \`$uninstall_line\` and install from FlatPark once the PR is live.

This comment is updated on every push."

if [ "${PR_BUNDLE_DRY_RUN:-0}" = 1 ]; then
    printf '%s\n' "$body"
    exit 0
fi

existing="$(gh api "repos/$repo/issues/$pr/comments" --paginate \
    --jq ".[] | select(.user.login == \"github-actions[bot]\") | select(.body | startswith(\"$marker\")) | .id" | head -n1)"
if [ -n "$existing" ]; then
    gh api -X PATCH "repos/$repo/issues/comments/$existing" -f body="$body" >/dev/null
    log "updated the test-bundle comment on PR #$pr"
else
    gh api -X POST "repos/$repo/issues/$pr/comments" -f body="$body" >/dev/null
    log "posted the test-bundle comment on PR #$pr"
fi
