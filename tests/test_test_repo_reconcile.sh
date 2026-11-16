#!/usr/bin/env bash
# test-repo-reconcile.sh and test-repo-plan.sh decisions, one PR at a time,
# against a stub gh, rclone's local backend as the bucket, and a stub flatpak
# that records what it was asked to do (the real thing runs in the container
# e2e, tests/test-repo/run.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for c in jq python3 rclone ostree gpg; do
    command -v "$c" >/dev/null 2>&1 || { echo "test_test_repo_reconcile: SKIP (no $c)"; exit 0; }
done
fail() { echo "FAIL: $*"; exit 1; }
tmp="$(mktemp -d)"
trap 'GNUPGHOME="$tmp/key" gpgconf --kill all >/dev/null 2>&1; rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/bucket/pr" "$tmp/gh/repos/o/r/pulls" "$tmp/gh/repos/o/r/actions/workflows/pr-checks.yml"
G="$tmp/gh/repos/o/r"
ln -s "$ROOT/tests/lib/gh-stub.sh" "$tmp/bin/gh"
cat > "$tmp/bin/flatpak" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_FX/flatpak-calls"
case "$1" in build-update-repo) repo="${!#}"; : > "$repo/summary"; : > "$repo/summary.sig" ;; esac
EOF
chmod +x "$tmp/bin/flatpak"

mkdir -m700 "$tmp/key"
GNUPGHOME="$tmp/key" gpg -q --batch --passphrase '' --quick-generate-key "t <t@example.org>" ed25519 sign never 2>/dev/null
GNUPGHOME="$tmp/key" gpg --armor --export > "$tmp/testing.pub.asc" 2>/dev/null
export FLATPAK_TESTING_GPG_KEY; FLATPAK_TESTING_GPG_KEY="$(GNUPGHOME="$tmp/key" gpg --armor --export-secret-keys 2>/dev/null)"
export PATH="$tmp/bin:$PATH" GH_FX="$tmp/gh" GITHUB_REPOSITORY=o/r TEST_REPO_DRY_RUN=1 \
    RCLONE_CONFIG_R2_TYPE=local TEST_REPO_BUCKET="$tmp/bucket" TEST_REPO_PUBKEY="$tmp/testing.pub.asc" \
    RCLONE_CONFIG="$tmp/rclone.conf"
: > "$tmp/rclone.conf"
H=1111111111111111111111111111111111111111

pr() { # <n> <state> <merged> <labeled 0/1> [head]
    local labels='[]'; [ "$4" = 1 ] && labels='[{"name":"needs-testers"}]'
    jq -n --arg s "$2" --argjson m "$3" --argjson l "$labels" --arg h "${5:-$H}" \
        '{state: $s, merged: $m, labels: $l, head: {sha: $h}}' > "$G/pulls/$1.json"
    mkdir -p "$G/pulls/$1"; echo "[{\"filename\":\"registry/io.example.App$1/flatpark.yml\"}]" > "$G/pulls/$1/files.json"
}
prefix() { # <n> [built-from] [retired-days-ago]: a real repo, one app ref
    local p="$tmp/bucket/pr/$1"
    ostree --repo="$p" init --mode=archive-z2
    mkdir -p "$tmp/tree"; echo x > "$tmp/tree/f"
    ostree --repo="$p" commit --branch="app/io.example.App$1/x86_64/stable" --subject=t "$tmp/tree" >/dev/null
    ostree --repo="$p" commit --branch="runtime/io.example.App$1.Locale/x86_64/stable" --subject=t "$tmp/tree" >/dev/null
    rm -rf "$p/tmp" "$p/.lock"
    echo "${2:-$H}" > "$p/built-from"
    [ -z "${3:-}" ] || date -u -d "$3 days ago" +%Y-%m-%dT%H:%M:%SZ > "$p/retired"
}
runs() { echo "{\"workflow_runs\":$1}" > "$G/actions/workflows/pr-checks.yml/runs.json"; }
run_json() { # <id> <status> <conclusion>
    printf '{"id":%s,"head_sha":"%s","event":"pull_request","status":"%s","conclusion":%s,"created_at":"2026-11-16T0%s:00:00Z"}' \
        "$1" "$H" "$2" "$( [ -n "$3" ] && echo "\"$3\"" || echo null)" "${1: -1}"
}
reconcile() { "$ROOT/scripts/test-repo-reconcile.sh" "$@" 2>"$tmp/err"; }
runs '[]'   # no pr-checks run on any head yet
decide() { "$ROOT/scripts/test-repo-reconcile.sh" --decide "$1" 2>/dev/null; }

# Prefix not a PR number -> purge.
mkdir -p "$tmp/bucket/pr/junk"; echo x > "$tmp/bucket/pr/junk/f"
[ "$(decide junk)" = purge ] || fail "non-numeric prefix not purged"
reconcile junk; [ ! -e "$tmp/bucket/pr/junk" ] || fail "pr/junk still there"
reconcile '../x' 2>/dev/null && fail "accepted a prefix name with a path"

# Open + labeled, built from the head -> left alone.
pr 1 open false 1; prefix 1
[ "$(decide 1)" = none ] || fail "live current PR: $(decide 1)"
: > "$GH_FX/calls"; reconcile 1
grep -qv '^GET' "$GH_FX/calls" && fail "touched GitHub for a current repo"
[ -f "$tmp/bucket/pr/1/built-from" ] && [ ! -e "$tmp/bucket/pr/1/retired" ] || fail "pr/1 changed"

# Open + labeled with a retired marker (the label came back) -> publish.
# With no build to publish, that is a gh-only check, not a publish (which is
# what makes the workflow install flatpak).
pr 11 open false 1; prefix 11 "" 1
[ "$(decide 11)" = check ] || fail "relabeled PR without a build: $(decide 11)"

# Closed, unmerged, no marker -> retire with the withdrawn text.
pr 2 closed false 1; prefix 2
[ "$(decide 2)" = retire ] || fail "closed PR: $(decide 2)"
out="$(reconcile 2)" || { cat "$tmp/err"; fail "retire failed"; }
grep -qF -- "--end-of-life=PR #2 test build withdrawn: flatpak uninstall io.example.App2 && flatpak remote-delete flatpark-pr2" "$GH_FX/flatpak-calls" \
    || fail "withdrawn EOL not applied: $(cat "$GH_FX/flatpak-calls")"
[ "$(grep -c -- '--end-of-life=' "$GH_FX/flatpak-calls")" = 2 ] || fail "not every ref (app + Locale) end-of-lifed"
grep -q -- '--gpg-sign=' "$GH_FX/flatpak-calls" || fail "EOL commits not signed"
[ -s "$tmp/bucket/pr/2/retired" ] || fail "no retired marker"
grep -qF 'flatpak uninstall io.example.App2' <<<"$out" || fail "retired comment: $out"
# Labeled but unlabeled-and-open reads the same way.
pr 12 open false 0; prefix 12
[ "$(decide 12)" = retire ] || fail "unlabeled open PR not retired"

# Merged -> the merged text.
: > "$GH_FX/flatpak-calls"
pr 3 closed true 1; prefix 3
reconcile 3 >/dev/null || { cat "$tmp/err"; fail "retire (merged) failed"; }
grep -qF -- "--end-of-life=PR #3 merged; switch to the released build: flatpak install --reinstall flatpark io.example.App3 && flatpak remote-delete flatpark-pr3" "$GH_FX/flatpak-calls" \
    || fail "merged EOL not applied: $(cat "$GH_FX/flatpak-calls")"

# Marker 15 days old -> purge; 1 day old -> untouched.
pr 4 closed false 0; prefix 4 "" 15
[ "$(decide 4)" = purge ] || fail "old marker: $(decide 4)"
reconcile 4; [ ! -e "$tmp/bucket/pr/4" ] || fail "pr/4 not purged"
pr 5 closed true 0; prefix 5 "" 1
[ "$(decide 5)" = none ] || fail "fresh marker: $(decide 5)"
reconcile 5; [ -f "$tmp/bucket/pr/5/retired" ] || fail "pr/5 touched"
# A PR that no longer exists reads as closed, unmerged.
prefix 13
[ "$(decide 13)" = retire ] || fail "missing PR: $(decide 13)"

# Open + labeled, no repo: the newest run on the head decides.
pr 6 open false 1
out="$(reconcile 6)"; grep -qF 'has not run on this commit' <<<"$out" || fail "no comment without a run: $out"
[ "$(decide 6)" = check ] || fail "no run: $(decide 6)"
runs "[$(run_json 61 in_progress "")]"
[ "$(decide 6)" = none ] || fail "run in progress: $(decide 6)"
: > "$GH_FX/calls"; out="$(reconcile 6)"
if [ -n "$out" ] || grep -q '^POST' "$GH_FX/calls"; then fail "acted on a run in progress"; fi
runs "[$(run_json 62 completed failure)]"
[ "$(decide 6)" = check ] || fail "failed run: $(decide 6)"
out="$(reconcile 6)"; grep -qF 'did not pass' <<<"$out" || fail "no comment for a failed run: $out"
# Comment once: the same state does not edit the comment again.
TEST_REPO_DRY_RUN=0 reconcile 6 >/dev/null
: > "$GH_FX/calls"; TEST_REPO_DRY_RUN=0 reconcile 6 >/dev/null
grep -qE '^(POST|PATCH)' "$GH_FX/calls" && fail "commented twice on the same failed run"
# Success with expired artifacts -> a check: re-run it and say so.
runs "[$(run_json 62 completed failure),$(run_json 63 completed success)]"
mkdir -p "$G/actions/runs/63"
echo '{"artifacts":[{"id":9,"name":"flatpak-repo-x86_64-pr6","expired":true}]}' > "$G/actions/runs/63/artifacts.json"
[ "$(decide 6)" = check ] || fail "expired artifacts: $(decide 6)"
: > "$GH_FX/calls"; out="$(reconcile 6)" || fail "rerun path failed"
grep -q '^POST repos/o/r/actions/runs/63/rerun' "$GH_FX/calls" || fail "expired artifacts not rebuilt"
if ! grep -qF 'expired' <<<"$out" || ! grep -qF 'pr-checks is running again' <<<"$out"; then fail "rebuilding comment: $out"; fi
# The run can't be re-run (too old, or refused): say how to rebuild, exit 0.
touch "$GH_FX/rerun-refused"
out="$(reconcile 6)" || { cat "$tmp/err"; fail "a refused re-run failed the job"; }
grep -qF "can't be re-run; push a commit or re-run pr-checks to rebuild" <<<"$out" || fail "no fallback comment: $out"
grep -q 'could not re-run run 63' "$tmp/err" || fail "refused re-run not logged"
rm "$GH_FX/rerun-refused"
# A PR that changes no app is never re-run.
echo '[{"filename":"docs/x.md"}]' > "$G/pulls/6/files.json"
: > "$GH_FX/calls"; out="$(reconcile 6)"
grep -q 'rerun' "$GH_FX/calls" && fail "re-ran pr-checks for a PR that changes no app"
grep -qF 'changes no app' <<<"$out" || fail "no-app comment: $out"
echo '[{"filename":"registry/io.example.App6/flatpark.yml"}]' > "$G/pulls/6/files.json"
# An artifact named for another PR is never used: still a check, no download.
echo '{"artifacts":[{"id":9,"name":"flatpak-repo-x86_64-pr66","expired":false}]}' > "$G/actions/runs/63/artifacts.json"
[ "$(decide 6)" = check ] || fail "another PR's artifact counted as a build"
: > "$GH_FX/calls"; reconcile 6 >/dev/null
grep -q 'artifacts/9/zip' "$GH_FX/calls" && fail "downloaded another PR's artifact"
# An unexpired artifact of this PR is the only thing that makes it a publish.
echo '{"artifacts":[{"id":9,"name":"flatpak-repo-x86_64-pr6","expired":false}]}' > "$G/actions/runs/63/artifacts.json"
[ "$(decide 6)" = publish ] || fail "ready build: $(decide 6)"
# A publish decided after the job's toolchain step (no flatpak here) waits for
# the next run instead of failing.
mkdir -p "$tmp/noflatpak"
for c in gh jq rclone python3 gpg base64 tar sed awk grep sort head tail cut tr date mktemp rm mkdir cat env bash dirname wc find gpgconf; do
    p="$(command -v "$c")" && ln -sf "$p" "$tmp/noflatpak/$c"
done
: > "$GH_FX/calls"; PATH="$tmp/noflatpak" reconcile 6 >/dev/null || { cat "$tmp/err"; fail "publish without flatpak failed the job"; }
grep -q 'flatpak/ostree are not installed' "$tmp/err" || fail "missing toolchain not reported: $(cat "$tmp/err")"
grep -q 'artifacts/9/zip' "$GH_FX/calls" && fail "downloaded without a toolchain to publish with"
echo '{"artifacts":[{"id":9,"name":"flatpak-repo-x86_64-pr66","expired":false}]}' > "$G/actions/runs/63/artifacts.json"

# The sweep plans exactly the PRs that need action.
echo '[{"number":6,"labels":[{"name":"needs-testers"}]},{"number":1,"labels":[{"name":"needs-testers"}]},{"number":98,"labels":[{"name":"bug"}]}]' > "$G/pulls.json"
plan="$("$ROOT/scripts/test-repo-plan.sh" sweep 2>/dev/null)"
[ "$plan" = '["11","12","13","6"]' ] || fail "sweep plan: $plan"
# A finished run names its PR only when that PR is open at the run's commit.
mkdir -p "$G/actions/runs/70"
echo '{"artifacts":[{"name":"flatpak-repo-x86_64-pr6"},{"name":"flatpak-repo-aarch64-pr6"}]}' > "$G/actions/runs/70/artifacts.json"
[ "$("$ROOT/scripts/test-repo-plan.sh" run 70 "$H" 2>/dev/null)" = '["6"]' ] || fail "run plan"
[ "$("$ROOT/scripts/test-repo-plan.sh" run 70 2222222222222222222222222222222222222222 2>/dev/null)" = '[]' ] \
    || fail "run plan trusted a run that is not the PR head"
echo '{"artifacts":[{"name":"flatpak-repo-x86_64-pr6"},{"name":"flatpak-repo-x86_64-pr2"}]}' > "$G/actions/runs/70/artifacts.json"
"$ROOT/scripts/test-repo-plan.sh" run 70 "$H" >/dev/null 2>&1 && fail "run plan accepted two PR numbers"

echo "test_test_repo_reconcile: PASS"
