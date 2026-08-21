#!/usr/bin/env bash
# Turn a CI failure into something that reaches a human.
#
# Nothing else in the pipeline notifies: a held-back pin or a failed publish is
# only a red run in the Actions tab, and GitHub emails those out for *scheduled*
# runs alone — a workflow_dispatch or a push-triggered publish that dies after
# an auto-merge tells nobody. This opens a labelled issue instead, and closes it
# again once the same key succeeds.
#
# Deduped by a hidden marker in the issue body rather than by title, so an issue
# someone renamed is still found, and re-titling one never opens a second. A
# repeat failure is deliberately quiet: a daily job that keeps failing keeps ONE
# open issue and does not comment on every run.
#
# Usage:
#   ci-alert.sh open    <key> <title> [body-file]   # body on stdin if omitted
#   ci-alert.sh resolve <key> [comment]
#   ci-alert.sh list    [key-prefix]                # keys with an open alert
#
# Needs GH_TOKEN (or GITHUB_TOKEN) with issues:write.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
need gh

LABEL="ci-alert"

run_url() {
    [ -n "${GITHUB_RUN_ID:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ] || return 0
    printf '%s/%s/actions/runs/%s\n' \
        "${GITHUB_SERVER_URL:-https://github.com}" "${GITHUB_REPOSITORY:-}" "$GITHUB_RUN_ID"
}

marker() { printf '<!-- ci-alert:%s -->' "$1"; }

# The open issue carrying this key, or nothing. Listed and filtered locally
# rather than via `--search`: the search index lags issue creation by up to a
# minute, long enough for two runs in a row to each open their own copy.
find_open() {
    gh issue list --state open --label "$LABEL" --limit 100 \
        --json number,body -q \
        "map(select(.body != null and (.body | contains(\"$(marker "$1")\")))) | .[0].number // empty"
}

cmd_open() {
    local key="$1" title="$2" body_file="${3:-}" body existing url
    [ -n "$key" ] && [ -n "$title" ] || die "usage: ci-alert.sh open <key> <title> [body-file]"
    if [ -n "$body_file" ]; then
        body="$(cat "$body_file")"
    else
        body="$(cat)"
    fi

    existing="$(find_open "$key")"
    if [ -n "$existing" ]; then
        log "ci-alert: #$existing already open for $key"
        return 0
    fi

    url="$(run_url)"
    [ -z "$url" ] || body="$(printf '%s\n\nFailing run: %s' "$body" "$url")"
    body="$(printf '%s\n\n%s\n' "$body" "$(marker "$key")")"

    # The label has to exist before it can be applied, and a fresh clone of this
    # repo has never created it.
    gh label create "$LABEL" --color B60205 \
        --description "Opened automatically by a failing workflow" >/dev/null 2>&1 || true
    gh issue create --title "$title" --label "$LABEL" --body "$body" >&2
    log "ci-alert: opened for $key"
}

cmd_resolve() {
    local key="$1" comment="${2:-}" existing url
    [ -n "$key" ] || die "usage: ci-alert.sh resolve <key> [comment]"
    existing="$(find_open "$key")"
    [ -n "$existing" ] || return 0
    url="$(run_url)"
    [ -n "$comment" ] || comment="Fixed — this succeeded again."
    [ -z "$url" ] || comment="$(printf '%s\n\nSucceeding run: %s' "$comment" "$url")"
    gh issue close "$existing" --comment "$comment" >&2
    log "ci-alert: closed #$existing for $key"
}

# Keys that currently have an open alert, so a caller can ask whether the
# thing that failed is healthy again. GitHub hands bodies back with CRLF line
# endings, hence the trailing-whitespace trim.
cmd_list() {
    local prefix="${1:-}"
    gh issue list --state open --label "$LABEL" --limit 100 \
        --json body -q '.[].body // ""' \
        | sed -n 's/.*<!-- ci-alert:\([^>]*\) -->.*/\1/p' \
        | sed 's/[[:space:]]*$//' \
        | awk -v p="$prefix" 'p == "" || index($0, p) == 1'
}

case "${1:-}" in
    open)    shift; cmd_open "${1:-}" "${2:-}" "${3:-}" ;;
    resolve) shift; cmd_resolve "${1:-}" "${2:-}" ;;
    list)    shift; cmd_list "${1:-}" ;;
    *) die "usage: ci-alert.sh open|resolve|list ..." ;;
esac
