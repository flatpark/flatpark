#!/usr/bin/env bash
# ci-alert.sh must open exactly ONE issue per key no matter how often the
# failure repeats, and close that issue again when the same key succeeds.
# A second issue per red run would be worse than no notification at all.
#
# Hermetic: `gh` is a stand-in backed by a JSON file. The dedupe query is the
# part worth testing, so the stand-in evaluates the real -q expression with jq
# rather than faking the answer.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"

command -v jq >/dev/null || { echo "test_ci_alert: SKIP (no jq)"; exit 0; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export CI_ALERT_TEST_STATE="$tmp/issues.json"
export CI_ALERT_TEST_LOG="$tmp/gh.log"
printf '[]\n' > "$CI_ALERT_TEST_STATE"
: > "$CI_ALERT_TEST_LOG"

mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
state="$CI_ALERT_TEST_STATE"; printf '%s\n' "$*" >> "$CI_ALERT_TEST_LOG"
sub="${1:-} ${2:-}"; shift 2 || true
write() { local f; f="$(mktemp)"; cat > "$f"; mv "$f" "$state"; }
case "$sub" in
  "label create") ;;
  "issue list")
      expr=""
      while [ $# -gt 0 ]; do
          case "$1" in -q|--jq) expr="$2"; shift 2 ;; *) shift ;; esac
      done
      jq '[.[] | select(.state == "open")]' "$state" | jq -r "$expr"
      ;;
  "issue create")
      title=""; body=""
      while [ $# -gt 0 ]; do
          case "$1" in
              --title) title="$2"; shift 2 ;;
              --body)  body="$2";  shift 2 ;;
              *) shift ;;
          esac
      done
      n=$(( $(jq 'length' "$state") + 100 ))
      jq --argjson n "$n" --arg t "$title" --arg b "$body" \
         '. + [{number: $n, title: $t, body: $b, state: "open"}]' "$state" | write
      echo "issue #$n"
      ;;
  "issue close")
      n="$1"
      jq --argjson n "$n" 'map(if .number == $n then .state = "closed" else . end)' "$state" | write
      ;;
  *) echo "unexpected gh call: $sub $*" >&2; exit 1 ;;
esac
GH
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"
export GITHUB_SERVER_URL="https://github.com" GITHUB_REPOSITORY="flatpark/flatpark" GITHUB_RUN_ID="42"

open_count() { jq '[.[] | select(.state == "open")] | length' "$CI_ALERT_TEST_STATE"; }
creates()    { grep -c '^issue create' "$CI_ALERT_TEST_LOG" || true; }

# First failure opens the issue, and it carries a link to the failing run.
printf 'the payload does not unpack\n' \
    | "$ROOT/scripts/ci-alert.sh" open "update-check/com.example.App" "held back: com.example.App" >/dev/null
assert_eq "$(open_count)" "1"
body="$(jq -r '.[0].body' "$CI_ALERT_TEST_STATE")"
case "$body" in
    *"actions/runs/42"*) ;;
    *) echo "FAIL: issue body lacks the run URL"; exit 1 ;;
esac

# Same failure tomorrow, and the day after: still one issue, no new create call.
for _ in 1 2; do
    printf 'the payload still does not unpack\n' \
        | "$ROOT/scripts/ci-alert.sh" open "update-check/com.example.App" "held back: com.example.App" >/dev/null
done
assert_eq "$(open_count)" "1"
assert_eq "$(creates)" "1"

# A different key is a different issue.
printf 'publish died\n' | "$ROOT/scripts/ci-alert.sh" open "publish" "publish failed" >/dev/null
assert_eq "$(open_count)" "2"

# Success closes only the key that recovered.
"$ROOT/scripts/ci-alert.sh" resolve "update-check/com.example.App" >/dev/null
assert_eq "$(open_count)" "1"
assert_eq "$(jq -r '[.[] | select(.state == "open")][0].body | contains("ci-alert:publish")' "$CI_ALERT_TEST_STATE")" "true"

# `list` reports what is still alerting, filtered by key prefix, so a caller
# can re-check exactly the things that have not recovered.
assert_eq "$("$ROOT/scripts/ci-alert.sh" list)" "publish"
assert_eq "$("$ROOT/scripts/ci-alert.sh" list update-check/)" ""

# Resolving a key with nothing open is a no-op, not an error.
"$ROOT/scripts/ci-alert.sh" resolve "update-check/com.example.App" >/dev/null
assert_eq "$(open_count)" "1"
