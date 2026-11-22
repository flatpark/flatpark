#!/usr/bin/env bash
# Delete finished GitHub Actions runs (their logs and artifacts go with them),
# so the Actions tab and artifact storage only hold what is still in play.
#
#   prune-actions-runs.sh            delete
#   DRY_RUN=1 prune-actions-runs.sh  list what would be deleted
#
# Kept:
#   - every run that is not finished: queued, in progress, waiting on a
#     deployment approval (status != completed);
#   - every run waiting for a maintainer to approve a fork PR
#     (conclusion action_required — deleting it would lose the approval
#     prompt, and approve-ci looks these up);
#   - pr-checks runs on the current head of an open PR: test-repo-reconcile.sh
#     reads that run's artifacts (or re-runs it when they expire) to build
#     pr/<N>/, and without it would report "pr-checks has not run on this
#     commit". Reviewers keep the PR's check results too.
# Everything else is deleted, including this run's own predecessors.
#
# The GITHUB_TOKEN gets about 1000 API calls an hour, one per delete. On a
# rate-limit refusal this stops cleanly; the rest goes next time.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
need gh; need jq

repo="${GH_REPO:-${GITHUB_REPOSITORY:-}}"
[ -n "$repo" ] || repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)" \
    || die "cannot tell which repository to prune; set GH_REPO"
dry="${DRY_RUN:-0}"

# Head shas of open PRs, as a jq object for the keep test.
open_heads="$(gh api "repos/$repo/pulls?state=open&per_page=100" --paginate \
    --jq '.[].head.sha' | jq -Rn '[inputs | {(.): true}] | add // {}')" \
    || die "could not list open PRs"

candidates="$(gh api "repos/$repo/actions/runs?per_page=100" --paginate \
    --jq '.workflow_runs[] | [.id, .status, (.conclusion // ""), .path, .event, .head_sha, .name, .created_at] | @tsv')" \
    || die "could not list workflow runs"

deleted=0 kept=0 failed=0
while IFS=$'\t' read -r id status concl path event sha name created; do
    [ -n "$id" ] || continue
    if [ "$status" != completed ] || [ "$concl" = action_required ]; then
        kept=$((kept + 1)); continue
    fi
    if [ "${path##*/}" = pr-checks.yml ] && [ "$event" = pull_request ] \
        && jq -e --arg s "$sha" '.[$s]' <<<"$open_heads" >/dev/null; then
        kept=$((kept + 1)); continue
    fi
    if [ "$dry" = 1 ]; then
        log "would delete $id  $name  $concl  $created"
        deleted=$((deleted + 1)); continue
    fi
    if err="$(gh api -X DELETE "repos/$repo/actions/runs/$id" 2>&1 >/dev/null)"; then
        deleted=$((deleted + 1))
    elif grep -qi 'rate limit' <<<"$err"; then
        warn "rate limited after $deleted deletes; the rest waits for the next run"
        break
    else
        # Gone already (a parallel delete) or refused: not worth failing over.
        warn "could not delete run $id ($name): $(head -c 200 <<<"$err")"
        failed=$((failed + 1))
    fi
done <<<"$candidates"

verb=deleted; [ "$dry" = 1 ] && verb="to delete (dry run)"
log "runs $verb: $deleted, kept: $kept, failed: $failed"
