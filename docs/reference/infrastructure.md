---
description: What serves flatpark.org and dl.flatpark.org, what it costs, and the settings that have to stay as they are.
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

### Cloudflare settings that must stay

- **Bot Fight Mode off** for the zone. It challenges GitHub's runners, so every
  release-hook call from an upstream's workflow gets a 403 "Just a moment…"
  page, while tests from a home connection still pass. On the free plan it is
  zone-wide and can't be scoped. If hook calls start failing that way, look up
  the Ray ID under Security → Events.
- **The one WAF rate-limit rule** guards `delta-indexes/` per IP (60 requests
  per 10 s), so the counts can't be inflated from a single address. They can
  still be from many; that is accepted.

### Known gaps

- `update-check` and `release-dispatch` run the unpack check on x86_64 only;
  an aarch64 payload that doesn't unpack is caught by `pr-checks` when its pin
  changes in a PR, not on an automatic bump.
- Removing `aarch64` from an app's `build.arches` doesn't prune its arm ref.
