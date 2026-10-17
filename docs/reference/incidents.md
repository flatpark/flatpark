---
description: Every problem a user could notice in a listed app, what caused it, how it was found, and the check that now catches it.
order: 2
---

# Incidents

Every problem a user could notice in a FlatPark app, with its cause, how it was
found and how fast it was fixed. Each row names the check in the
[testing playbook](../reviewers/testing-playbook.md) that catches it now; every
new fix adds a row here and, when no check covers it yet, a check there.

Collected from the git history, June to mid-October 2026. Screenshots, links,
icons, storage size and permission narrowing are left out. Of the 193 app ids
listed in that time, 36 had a problem at some point (18.7%), 30 of them caused
by us; 7 were severe at listing.

## Severe

Won't install, won't start, loses data, or its main feature doesn't work.

| App | Symptom | Cause | Introduced by | Found by | Time to fix | Check |
|---|---|---|---|---|---|---|
| Trilium | Notes lost on every restart | `~/.local/share/trilium-data` not granted | Listing | User (#145) | ~3 weeks | [Data survives](../reviewers/testing-playbook.md#data-survives-a-restart) |
| AB Download Manager | Settings and library lost; second instance | `~/.abdm` not granted | Listing | User | ~7 weeks | [Data survives](../reviewers/testing-playbook.md#data-survives-a-restart), [second launch](../reviewers/testing-playbook.md#bus-names-tray-media-second-launch) |
| ZCode | Logged out on every start | `~/.zcode` not granted | Listing | Us | Same day | [Data survives](../reviewers/testing-playbook.md#data-survives-a-restart) |
| DBX | Drivers, JRE, DuckDB extensions lost | `~/.dbx`, `~/.duckdb` not granted | Listing | Us | 13 days | [Data survives](../reviewers/testing-playbook.md#data-survives-a-restart) |
| Fastpotify (now Spotifast) | Crashed on playback | An injected `getpid` shim broke libpulse | Listing | Upstream (spotifast#73) | ~6 weeks | [Main feature](../reviewers/testing-playbook.md#the-main-feature), [media](../reviewers/testing-playbook.md#bus-names-tray-media-second-launch) |
| ZapFast | Voice and media messages wouldn't play or record | The same shim | Listing | Us | ~3 weeks | [Main feature](../reviewers/testing-playbook.md#the-main-feature) |
| cc-switch | `EBUSY` when activating a config | Rename onto a single-file bind mount | Listing | User (#44) | ~19 days | [Main feature](../reviewers/testing-playbook.md#the-main-feature) |
| All tarball apps, system-wide | `apply_extra script failed` | `chown` fails as root without capabilities | Our pipeline | Us | — | [Unpacks](../reviewers/testing-playbook.md#it-unpacks-as-a-system-install) |
| 5 prebuilt consumers | "Wrong size" on install and update | Re-pin changed `sha256` but not `size` | Our change | Us | Same day (#359) | [Unpacks](../reviewers/testing-playbook.md#it-unpacks-as-a-system-install) |
| Sigma, mDNS Browser, Cockpit Tools | Transparent window, content flashes on scroll | GNOME 51 + forced non-accelerated WebKit + transparent window | Our change (runtime batch, #362) | Us | 2 hours (#364) | [Starts and draws](../reviewers/testing-playbook.md#it-starts-and-draws) |
| SubtitleEdit | Burning subtitles always failed | The SDK's ffmpeg has no libass | Our change (#233) | Contributor | ~18 hours (#238) | [Main feature](../reviewers/testing-playbook.md#the-main-feature) |
| Enpass 6.12 | Crash on start after an update | Upstream moved Qt from xcb to Wayland | Upstream | Us | 4 hours (#351) | [Starts and draws](../reviewers/testing-playbook.md#it-starts-and-draws) |
| tldraw | Install and update failed from 1.12 | Upstream renamed the launcher | Upstream | User (#130) | — | [Unpacks](../reviewers/testing-playbook.md#it-unpacks-as-a-system-install) |
| Harbor Beta | Pin 404 | Upstream re-cut with `-2` and deleted the old file | Upstream | Us | — | [Unpacks](../reviewers/testing-playbook.md#it-unpacks-as-a-system-install) |
| thinkorswim | Blank login dialog | JxBrowser 9's sandbox needs user namespaces | Upstream (probably) | Us | — | [Starts and draws](../reviewers/testing-playbook.md#it-starts-and-draws) |
| Authme | Crash on start in no-auth mode | 7.x uses the kernel keyring only | Upstream (probably) | Us | — (#527) | [Main feature](../reviewers/testing-playbook.md#the-main-feature) |

## Minor

One feature or one piece of desktop integration.

| App | Symptom | Cause | Fix | Check |
|---|---|---|---|---|
| Folia | No media controls, windows not grouped | MPRIS name not granted; wrong `StartupWMClass` | #609 (user report #607) | [Bus names](../reviewers/testing-playbook.md#bus-names-tray-media-second-launch), [window class](../reviewers/testing-playbook.md#window-class) |
| Flow | Media controls dead | `launch` symlink gave WebKit a hashed name | #549 | [Bus names](../reviewers/testing-playbook.md#bus-names-tray-media-second-launch) |
| Harbor | Media keys dead | MPRIS name not granted | #517 | [Bus names](../reviewers/testing-playbook.md#bus-names-tray-media-second-launch) |
| OpenTubeX | No media controls | Branded bus name not granted | #291 | [Bus names](../reviewers/testing-playbook.md#bus-names-tray-media-second-launch) |
| Stoat, Thorium and 4 more Electron apps | No media controls; windows not grouped | Missing grant; `StartupWMClass` not measured | #561 | [Bus names](../reviewers/testing-playbook.md#bus-names-tray-media-second-launch), [window class](../reviewers/testing-playbook.md#window-class) |
| PhotoCraft | Windows not grouped | Wrong `StartupWMClass` | #569 | [Window class](../reviewers/testing-playbook.md#window-class) |
| materialgram | Bots, payments, Instant View broken | No WebKitGTK in the freedesktop runtime | #515 | [Main feature](../reviewers/testing-playbook.md#the-main-feature) |
| Min | Saving passwords failed on Hyprland and Sway | Unknown desktop → plain-text store | #560 | [Main feature](../reviewers/testing-playbook.md#the-main-feature) |
| PI-Desktop | Couldn't quit | An injected `getpid` shim | #434 | [Main feature](../reviewers/testing-playbook.md#the-main-feature) |
| Magpie | 16 directories created in `$HOME` | `:create` on other tools' directories | #461 | [Home folder](../reviewers/testing-playbook.md#nothing-new-in-the-home-folder) |
| Yaak | Installed the CEF build instead of WebKitGTK | Loose resolver match | d1d0020 | [Unpacks](../reviewers/testing-playbook.md#it-unpacks-as-a-system-install) |
| WorkBuddy | Install failed in one region | CDN served different bytes per region | #651 | — (no local check reproduces it) |
| Cellar | Installer shortcuts written to the host desktop | Desktop path not redirected | #676 | [Home folder](../reviewers/testing-playbook.md#nothing-new-in-the-home-folder) |

## What the record shows

- **Severe listing defects are rare and concentrated.** Four of the seven were
  a `~/.dotdir` not granted, all before mid-August; two were the same injected
  shim, after which injecting code into open-source apps was banned; one was
  `EBUSY` on a single-file grant.
- **Minor problems are desktop integration** (window class, media names), and
  were fixed in one audit across the catalog.
- **Fixing is fast; finding is the bottleneck.** 14 of the 36 were fixed within
  a day. The severe ones we caused that weren't caught at once took 13 days to
  7 weeks, and four were found by users or upstream: data loss shows only after
  a restart, a crash only after pressing play.
- **Batch changes worked** when sampled by stack: the GNOME 51 transparent
  window was found right after the upgrade, every app built the same way was
  checked, and all three were fixed within hours
  ([batch changes](../reviewers/batch-changes.md)).
- **Upstream breakage (about 3%) can't be prevented before release**; it is
  fixed when it happens.

"Found by us" is inferred from the absence of an issue, and problems in apps
removed without a fix commit aren't counted.

## Adding a row

When a fix for a listed app merges, add a row: severe if the app wouldn't
install, start, keep data, or do its main job; minor otherwise. Name the check
that would have caught it. If none would, add the check to the
[testing playbook](../reviewers/testing-playbook.md) in the same PR.
