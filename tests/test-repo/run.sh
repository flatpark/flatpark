#!/bin/bash
# Per-PR test repository e2e (#585): the real scripts/test-repo-*.sh publish a
# PR's pr-checks artifact to a bucket (rclone's local backend) served over
# HTTP, and a client installs from it, then the PR merges and the repo is
# retired and purged. Needs podman (the client runs privileged: apply_extra
# runs under bubblewrap) and network access for the images. Nothing runs
# flatpak on the host.
#
#   tests/test-repo/run.sh
#
# SERVER_BASE is the GitHub runner's distro (ubuntu-26.04); CLIENT_BASE a
# tester's.
set -uo pipefail
K=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$K/../.." && pwd)
SERVER_BASE=${SERVER_BASE:-docker.io/library/ubuntu:26.04}
CLIENT_BASE=${CLIENT_BASE:-docker.io/library/debian:trixie}
fails=0; mkdir -p "$ROOT/out"; log=$ROOT/out/test-repo-e2e.log; : > "$log"
img() { local t; t=localhost/test-repo-e2e:$(echo "${1##*/}" | tr -c 'a-z0-9\n' '-'); podman build -q --build-arg BASE="$1" -t "$t" "$K" >/dev/null && echo "$t"; }
cleanup() { podman rm -f -t0 test-repo-srv test-repo-client >/dev/null 2>&1; podman volume rm -f test-repo-srv >/dev/null 2>&1; }
trap cleanup EXIT; cleanup
S=$(img "$SERVER_BASE") || { echo "image build failed: $SERVER_BASE"; exit 1; }
C=$(img "$CLIENT_BASE") || { echo "image build failed: $CLIENT_BASE"; exit 1; }
podman volume create test-repo-srv >/dev/null
srv() { podman run --rm --network host -v test-repo-srv:/srv -v "$ROOT:/src:ro" "$S" /src/tests/test-repo/server.sh "$@"; }
# shellcheck disable=SC2329  # called through check
cli() { podman exec test-repo-client /src/tests/test-repo/client.sh "$@"; }

# check <desc> <want: a grep -E pattern, or !pattern for "must not match"> <cmd...>
check() { local desc=$1 want=$2 out rc ok; shift 2
  out=$("$@" 2>&1); rc=$?
  { echo "### $desc (rc=$rc): $*"; echo "$out"; } >> "$log"
  if [ "${want:0:1}" = '!' ]; then
    [ $rc -eq 0 ] && ! grep -qE -- "${want:1}" <<<"$out" && ok=1 || ok=0
  else
    [ $rc -eq 0 ] && grep -qE -- "$want" <<<"$out" && ok=1 || ok=0
  fi
  if [ $ok = 1 ]; then echo "PASS $desc"; else echo "FAIL $desc"; fails=$((fails+1)); tail -5 <<<"$out" | sed 's/^/     | /'; fi; }

echo "== server: $(podman run --rm "$S" flatpak --version), client: $(podman run --rm "$C" flatpak --version)"
srv init 2>&1 | tee -a "$log" | grep 'artifact refs' || { echo "server init failed (details: $log)"; exit 1; }
podman run -d --name test-repo-srv --network host -v test-repo-srv:/srv -v "$ROOT:/src:ro" "$S" /src/tests/test-repo/server.sh serve >/dev/null
podman run -d --name test-repo-client --privileged --network host -v "$ROOT:/src:ro" "$C" sleep infinity >/dev/null
sleep 1

echo; echo "######## publish (PR #7 open, labeled needs-testers)"
check "plan: the finished pr-checks run names PR 7" '^\["7"\]$' srv plan-run
check "plan: the sweep picks PR 7 (no repo yet)"     '^\["7"\]$' srv plan
# Artifacts expired: a gh-only check (the workflow installs no flatpak for it)
# that re-runs pr-checks; only a ready artifact makes it a publish.
srv expire 1 >/dev/null
check "decide: expired artifacts are a check"         '^check$' srv decide
check "reconcile re-runs the expired build"           're-running it' srv reconcile
check "the re-run was requested"                      '^POST repos/o/r/actions/runs/77/rerun$' srv calls
check "comment: rebuilding"                           'pr-checks is running again' srv show comment
srv expire 0 >/dev/null
check "decide: a ready artifact is a publish"         '^publish$' srv decide
check "reconcile publishes pr/7/"                    'published PR #7' srv reconcile
check "bucket: only the PR's app ref (+ appstream)"  '^app/org.flatpark.TestApp/x86_64/stable appstream/x86_64 appstream2/x86_64 $' srv show refs
check "bucket: discovery files and built-from"       'built-from.*flatpark-pr7.flatpakrepo.*org.flatpark.TestApp.flatpakref' srv show files
check "comment: install command"                     'flatpak install --user http://127.0.0.1:18767/pr/7/org.flatpark.TestApp.flatpakref' srv show comment
check "plan: the sweep leaves a current repo alone"  '^\[\]$' srv plan
published=$(srv show commit)

echo; echo "######## client"
check "1. user install from the flatpakref, extra-data applied"   '^HELLO-EXTRA-DATA$' cli user-install
check "2. system install (root), extra-data applied"              '^HELLO-EXTRA-DATA$' cli system-install
check "3a. remote-ls lists the PR's app"                          'app/org.flatpark.TestApp/x86_64/stable' cli remote-ls
check "3b. remote-ls lacks the foreign app and the dependency"    '!org.evil.App|runtime/org.test.Platform' cli remote-ls

echo; echo "######## label removed, then added again"
srv unlabel >/dev/null
check "plan: a pr-checks run on the unlabeled PR names nothing" '^\[\]$' srv plan-run
check "reconcile retires pr/7/ (withdrawn)"          'retired pr/7 \(withdrawn\)' srv reconcile
eold=$(srv show commit)
check "client: update shows the withdrawn message"   'end-of-life.*PR #7 test build withdrawn: flatpak uninstall org\.flatpark\.TestApp && flatpak remote-delete flatpark-pr7' cli update
srv relabel >/dev/null
check "plan: the sweep picks the retired, labeled PR" '^\["7"\]$' srv plan
check "reconcile republishes pr/7/"                   'published PR #7' srv reconcile
republished=$(srv show commit)
# The republished commit is the artifact's own, so it must not be older than
# the EOL commit a client already has: flatpak pulls with timestamp-check,
# which refuses a strictly older commit. build-commit-from keeps the source
# commit's timestamp, so all three carry the build's time (server.sh builds
# with a fixed one, so "now" can't match it by accident).
# shellcheck disable=SC2329  # called through check
same_time() { [ "${published#* }" = "2026-01-02 03:04:05 +0000" ] && [ "${eold#* }" = "${published#* }" ] && [ "${republished#* }" = "${published#* }" ] \
  && [ "${eold%% *}" != "${published%% *}" ] && [ "${republished%% *}" = "${published%% *}" ] \
  && echo "published $published / EOL $eold / republished $republished"; }
check "EOL and republished commits keep the build's timestamp" 'published' same_time
check "bucket: retired marker gone"                   '!retired' srv show files
check "client: update leaves end-of-life"             '!end-of-life' cli update
check "client: remote-info has no EOL line"           '!End-of-life' cli remote-info

echo; echo "######## PR #7 merged"
srv merge >/dev/null
check "reconcile retires pr/7/"                      'retired pr/7 \(merged\)' srv reconcile
check "bucket: retired marker"                       'retired' srv show files
check "comment: retired text"                        'flatpak install --reinstall flatpark org.flatpark.TestApp' srv show comment
eol='PR #7 merged; switch to the released build: flatpak install --reinstall flatpark org.flatpark.TestApp && flatpak remote-delete flatpark-pr7'
check "4a. flatpak update shows the EOL message"     "end-of-life.*${eol//./\\.}" cli update
check "4b. remote-info shows the EOL message"        "${eol//./\\.}" cli remote-info
check "4c. system update shows it too"               "end-of-life.*${eol//./\\.}" cli system-update

echo; echo "######## purge"
srv age-marker 1 >/dev/null
check "marker 1 day old: kept"                       'pr/7: none' srv reconcile
srv age-marker 15 >/dev/null
check "plan: the sweep picks the expired prefix"     '^\["7"\]$' srv plan
check "reconcile purges pr/7/"                       'purged pr/7' srv reconcile
check "5. prefix deleted"                            '^gone$' srv show gone

echo; [ $fails -eq 0 ] && echo "ALL PASS" || echo "$fails FAILED (details: $log)"
exit $fails
