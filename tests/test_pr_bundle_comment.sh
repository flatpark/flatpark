#!/usr/bin/env bash
# pr-bundle-comment.sh against a stub gh: it comments only on the PR the run
# really built, lists the bundled apps, and updates its own comment in place.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for c in jq unzip python3; do
    command -v "$c" >/dev/null 2>&1 || { echo "test_pr_bundle_comment: SKIP (no $c)"; exit 0; }
done

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/fx"

# One artifact holding two app bundles and a file that is not an app id.
python3 -I -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    for n in ("io.example.One.flatpak", "io.example.Two.flatpak", "evil$(id).flatpak"):
        z.writestr(n, "")' "$tmp/fx/art.zip"

cat > "$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Minimal `gh api` stub driven by files in $FX. Records writes in $FX/calls.
[ "$1" = api ] || exit 1; shift
method=GET
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        -X) method="$2"; shift 2 ;;
        --paginate) shift ;;
        --jq) jq_expr="$2"; shift 2 ;;
        -f) echo "$method ${args[0]} $2" >> "$FX/calls"; shift 2 ;;
        *) args+=("$1"); shift ;;
    esac
done
path="${args[0]}"
out() { if [ -n "${jq_expr:-}" ]; then jq -r "$jq_expr"; else cat; fi; }
case "$method $path" in
    "GET repos/o/r/actions/runs/7/artifacts")
        printf '{"artifacts":[{"id":11,"name":"flatpak-bundles-x86_64-pr%s","expired":false,"expires_at":"2026-10-20T00:00:00Z"}]}' "$PR_IN_NAME" | out ;;
    "GET repos/o/r/pulls/"*)
        printf '{"state":"open","head":{"sha":"abc1234def"}}' | out ;;
    "GET repos/o/r/actions/artifacts/11/zip")
        cat "$FX/art.zip" ;;
    "GET repos/o/r/issues/"*"/comments")
        cat "$FX/comments.json" | out ;;
    "PATCH "*|"POST "*) ;;
    *) echo "unexpected gh call: $method $path" >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" FX="$tmp/fx" GITHUB_REPOSITORY=o/r GH_TOKEN=x
run() { "$ROOT/scripts/pr-bundle-comment.sh" 7 "$1" 2>"$tmp/err"; }

# The body lists exactly the valid app ids, with install commands and the expiry.
export PR_IN_NAME=5
body="$(PR_BUNDLE_DRY_RUN=1 run abc1234def)"
grep -q '^<!-- flatpark:test-bundles -->' <<<"$body" || { echo "FAIL: no marker"; exit 1; }
grep -q 'flatpak install --user ./io.example.One.flatpak' <<<"$body" || { echo "FAIL: no install line"; exit 1; }
grep -q 'io.example.Two' <<<"$body" || { echo "FAIL: second app missing"; exit 1; }
grep -q 'evil' <<<"$body" && { echo "FAIL: a non-app-id file name reached the comment"; exit 1; }
grep -q '2026-10-20' <<<"$body" || { echo "FAIL: expiry missing"; exit 1; }

# A run whose commit is not the PR's head (newer push, or a forged PR number in
# the artifact name) posts nothing.
: > "$FX/calls"; echo '[]' > "$FX/comments.json"
run deadbeef00
[ ! -s "$FX/calls" ] || { echo "FAIL: commented for a commit that is not the PR head"; cat "$FX/calls"; exit 1; }

# First run posts; a run with our comment already there edits it instead.
run abc1234def
grep -q '^POST repos/o/r/issues/5/comments' "$FX/calls" || { echo "FAIL: did not post"; cat "$FX/calls"; exit 1; }
: > "$FX/calls"
echo '[{"id":99,"user":{"login":"github-actions[bot]"},"body":"<!-- flatpark:test-bundles -->\nold"}]' > "$FX/comments.json"
run abc1234def
grep -q '^PATCH repos/o/r/issues/comments/99' "$FX/calls" || { echo "FAIL: did not update in place"; cat "$FX/calls"; exit 1; }
grep -q '^POST' "$FX/calls" && { echo "FAIL: posted a second comment"; exit 1; }

echo "test_pr_bundle_comment: PASS"
