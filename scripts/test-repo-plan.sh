#!/usr/bin/env bash
# Decide which PRs' test repositories need a test-repo-reconcile.sh run, as a
# JSON array of prefix names for the pr-test-repo workflow's matrix (#585).
# Plans only: it never publishes, retires or purges anything itself.
#
#   test-repo-plan.sh run <run-id> <head-sha>   the PR a finished pr-checks run built
#   test-repo-plan.sh pr <N>                    PR N (label/close events, dispatch)
#   test-repo-plan.sh sweep                     every prefix in the bucket and every
#                                               open labeled PR whose state needs action
#
# `run` and `pr` read GitHub only and need no secrets. `run` takes the PR
# number from the run's artifact names (flatpak-repo-<arch>-pr<N>), which the
# PR's own workflow could forge, so it names a PR only when that PR is open
# and its head is the commit the run built.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
. "$ROOT/scripts/lib/test-repo.sh"
need gh; need jq

json() { jq -cnR '[inputs | select(length > 0)]'; }

cmd="${1:?usage: test-repo-plan.sh run <run-id> <head-sha> | pr <N> | sweep}"
shift
tr_init
case "$cmd" in
run)
    run_id="${1:?run-id}"; head="${2:?head-sha}"
    [[ "$run_id" =~ ^[0-9]+$ ]] || die "not a run id: $run_id"
    names="$(gh api "repos/$TR_REPO/actions/runs/$run_id/artifacts?per_page=100" --paginate \
        --jq '.artifacts[] | select(.name | test("^flatpak-repo-(x86_64|aarch64)-pr[0-9]+$")) | .name')" \
        || die "could not list the artifacts of run $run_id"
    prs="$(sed -n 's/.*-pr\([0-9]*\)$/\1/p' <<<"$names" | sort -u)"
    if [ -z "$prs" ]; then
        log "run $run_id uploaded no flatpak-repo artifact"; json </dev/null; exit 0
    fi
    [ "$(wc -l <<<"$prs")" -eq 1 ] || die "run $run_id names more than one PR: ${prs//$'\n'/ }"
    tr_is_pr_number "$prs" || die "not a PR number: $prs"
    tr_pr_load "$prs"
    if [ "$(jq -r .state <<<"$TR_PR_JSON")" != open ] || [ "$(tr_pr_head)" != "$head" ]; then
        log "PR #$prs is not open at $head (a newer push, or a forged name); nothing to do"
        json </dev/null; exit 0
    fi
    # Only a labeled PR has a repo to keep current. One that lost the label
    # was retired by its unlabeled event (or the sweep), not by its builds.
    if ! tr_pr_live; then
        log "PR #$prs is not labeled $TR_LABEL; nothing to do"
        json </dev/null; exit 0
    fi
    printf '%s\n' "$prs" | json ;;
pr)
    tr_is_pr_number "${1:-}" || die "not a PR number: ${1:-}"
    printf '%s\n' "$1" | json ;;
sweep)
    need rclone
    prefixes="$(rclone lsf "$TR_DEST/pr/" --dirs-only 2>"$TR_TMP/err")" || {
        # An empty bucket has no pr/ yet; any other failure must not pass as "nothing".
        grep -qi 'directory not found' "$TR_TMP/err" || { cat "$TR_TMP/err" >&2; die "could not list $TR_DEST/pr/"; }
        prefixes=""
    }
    # The pulls list, not issues?labels=: that needs an issues permission the
    # workflow does not grant.
    labeled="$(gh api "repos/$TR_REPO/pulls?state=open&per_page=100" --paginate \
        --jq ".[] | select(any(.labels[]?; .name == \"$TR_LABEL\")) | .number")" || die "could not list the labeled PRs"
    { printf '%s\n' "$prefixes" | sed 's#/$##'; printf '%s\n' "$labeled"; } | sed '/^$/d' | sort -u \
    | while IFS= read -r n; do
        if ! tr_is_pr_number "$n"; then
            log "pr/$n: purge (not a PR number)"; printf '%s\n' "$n"; continue
        fi
        tr_pr_load "$n"
        tr_prefix_load "$n"
        tr_decide "$n"
        log "pr/$n: $TR_ACTION ($TR_REASON)"
        # A live PR with no successful build is planned every hour; its leg
        # only re-checks (and comments once), which is cheap.
        [ "$TR_ACTION" = none ] || printf '%s\n' "$n"
    done | json ;;
*) die "unknown command: $cmd" ;;
esac
