---
description: What serves flatpark.org, dl.flatpark.org and test.flatpark.org, what it costs, and the settings that have to stay as they are.
---

# Infrastructure

FlatPark runs on one Cloudflare account and GitHub Actions:

- **flatpark.org**: the site, on Cloudflare Pages, deployed by `publish.yml`.
- **dl.flatpark.org**: the signed OSTree repository, in R2 behind a custom
  domain. Runtimes come from Flathub, and an extra-data app's payload from its
  vendor, so neither is stored here.
- **hooks.flatpark.org**: the release webhook Worker
  ([`workers/release-hook`](../../workers/release-hook/src/index.js)) that
  [publish-action](../developers/publish-action.md) calls.
- **Install counts**: a Worker on `dl.flatpark.org/delta-indexes/*`
  ([`workers/install-stats`](../../workers/install-stats/src/index.js)).
- **test.flatpark.org**: one test repository per PR labeled `needs-testers`
  ([testing a PR build](../users/testing.md)), in the R2 bucket
  `flatpark-testing` behind a custom domain, signed with a separate testing
  key. Nothing in it is meant to last.

Who holds the account and how that changes is in
[governance](../project/governance.md#infrastructure); how the repository is
signed is in [security](../project/security.md#how-the-repository-is-signed).

## For agents

### Cost

R2 storage is the only cost that grows with the catalog, so packages are
shaped to keep it small:

- **Extra-data first.** Only the wrapper, metainfo and icons reach R2, a few MB
  per app; the vendor's file is downloaded at install time.
- **Screenshots are linked** from upstream, never stored.
- **No full source builds by default**: they store the whole compiled app,
  ten to seventy times an extra-data package.
- **One version per ref.** Publishing only adds; objects leave on the weekly
  `delist-prune` (Saturday 02:00 UTC, or run by hand), which also prunes old
  summaries.

R2 reads grow with users instead, and are kept off R2 by the edge cache
(see the cache rules under [Cloudflare settings](#cloudflare-settings-that-must-stay)).

To see what an app takes up, use the **Download Size** of
`flatpak remote-info flatpark <ref>`. `flatpak remote-ls` folds the extra-data
payload into its size column, so it overstates. Summing every ref still
overcounts, because OSTree shares objects (one Electron BaseApp copy serves
all Electron apps); `ostree pull --mirror` of every ref gives the live size.

### Install counts

The Worker records one row per install or update in Analytics Engine; the
header comment in its source explains why it sits on `delta-indexes/*` and
what it stores (no IP, no raw user agent). `install-stats.yml` rolls the rows
up daily at 01:30 UTC into `dl.flatpark.org/stats/daily/*.json` and
`stats/totals.json`, which the site reads on its next publish. Analytics Engine
keeps three months, so the daily files are the only long-term record.

If counts look wrong, first check that the summary still advertises indexed
deltas: the counting depends on exactly one delta-index request per pull.

### Test repositories

`pr-test-repo.yml` keeps `pr/<N>/` in `flatpark-testing` in one of three
states, decided by `scripts/test-repo-reconcile.sh <N>` from the PR and the
bucket alone:

- **live** while PR N is open and labeled `needs-testers`: the refs of the
  apps the PR's diff touches, taken from its own pr-checks artifact
  (`flatpak-repo-<arch>-pr<N>`, kept 7 days), re-pulled into a clean repo and
  signed with the testing key. `built-from` holds the head sha it was built
  from; a push makes it stale, and the next run rebuilds it. If the
  artifacts have expired, the pr-checks run is re-run; if it is too old to
  re-run, the PR comment asks for a push or a manual re-run instead. Only a
  ready build or a retire installs flatpak in the job; waiting on a run or
  explaining why there is no build is GitHub API calls only.
- **retired** once the PR closes or loses the label: every ref gets an
  end-of-life message saying how to switch back, and a `retired` file holds
  the time.
- **purged** 14 days after that (`TEST_REPO_RETIRE_DAYS`).

The triggers only speed things up. pr-checks finishing, a label change or
close, and a dispatch each reconcile one PR; an hourly sweep plans every
prefix and labeled PR and reconciles the ones that need it, so a missed or
disabled trigger costs at most an hour. Each reconcile job handles one PR and
touches only `pr/<N>/` (`concurrency: test-repo-pr-<N>`). The workflow runs
main's code only and never checks out a PR. What it takes from the untrusted
run is checked first: the tar's paths, links and size, and which refs it
holds.

- **Environment `testing`** (deploys from `main` only) holds
  `FLATPAK_TESTING_GPG_KEY` (the armored secret testing key, no passphrase,
  fingerprint `7858FD7DD9F527EC02342A9A7630ADC35A942414`; its public half is
  [`config/flatpark-testing.pub.asc`](../../config/flatpark-testing.pub.asc)),
  `R2_ACCOUNT_ID`, and `R2_TESTING_ACCESS_KEY_ID` /
  `R2_TESTING_SECRET_ACCESS_KEY`, a token scoped to this bucket only. The
  scripts import the key into a keyring of their own; the production key is
  never in it.
- **Cache headers**: everything under `pr/` is uploaded with
  `Cache-Control: public, max-age=300`. These files are rewritten on every
  push and deleted later, so the one-year `immutable` header production
  objects get must never be used here; `scripts/sync-r2.sh` is not used
  for this bucket.
- **Lifecycle rule**: R2 deletes objects under `pr/` after 120 days. It is a
  backstop for a purge that never ran, not part of the normal lifecycle.

### GitHub settings that must stay

- **Fork PR workflow runs need approval for all external contributors.**
  GitHub counts everyone outside the flatpark organization as external.
  Maintainers and the `triage` team are organization members, so pr-checks
  runs on their own PRs, fork or not, without approval: a team member's push
  is trusted the way their approval of someone else's push is. Every push from
  outside the organization is looked at before pr-checks runs, so a
  `needs-testers` label is enough to publish what pr-checks built.
  Maintainers approve held runs in the UI; the `triage` team (triage role on
  this repository) approves them with `/approve-ci`, which `approve-ci.yml`
  turns into an API call. That workflow decides who may use it from the
  commenter's role on the repository, so giving someone the triage role lets
  them approve CI, and adding them to the organization lets their own PRs run
  unheld.
- **The Actions event policy for `pr-test-repo.yml`** (policy 14419) allows
  exactly `pull_request_target`, `workflow_run`, `schedule` and
  `workflow_dispatch` for that file. From 2026-12-02 GitHub disables
  `pull_request_target` on public repositories unless a policy allows it.
  Adding a trigger to `pr-test-repo.yml` means adding it to the policy too, or
  runs from that trigger are blocked. Even without `pull_request_target`, the
  hourly sweep keeps the test repositories correct.

### Cloudflare settings that must stay

- **Bot Fight Mode off** for the zone. It challenges GitHub's runners, so every
  release-hook call from an upstream's workflow gets a 403 "Just a moment…"
  page, while tests from a home connection still pass. On the free plan it is
  zone-wide and can't be scoped. If hook calls start failing that way, look up
  the Ray ID under Security → Events.
- **The one WAF rate-limit rule** guards `delta-indexes/` per IP (60 requests
  per 10 s), so the counts can't be inflated from a single address. They can
  still be from many; that is accepted.
- **Two cache rules on `dl.flatpark.org`.** Cloudflare caches no OSTree file
  by default: `.filez`, `.dirtree`, `summary.idx` are not on its extension
  list, so without these rules every pull request is an R2 read, billed per
  request past 10 M a month (it passed that in November 2026 at ~650 k a day).
  - `flatpark cache`: `/objects/`, `/deltas/`, `/summaries/`, and
    `/summary.idx`, `/summary`, `/summary.sig`, `/config`. Eligible for cache,
    edge TTL **from the origin's Cache-Control**, which `scripts/sync-r2.sh`
    sets: a year for content-addressed objects, `s-maxage=60` for the mutable
    files. The free plan can't set an edge TTL under 2 h in a rule, far too
    long for `summary.idx`, so the short TTL has to come from the header.
    Browser TTL must be **Respect origin TTL**: left at the zone setting,
    Cloudflare raises a cached response's `max-age=0` to the zone's 4 h, and a
    caching proxy between a user and the edge could then hold `summary.idx`
    that long.
    After changing the headers in `sync-r2.sh`, run publish by hand with
    **rewrite_headers**, or files whose bytes don't change (`config`, old
    commits' `.commitmeta`) keep the old header.
  - `flatpark 404`: `/delta-indexes/`, edge TTL 2 h, 404 cached 2 h. The repo
    builds no static deltas, so every delta-index request is a 404. The
    install-stats Worker runs before the cache, so caching these doesn't
    affect counting.

  Check with `curl -sI` twice: `cf-cache-status: HIT` on an object and a
  delta-index, `HIT` with `age` under 60 on `summary.idx`.

### Known gaps

- `update-check` and `release-dispatch` run the unpack check on x86_64 only;
  an aarch64 payload that doesn't unpack is caught by `pr-checks` when its pin
  changes in a PR, not on an automatic bump.
- Removing `aarch64` from an app's `build.arches` doesn't prune its arm ref.
