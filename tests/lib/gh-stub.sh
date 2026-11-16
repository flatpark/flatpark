#!/usr/bin/env bash
# A file-backed stand-in for `gh api`, for the test-repo tests (unit and e2e).
# Link it into PATH as `gh`. State lives under $GH_FX, laid out like the API:
#
#   GET <path>[?query]  -> $GH_FX/<path>.json (query ignored), through --jq if given;
#                          .../zip -> the raw file $GH_FX/<path>; missing -> HTTP 404
#                          (a missing .../comments list reads as []).
#   POST .../issues/<N>/comments -f body=..   appends to that list (as github-actions[bot])
#   PATCH .../issues/comments/<id> -f body=.. edits it wherever it is
#   POST .../rerun                            accepted; refused (HTTP 403) when
#                                             $GH_FX/rerun-refused exists
#
# Every call is appended to $GH_FX/calls as "<METHOD> <path>".
set -uo pipefail
[ "${1:-}" = api ] || { echo "gh stub: only 'gh api' is supported" >&2; exit 2; }
shift
method=GET jq_expr="" body="" path=""
while [ $# -gt 0 ]; do
    case "$1" in
        -X) method="$2"; shift 2 ;;
        --paginate) shift ;;
        --jq) jq_expr="$2"; shift 2 ;;
        -f) case "$2" in body=*) body="${2#body=}" ;; esac; shift 2 ;;
        *) path="$1"; shift ;;
    esac
done
: "${GH_FX:?GH_FX is not set}"
echo "$method $path" >> "$GH_FX/calls"
p="${path%%\?*}"
out() { if [ -n "$jq_expr" ]; then jq -r "$jq_expr"; else cat; fi; }

case "$method $p" in
    "GET "*/zip)
        [ -f "$GH_FX/$p" ] || { echo '{"message":"Not Found"}'; echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
        cat "$GH_FX/$p" ;;
    "GET "*)
        f="$GH_FX/$p.json"
        if [ ! -f "$f" ]; then
            case "$p" in */comments) echo '[]' | out; exit 0 ;; esac
            echo '{"message":"Not Found"}'; echo "gh: Not Found (HTTP 404)" >&2; exit 1
        fi
        out < "$f" ;;
    "POST "*/issues/*/comments)
        f="$GH_FX/$p.json"; mkdir -p "$(dirname "$f")"; [ -f "$f" ] || echo '[]' > "$f"
        id=$(( $(jq '[.[].id] | max // 1000' "$f") + 1 ))
        jq --argjson id "$id" --arg b "$body" '. + [{id: $id, user: {login: "github-actions[bot]"}, body: $b}]' "$f" > "$f.new" && mv "$f.new" "$f"
        echo "{\"id\":$id}" ;;
    "PATCH "*/issues/comments/*)
        id="${p##*/}"
        while IFS= read -r f; do
            jq --argjson id "$id" --arg b "$body" 'map(if .id == $id then .body = $b else . end)' "$f" > "$f.new" && mv "$f.new" "$f"
        done < <(find "$GH_FX" -name comments.json)
        echo '{}' ;;
    "POST "*/rerun)
        if [ -e "$GH_FX/rerun-refused" ]; then
            echo '{"message":"Unable to retry this workflow run because it was created over a month ago"}'
            echo "gh: Unable to retry this workflow run because it was created over a month ago (HTTP 403)" >&2
            exit 1
        fi
        echo '{}' ;;
    *) echo "gh stub: unexpected call: $method $path" >&2; exit 1 ;;
esac
