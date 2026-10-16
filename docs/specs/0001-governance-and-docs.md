# Spec 0001: Governance, testing and documentation

- **Status:** accepted direction; being built. This replaces the RFC draft first
  posted in #605. The discussion that led here is in that PR, and the decision is
  summarised in [this comment](https://github.com/flatpark/flatpark/pull/605#issuecomment-6205935172).
- **Author:** @jing2uo
- **Related:** #585 (pre-release testing), #473 (upstream self-merge), #379
  (upstream approvals), #599–#603 (packaging policy and levels)

## Goal

FlatPark is a Flatpak remote that runs efficiently and is easy to take part in.

Speed is the main reason it exists. Apps often land minutes after an upstream
release, and a fix reaches users just as fast. Every rule in this spec is judged
by two questions: does it stop us shipping our own bugs, and does it keep that
speed?

## Decisions

1. **No manual review on every listing or update.** A human gate on every PR would
   end the speed, and the history (below) shows it wouldn't catch much.
2. **Testing is driven by a written playbook,** run with AI assistance on every new
   listing and on every change we make to a package: runtime upgrades, permissions,
   build steps, prebuilt stacks, wrappers.
3. **Every incident becomes a check.** Each past bug is a specific item in the
   playbook, and every future fix adds one. Items that can be checked mechanically
   move into CI over time. The incident list is public.
4. **Batch changes are sampled by stack.** The checks run on every affected app,
   plus a real feature test on one app of each stack (Electron, Tauri/WebKit, Qt,
   GTK, Java, .NET, Flutter, …). A problem in one means checking every app of that
   stack.
5. **Upstream breakage stays on the fast path.** An upstream release that breaks
   our package is fixed quickly; version bumps are not held for review.
6. **Human testing only under a hard constraint.** If an app's core feature can't be
   tested because it needs an account, a login or hardware we don't have, the app
   isn't listed until someone has tested it. The PR stays open, its build goes to
   the test remote, and a tester or upstream confirms it.
7. **Human review where it's about trust, not bugs:** packages at level Modified or
   Reduced isolation, infrastructure, principles, new repositories, and anything
   that touches the security floor. Two reviewers there.
8. **Documentation is the main work.** One library in the repo's `docs/`, written
   in enough detail that an AI agent can package and review apps from it, and
   rendered on the site so people read the same files. What people read stays short
   and plain.

## Evidence: what went wrong so far

Every fix shipped for a listed app was collected from the git history (June to
mid-October 2026). Screenshots, links, icons, R2 size and permission narrowing are
left out; only problems a user could notice are counted.

**Denominator:** 193 app ids have been listed, 28 of them since removed or renamed.
**36 had a user-facing problem at some point: 18.7%.**

| Measure | Apps | Share of 193 |
|---|---|---|
| Any problem | 36 | 18.7% |
| Caused by us (listing defect or our later change) | 30 | 15.5% |
| Defect present at listing | 21 | 10.9% |
| … of which severe (won't install, won't start, loses data, core feature broken) | 7 | 3.6% |
| … of which minor (media controls, window grouping, one feature) | 14 | 7.3% |
| Severe, caused by our later changes | 9 apps, 3 incidents | 4.7% |
| Severe, caused by upstream changes | 6 | 3.1% |

Install stats (`dl.flatpark.org/stats/totals.json`) only cover 2026-10-04 to
10-14 and currently listed apps. Of the 50 apps with at least 10 active installs,
11 had a problem (22%): the more an app is used, the more likely a problem is
found. So 18.7% is a lower bound.

### Severe problems

| App | Symptom | Cause | Introduced by | Found by | Time to fix |
|---|---|---|---|---|---|
| Trilium | Notes lost on every restart | `~/.local/share/trilium-data` not granted | Listing | User (#145) | ~3 weeks |
| AB Download Manager | Settings and library lost; second instance | `~/.abdm` not granted | Listing | User | ~7 weeks |
| ZCode | Logged out on every start | `~/.zcode` not granted | Listing | Us | Same day |
| DBX | Drivers, JRE, DuckDB extensions lost | `~/.dbx`, `~/.duckdb` not granted | Listing | Us | 13 days |
| Fastpotify (now Spotifast) | Crashed on playback | fake-getpid shim broke libpulse | Listing | Upstream (spotifast#73) | ~6 weeks |
| ZapFast | Voice and media messages wouldn't play or record | Same shim | Listing | Us | ~3 weeks |
| cc-switch | EBUSY when activating a config | Rename onto a single-file bind mount | Listing | User (#44) | ~19 days |
| All tarball apps, `--system` | `apply_extra script failed` | chown fails as root | Our pipeline | Us | — |
| 5 prebuilt apps | "Wrong size" on install and update | Re-pin changed sha256 but not size | Our change | Us | Same day (#359) |
| Sigma, mDNS Browser, Cockpit Tools | Transparent window, content flashes on scroll | GNOME 51 + forced non-accelerated + transparent window | Our change (runtime batch, #362) | Us | 2 hours (#364) |
| SubtitleEdit | Burning subtitles always failed | SDK ffmpeg has no libass | Our change (#233) | Contributor | ~18 hours (#238) |
| Enpass 6.12 | Crash on start after auto-update | Upstream moved Qt from xcb to wayland | Upstream | Us | 4 hours (#351) |
| tldraw | Install and update failed from 1.12 | Upstream renamed the launcher | Upstream | User (#130) | — |
| Harbor Beta | Pin 404 | Upstream re-cut with `-2` and deleted the old file | Upstream | Us | — |
| thinkorswim | Blank login dialog | JxBrowser 9 sandbox needs user namespaces | Upstream (probably) | Us | — |
| Authme | Crash on start in no-auth mode | 7.x uses kernel `keyctl` only | Upstream (probably) | Us | — (#527) |

### Minor problems

| App | Symptom | Cause | Fix |
|---|---|---|---|
| Folia | No MPRIS, windows not grouped | MPRIS name not granted; wrong StartupWMClass | #609 (user report #607) |
| Flow | Media controls dead | `launch` symlink gave WebKit a hashed name | #549 |
| Harbor | Media keys dead | MPRIS name not granted | #517 |
| OpenTubeX | MPRIS dead | Branded bus name not granted | #291 |
| Stoat, Thorium + 4 Electron apps | No MPRIS; window/launcher not grouped | Missing grant; StartupWMClass not measured | #561 |
| PhotoCraft | Windows not grouped | Wrong StartupWMClass | #569 |
| materialgram | Bots, payments, Instant View broken | No WebKitGTK in the fd runtime | #515 |
| Min | Saving passwords failed on Hyprland/Sway | Unknown desktop → basic_text store | #560 |
| PI-Desktop | Couldn't quit | fake-getpid shim | #434 |
| Magpie | 16 directories created in `$HOME` | `:create` on other tools' directories | #461 |
| Yaak | Installed the CEF build instead of WebKitGTK | Loose resolver match | d1d0020 |
| WorkBuddy | Install failed in one region | CDN served different bytes per region | #651 |
| Cellar | Installer shortcuts written to the host desktop | Desktop path not redirected | #676 |

### What the history says

- **One package shipped with its core feature unusable:** Fastpotify, for six weeks,
  found by upstream. We had no Spotify account, so nobody pressed play. It was not a
  review miss; it was a core feature nobody could test.
- **Severe listing defects are rare and concentrated.** Four of the seven were a
  `~/.dotdir` we hadn't granted (all before mid-August; none since the pattern was
  understood), two were the same injected shim (which led to principle 3), and one
  was EBUSY on a single-file grant.
- **Minor problems are mostly desktop integration** (StartupWMClass, MPRIS names),
  and were fixed in one audit across the catalog. They can be measured mechanically.
- **Fixing is fast; finding is the bottleneck.** 14 of the 36 were fixed within a
  day, every one of them found by us or a contributor right after a listing or a
  change. The six severe problems we caused that weren't caught at once each took
  13 days to 7 weeks, and four of them were found by users or upstream: data loss
  shows only after a restart, a crash only after pressing play.
- **Batch changes worked.** 43 apps moved to GNOME 51 at once. A transparent Tauri
  window rendered wrong right after the upgrade; the cause was shared by every app
  built the same way, so all were checked, two more were found, and all three were
  fixed within hours. That is decision 4.
- **Upstream breakage (~3%) can't be prevented before release,** and a review gate
  on version bumps wouldn't have caught it. It is fixed when it happens.

Caveats: "found by us" is inferred from the absence of an issue, and problems in
apps that were removed without a fix commit aren't counted.

## Testing

### Playbook

A testing playbook in `docs/reviewers/` is the checklist an agent (or a person)
runs. It starts with the checks the history asks for:

| Check | Catches |
|---|---|
| Install from the built repo, user **and** system-wide | Wrong size, tar chown as root, renamed files, 404 pins |
| Launch; screenshot the first window | Crash on start, transparent/blank windows, wrong Qt platform |
| Use the app, quit, restart, compare `~/.var/app/<id>` and any granted dotdir | Settings and data lost to tmpfs |
| Diff `$HOME` before and after | Directories created where they shouldn't be |
| Measure the window class against `StartupWMClass` | Windows not grouped |
| Play a tone; check the MPRIS name on the bus | Media controls; audio broken by a shim |
| Core feature, as stated in the PR | Everything above misses |

Each incident from now on adds a row, with a link to the fix. Checks that can be
run headless (Xvfb or headless weston, a null audio sink, `dbus-run-session`) move
into PR CI over time.

### Test remote

`flatpark-test` is a separate remote at `dl.flatpark.org/test/`, with its own
signing key, for builds that need a person to test them. Each PR is published as
its own branch:

```sh
flatpak remote-add --user flatpark-test https://dl.flatpark.org/test/flatpark-test.flatpakrepo
flatpak install --user flatpark-test <app-id>//pr<N>
```

- The untrusted build stays in `pr-checks`, which has no secrets. A privileged
  `workflow_run` job commits that build into the test repo, signs it with the test
  key, and syncs it to R2. The stable key never touches PR content.
- The test repo is disposable: it is rebuilt from scratch and fully synced, refs
  are marked end-of-life when a PR closes, and a daily job sweeps anything left.
- A test build installs next to the regular one and **shares `~/.var/app/<id>`**
  with it. A passed test checks function, not security. Both are said on the
  testers' page.

It ships in its own PR.

## Who signs off on what

| Change | Sign-off |
|---|---|
| Version or pin bump that passes the mechanical gate | CI only (auto-merge) |
| Upstream self-merge within the safe surface | CI only |
| New listing; change to a listed package | Packager runs the playbook; CI |
| New listing whose core feature we can't test | Plus a tester or upstream, via `flatpark-test` |
| Batch change (runtime, prebuilt stack, shared wrapper) | Playbook on every app + one feature test per stack |
| Package at level Modified or Reduced isolation | 2 reviewers |
| De-listing for one of the listed reasons | 1 reviewer |
| Principles, infrastructure, security floor, new repository | 2 reviewers |

While there is no other active reviewer, the owner's sign-off counts as two. As
soon as one other reviewer is active, two-reviewer changes need them too. A
release found to steal data or damage systems is pulled at once by anyone with
merge rights, with a public write-up within 7 days.

## What stays from the RFC draft

These parts of the first draft stand, and move into the docs as they are written:

- **Principles:** extra-data only; source builds in their own `-release`
  repositories; open-source apps ship unmodified; closed-source changes are
  disclosed; every package declares its packaging level and CI checks it; least
  privilege by default; upstream has the final word on its own app; judge the
  package, not how it was written; one runtime major; decisions in public.
- **Roles:** owner, reviewer, tester, upstream maintainer, packager. Reviewers
  matter for the trust decisions above; testers for hard constraints.
- **Upstream lanes (#473):** self-merge for pins on the same host, metainfo and
  narrowing `finish-args`; anything else is an upstream request with a
  security-only check.
- **Lifecycle:** listing, Flathub overlap, renames and removals via Flatpak
  end-of-life (`config/renames.yml`, 90 days), and the de-listing reasons.
- **Security and keys:** `SECURITY.md`, emergency pull, offline master key, a
  separate test key, infrastructure continuity.
- **News:** one stream at `/news/` with RSS/Atom, generated from merged PRs. It
  ships in its own PR.

## Documentation

### One library, two readers

All documentation lives in the repo's `docs/`. The site renders that directory
under `flatpark.org/docs/`, so an agent reading the repo and a person reading the
site see the same files and nothing needs syncing. The site's current pages
(about, policies, trust, guide, contributing, legal, conduct) move in; their old
URLs redirect.

```
docs/
  README.md        index: the entry point for agents and GitHub, /docs/ on the site
  users/           install, permissions, packaging levels, renames and removals,
                   reporting problems, testing new apps
  developers/      getting listed or not, the approval shield, your own PRs,
                   push-mode updates, Flathub overlap, renaming your app
  packagers/       quick start, flatpark.yml, by format, by stack, prebuilt,
                   resolvers, local testing, sandbox problems
  reviewers/       review runbook, testing playbook, batch changes
  reference/       common solutions, incident list
  project/         about, principles, governance, security, legal, conduct
  specs/           design specs like this one
  internal/        operations notes; not published
```

- The directory is the sidebar. Each page has `title`, `description` and `order`
  in its front matter, and each directory has an `_index.md` with its title and
  order. A page with `publish: false` stays in the repo only.
- Links are relative `.md` paths, so they work on GitHub and for an agent; the site
  rewrites them to its own URLs, and link-check catches broken ones.
- **Short first, detail after.** Each page opens with what a person needs, in a few
  plain paragraphs. Rules, edge cases and checks follow under `## Details`, which
  the site folds away. Pages that are only reference (the playbook, the incident
  list, common solutions) are detail throughout. There is one version of each
  page, never a short copy and a long copy.
- **For agents:** `llms.txt` lists the docs, `/llms-full.txt` concatenates them, and
  each page's Markdown source is served next to it. `AGENTS.md` at the repo root
  points to `docs/README.md`.
- **Language:** English is the source. User- and developer-facing pages get a
  zh-Hans translation next to the English file (`install.zh-Hans.md`); the rest
  falls back to English.

### What the docs need to say

- what can be listed, what can't, and when an app is removed;
- how to package an app, what the limits are, and when to use `flatpark/prebuilt`;
- which changes ship straight away, and when someone else needs to review;
- what app developers, third-party packagers and users each need to know;
- the solutions built up for common problems, including where each kind of
  sandbox problem goes:

| Problem | Open-source app | Closed-source app |
|---|---|---|
| Needs an env var or launch flag | Workaround OK (Unmodified) | Workaround OK |
| A library or tool missing from the runtime; fonts | From `flatpark/prebuilt` or as extra-data (Adapted) | Same |
| In-app updater can't work in Flatpak | Turn it off via its own setting (Adapted); if it has no switch, ask upstream to check `FLATPAK_ID` | Same, or disable it in the build (Modified, disclosed) |
| Writes to a hardcoded `~/.dotdir` | `--filesystem=~/.dir:create` for the app's own directory | Same |
| Needs to run host commands | PATH script via `flatpak-spawn --host` (Reduced isolation, declared) | Same |
| The app's own sandbox needs user namespaces | zypak for Chromium-based apps; otherwise ask upstream | May turn it off (Reduced isolation, disclosed) |
| Needs code injected into its process, or files patched | Not listed; report upstream | Last resort (Modified, disclosed) |
| The vendor's installer must run at first launch | Not listed | Allowed (Modified, disclosed) |

## Plan

| Step | What | Where |
|---|---|---|
| 1 | This spec | this PR |
| 2 | `/docs/` on the site: collection from `docs/`, sidebar, link rewriting, redirects, `llms-full.txt`; existing pages and docs moved in | this PR |
| 3 | Docs content: per-audience pages, testing playbook, incident list, common solutions; governance and security pages | this PR, then ongoing |
| 4 | `flatpark-test` remote | own PR |
| 5 | News with RSS/Atom | own PR |
| 6 | Renames and removals via end-of-life (AeroFTP first) | own PR |
| 7 | Playbook checks in PR CI, one at a time | ongoing |

## Open questions

- **An edge/verified label** in the one remote, where new listings start as edge
  and become verified after time and installs, with clients hiding edge by default.
  It would need client support: Bazaar's `show-only-verified` reads Flathub's
  verification only, and its blocklists are distro files with no user toggle. Not
  planned until a client wants it.
- **How Bluefin wants to integrate** the remote, and what it needs from these docs.
