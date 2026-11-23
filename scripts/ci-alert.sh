#!/usr/bin/env bash
# Turn a CI failure into something that reaches a human.
#
# Nothing else in the pipeline notifies: a held-back pin or a failed publish is
# only a red run in the Actions tab, and GitHub emails those out for *scheduled*
# runs alone — a workflow_dispatch or a push-triggered publish that dies after
# an auto-merge tells nobody. This opens a labelled issue instead, and closes it
# again once the same key succeeds.
#
# `sync` is for an alert that stands for a batch rather than one thing: it is
# still one issue per key, but a repeat rewrites the title and body so the
# issue always shows the latest run's list instead of the first one's.
#
# Deduped by a hidden marker in the issue body rather than by title, so an issue
# someone renamed is still found, and re-titling one never opens a second. A
# repeat failure is deliberately quiet: a daily job that keeps failing keeps ONE
# open issue and does not comment on every run.
#
# Usage:
#   ci-alert.sh open    <key> <title> [body-file]   # body on stdin if omitted
#   ci-alert.sh sync    <key> <title> [body-file]   # open, or rewrite the open one
#   ci-alert.sh resolve <key> [comment]
#   ci-alert.sh drop-row <key> <id> <title-format> [comment]
#                                                   # batch alert: drop one row
#   ci-alert.sh list    [key-prefix]                # keys with an open alert
#
# Needs GH_TOKEN (or GITHUB_TOKEN) with issues:write.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib/common.sh"
need gh

LABEL="ci-alert"
# Every bot-opened issue carries this, so they read apart from human-filed
# ones ([Bug], [App Request], ...) in the issue list. Callers pass bare titles.
TITLE_PREFIX="[CI] "

prefixed() {
    case "$1" in
        "$TITLE_PREFIX"*) printf '%s' "$1" ;;
        *) printf '%s%s' "$TITLE_PREFIX" "$1" ;;
    esac
}

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
    gh issue create --title "$(prefixed "$title")" --label "$LABEL" --body "$body" >&2
    log "ci-alert: opened for $key"
}

cmd_sync() {
    local key="$1" title="$2" body_file="${3:-}" body existing url
    [ -n "$key" ] && [ -n "$title" ] || die "usage: ci-alert.sh sync <key> <title> [body-file]"
    if [ -n "$body_file" ]; then
        body="$(cat "$body_file")"
    else
        body="$(cat)"
    fi
    existing="$(find_open "$key")"
    if [ -z "$existing" ]; then
        printf '%s\n' "$body" | cmd_open "$key" "$title"
        return
    fi
    url="$(run_url)"
    [ -z "$url" ] || body="$(printf '%s\n\nLatest run: %s' "$body" "$url")"
    body="$(printf '%s\n\n%s\n' "$body" "$(marker "$key")")"
    gh issue edit "$existing" --title "$(prefixed "$title")" --body "$body" >&2
    log "ci-alert: refreshed #$existing for $key"
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

# A `sync` batch alert lists one thing per markdown table row, keyed by its
# first cell (`| \`<id>\` | ...`). When one of those recovers outside the batch
# job — update-app.yml fixing a single app — drop just its row instead of
# waiting for the next batch run to rewrite the list. <title-format> is the
# batch title with %d for the rows left; none left closes the issue. A batch run
# racing this rewrites the whole body anyway, so the worst case is a row that
# reappears until that run.
cmd_drop_row() {
    local key="$1" id="$2" title_fmt="$3" comment="${4:-}" existing body left n
    [ -n "$key" ] && [ -n "$id" ] && [ -n "$title_fmt" ] \
        || die "usage: ci-alert.sh drop-row <key> <id> <title-format> [comment]"
    existing="$(find_open "$key")"
    [ -n "$existing" ] || return 0
    # CRLF from GitHub: strip it so the row prefix and the counts match.
    body="$(gh issue view "$existing" --json body -q .body | tr -d '\r')"
    left="$(printf '%s\n' "$body" | awk -v row="| \`$id\` |" 'index($0, row) != 1')"
    if [ "$left" = "$body" ]; then
        log "ci-alert: $id is not listed in #$existing"
        return 0
    fi
    n="$(printf '%s\n' "$left" | grep -c '^| `' || true)"
    if [ "$n" = 0 ]; then
        cmd_resolve "$key" "${comment:-\`$id\` recovered, and it was the last one listed.}"
        return
    fi
    # shellcheck disable=SC2059  # the format is the caller's, by design
    gh issue edit "$existing" --title "$(prefixed "$(printf "$title_fmt" "$n")")" --body "$left" >&2
    [ -z "$comment" ] || gh issue comment "$existing" --body "$comment" >&2
    log "ci-alert: dropped $id from #$existing ($n left)"
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
    sync)    shift; cmd_sync "${1:-}" "${2:-}" "${3:-}" ;;
    resolve) shift; cmd_resolve "${1:-}" "${2:-}" ;;
    drop-row) shift; cmd_drop_row "${1:-}" "${2:-}" "${3:-}" "${4:-}" ;;
    list)    shift; cmd_list "${1:-}" ;;
    *) die "usage: ci-alert.sh open|sync|resolve|drop-row|list ..." ;;
esac
