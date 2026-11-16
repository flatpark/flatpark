#!/usr/bin/env bash
# Bring one PR's test repository, pr/<N>/, in line with the PR (#585).
#
#   test-repo-reconcile.sh <N>            decide and act
#   test-repo-reconcile.sh --decide <N>   print the action only:
#                                         none|publish|check|retire|purge
#
# The rule: pr/<N>/ is live iff PR N is open and labeled needs-testers. Every
# trigger (pr-checks finishing, a label change, the hourly sweep) ends here
# with one PR number, and this decides from the current state alone, so a
# missed or disabled trigger is caught up by the next one:
#
#   open + labeled, and pr/<N>/ missing, retired, or built from another sha,
#   looking at the newest pr-checks run on the head sha:
#       a run in progress -> nothing (its completion triggers this again)
#       a success with unexpired artifacts -> publish (needs flatpak, ostree)
#       otherwise -> check (gh only): artifacts expired -> re-run it and say
#          so (or, if it can't be re-run, say how to rebuild); no run, or none
#          passed -> say so, once.
#   otherwise, pr/<N>/ has no `retired` marker
#       -> retire: end-of-life every ref, re-sign, write `retired`, comment.
#   otherwise, marked retired more than TEST_REPO_RETIRE_DAYS ago -> purge.
#
# <N> may also be a prefix name that is not a PR number (the sweep found it in
# the bucket): that prefix is purged.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
. "$ROOT/scripts/lib/test-repo.sh"
need gh; need jq; need rclone

decide_only=0
[ "${1:-}" = --decide ] && { decide_only=1; shift; }
n="${1:?usage: test-repo-reconcile.sh [--decide] <pr-number>}"
tr_init

if tr_is_pr_number "$n"; then
    tr_pr_load "$n"
    tr_prefix_load "$n"
    tr_decide "$n"
else
    [[ "$n" =~ ^[A-Za-z0-9._-]+$ ]] && [ "$n" != . ] && [ "$n" != .. ] \
        || die "refusing to touch prefix pr/$n"
    TR_ACTION=purge TR_REASON="not a PR number"
fi
log "pr/$n: $TR_ACTION ($TR_REASON)"
if [ "$decide_only" = 1 ]; then
    echo "$TR_ACTION"
    exit 0
fi
# The workflow installs flatpak only when --decide said publish or retire. If
# the state moved into one of those since, leave it to the next run (the
# finished pr-checks run that made a build ready triggers one).
case "$TR_ACTION" in
    publish|retire)
        if ! command -v flatpak >/dev/null 2>&1 || ! command -v ostree >/dev/null 2>&1; then
            warn "pr/$n needs $TR_ACTION, but flatpak/ostree are not installed in this job; leaving it to the next run"
            exit 0
        fi ;;
esac

# A state comment for a PR that has no live repo; a live (older) build keeps
# its comment, which still describes what the repo serves.
comment_if_no_repo() {
    if [ "$TR_PFX_EXISTS" = 1 ] && [ -z "$TR_PFX_RETIRED" ]; then
        log "pr/$n still serves ${TR_PFX_BUILT:-an older build}; its comment stays"
        return 0
    fi
    tr_put_comment "$n" "$1"
}

publish() {
    local head art_id name dirs=()
    head="$(tr_pr_head)"
    while IFS=$'\t' read -r art_id name; do
        gh api "repos/$TR_REPO/actions/artifacts/$art_id/zip" > "$TR_TMP/$name.zip" \
            || die "could not download artifact $name"
        tr_unpack_artifact_zip "$TR_TMP/$name.zip" "$TR_TMP/art/$name"
        dirs+=("$TR_TMP/art/$name")
    done <<<"$TR_ARTS"
    TEST_REPO_HEAD_SHA="$head" TEST_REPO_RUN_ID="$TR_RUN_ID" \
        "$ROOT/scripts/test-repo-publish.sh" "$n" "${dirs[@]}"
}

# Nothing to publish for the head: re-run an expired build, or say why there
# is none.
check() {
    local head ids run_url
    head="$(tr_pr_head)"
    run_url="https://github.com/$TR_REPO/actions/runs/$TR_RUN_ID"
    case "$TR_BUILD" in
        norun)
            comment_if_no_repo "$(tr_body_nobuild "$n" "$head" "pr-checks has not run on this commit.")" ;;
        failed)
            comment_if_no_repo "$(tr_body_nobuild "$n" "$head" \
                "[pr-checks]($run_url) did not pass on this commit (\`$TR_RUN_CONCL\`).")" ;;
        expired)
            ids="$(tr_pr_app_ids "$n")"
            if [ -z "$ids" ]; then
                comment_if_no_repo "$(tr_body_nobuild "$n" "$head" "this PR changes no app, so there is nothing to install.")"
            elif gh api -X POST "repos/$TR_REPO/actions/runs/$TR_RUN_ID/rerun" >/dev/null 2>"$TR_TMP/rerun-err"; then
                log "artifacts of run $TR_RUN_ID are gone; re-running it"
                comment_if_no_repo "$(tr_body_rebuilding "$n" "$head" "$TR_RUN_ID")"
            else
                # Too old to re-run (GitHub allows about 30 days), or refused:
                # say how to rebuild instead of failing every hour.
                warn "could not re-run run $TR_RUN_ID: $(head -c 300 "$TR_TMP/rerun-err")"
                comment_if_no_repo "$(tr_body_nobuild "$n" "$head" \
                    "the build's artifacts expired and [pr-checks]($run_url) can't be re-run; push a commit or re-run pr-checks to rebuild.")"
            fi ;;
        *) die "check: unexpected build state '$TR_BUILD'" ;;
    esac
}

retire() {
    local reason="$TR_REASON" repo="$TR_TMP/repo" refs ref id at
    need ostree; need flatpak; need gpg
    # Over rclone, not HTTPS: nothing cached. The bucket keeps no empty
    # directories, which ostree needs.
    rclone copy "$TR_DEST/pr/$n" "$repo" --fast-list --transfers=16 --checkers=32
    mkdir -p "$repo/refs/heads" "$repo/refs/remotes" "$repo/refs/mirrors" "$repo/tmp" "$repo/objects"
    mapfile -t refs < <(ostree --repo="$repo" refs | grep -E '^(app|runtime)/' | sort)
    [ "${#refs[@]}" -gt 0 ] || die "pr/$n holds no app or runtime ref"
    tr_import_testing_key
    local sign; signing_args sign
    for ref in "${refs[@]}"; do
        id="$(tr_ref_id "$ref")"
        flatpak build-commit-from --force --no-update-summary --src-ref="$ref" \
            --end-of-life="$(tr_eol_message "$reason" "$n" "$id")" \
            "${sign[@]}" "$repo" "$ref" >/dev/null
        log "end-of-lifed $ref"
    done
    tr_update_repo "$repo" "$n"
    at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' "$at" > "$repo/retired"
    # Labeled again while this ran: leave the repo live for the next publish.
    tr_pr_load "$n"
    if tr_pr_live; then
        log "PR #$n is open and labeled again; not retiring"
        return 0
    fi
    tr_upload "$repo" "$n" retire
    mapfile -t ids < <(printf '%s\n' "${refs[@]}" | tr_id_arch_table | cut -f1)
    tr_put_comment "$n" "$(tr_body_retired "$reason" "$n" "$at" "${ids[@]}")"
    log "retired pr/$n ($reason)"
}

case "$TR_ACTION" in
    none) ;;
    publish) publish ;;
    check) check ;;
    retire) retire ;;
    purge)
        rclone purge "$TR_DEST/pr/$n"
        log "purged pr/$n" ;;
esac
