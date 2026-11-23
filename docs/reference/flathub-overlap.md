---
description: Every listed app that Flathub also carries, and why FlatPark lists it anyway.
order: 4
---

# Apps also on Flathub

FlatPark doesn't package an app its developer already publishes on Flathub, and
lists a third party's Flathub app only when that package falls short
([rules](../packagers/can-it-be-packaged.md#apps-already-on-flathub)). This page
records each listed app that Flathub carries too, and the reason it stays here.

A PR that lists an app Flathub already has adds its row here, with the reason
from the PR. When an app turns up on Flathub after it was listed here, it goes
under [arrived on Flathub later](#arrived-on-flathub-later). When a reason stops
holding (the Flathub package catches up, or gains the missing feature), the row
is reviewed: either a new reason is found or the app is de-listed
([de-listed apps](delisted.md)).

"Verified" is Flathub's developer badge
(`https://flathub.org/api/v2/verification/<id>/status`). Versions were checked
on 2026-11-23.

## Already on Flathub when listed

A third-party package was on Flathub first. Ours is listed because that package
falls short.

| App | Our id | Flathub id | Why FlatPark lists it | Added |
|-----|--------|------------|-----------------------|-------|
| Google Chrome | `com.google.Chrome` | same | Flathub's package is a third party's (not verified), on 25.08 and built from source (dconf, zypak); ours is on 26.08 with the BaseApp's prebuilt zypak and builds nothing | [#803](https://github.com/flatpark/flatpark/pull/803), 2026-10-22 |
| Visual Studio Code | `com.visualstudio.code` | same | Flathub's often falls behind; ours follows Microsoft's releases within hours, and adds `code-flags.conf`, host gpg-agent signing, Plasma colour scheme and a host-visible TMPDIR (the metainfo lists the differences) | [#922](https://github.com/flatpark/flatpark/pull/922), 2026-10-31 |
| PyCharm Community | `com.jetbrains.PyCharm-Community` | same | Follows JetBrains' open-source releases sooner than Flathub's package, which was archived at 2024.3.4 when this was listed and has since resumed | [#1003](https://github.com/flatpark/flatpark/pull/1003), 2026-11-07 |
| WPS Office International | `com.wps.Office` | same | Flathub's third-party package is stuck on 11.1.0.11723 (2024); its update check can't find 12.x downloads (flathub/com.wps.Office#132, #156) | [#1126](https://github.com/flatpark/flatpark/pull/1126), 2026-11-10 |
| LibreSprite | `io.github.libresprite.libresprite` | `com.github.libresprite.LibreSprite` | Flathub's third-party package is pinned at an old release; ours ships the current official AppImage under upstream's own id | [#1215](https://github.com/flatpark/flatpark/pull/1215), 2026-11-14 |
| Eudic | `net.eudic.dict` | same | Flathub's package has fallen behind, with its update PRs left open; the vendor replaces the download in place, so the old pin can break new installs | [#1356](https://github.com/flatpark/flatpark/pull/1356), 2026-11-18 |
| Audacity | `org.audacityteam.Audacity` | same | Flathub's community package is on Audacity 3.7.8 and its 4.0 update fails to build; ours ships Audacity 4 | [#929](https://github.com/flatpark/flatpark/pull/929), 2026-11-01 |
| darktable | `org.darktable.Darktable` | same | Flathub's build leaves out darktable's local AI tools (object masks, denoise, upscale); ours ships upstream's AppImage with them, and grants less (no `host`, no `--device=all`) | [#1114](https://github.com/flatpark/flatpark/pull/1114), 2026-11-10 |
| OpenShot Video Editor | `org.openshot.OpenShot` | same | Flathub's is on 3.5.1, behind upstream's 4.x. It was also the first test of AppImage extraction (`appimage-tools`) on a heavy app | [#293](https://github.com/flatpark/flatpark/pull/293), 2026-09-01 |
| WeMeet | `com.tencent.wemeet` | same | Flathub dropped the forced-XWayland screenshare hook (its PR #69), but native Wayland screenshare doesn't work on Hyprland; ours keeps the hook | 2e37041b, 2026-07-15 |
| Enpass | `io.enpass.Enpass` | same | Flathub's Enpass can't verify the browser behind its extension; ours can ([how](../packagers/permissions.md#declaring-high-risk-permissions)) | a1ed6f7e, 2026-07-08 |
| calibre | `com.calibre_ebook.calibre` | same | Picks up upstream releases sooner; it also grants less than Flathub's `--filesystem=host` | 74a2488a, 2026-08-18 |
| thinkorswim | `com.schwab.thinkorswim` | `com.tdameritrade.ThinkOrSwim` | Packaged here without knowing Flathub had it, and kept. Flathub's package still carries the TD Ameritrade name and id | fad2a009, 2026-06-22 |
| TradingView | `com.tradingview.tradingview` | same | FlatPark's maintainer used to maintain the Flathub package, left the Flathub organisation, and now maintains it only here; Flathub's has since fallen behind (3.3.0 vs 3.5.1) | 400b09e2, 2026-07-04 |
| Longbridge | `com.longbridge.Longbridge` | `com.longbridgeapp.LongbridgePro` | FlatPark's maintainer used to maintain the Flathub package (the old id, renamed here in [#1121](https://github.com/flatpark/flatpark/pull/1121)), left the Flathub organisation, and now maintains it only here | [#1121](https://github.com/flatpark/flatpark/pull/1121), 2026-11-10 |

## Arrived on Flathub later

Listed here first; Flathub got the app afterwards. These stay unless the
developer asks for removal
([rules](../packagers/can-it-be-packaged.md#apps-already-on-flathub)).

| App | Our id | Flathub id | Flathub since | Who publishes it there | Added here |
|-----|--------|------------|---------------|------------------------|------------|
| PKHeX-Avalonia | `io.github.realgarit.PKHeX-Avalonia` | same | 2026-10-27 | The developer (verified, GitHub realgarit) | [#589](https://github.com/flatpark/flatpark/pull/589), 2026-10-09 |
| Timezones | `io.github.hernantz.timezones` | same | 2026-10-28 | The developer (verified, GitHub hernantz) | [#647](https://github.com/flatpark/flatpark/pull/647), 2026-10-13 |
| OpenCloud Desktop | `eu.opencloud.desktop.opencloud` | same | 2026-10-27 | A third party (not verified), built from source on the KDE runtime (flathub/flathub#9623) | [#798](https://github.com/flatpark/flatpark/pull/798), 2026-10-22 |
| Epic Games Launcher | `com.epicgames.eglv2` | `com.epicgames.launcher` | 2026-11-13 | Not verified; listed under Epic Games, Inc. | [#799](https://github.com/flatpark/flatpark/pull/799), 2026-10-22 |

## Same name, different app

Flathub search turns these up, but they are unrelated apps. Listed so nobody
checks them again.

| Ours | Flathub app with the same name |
|------|--------------------------------|
| Root, `com.rootapp.Root` (community chat) | ROOT, `cern.root.ROOT` (CERN data analysis) |
| Flow, `io.github.aedev.flow.desktop` (streaming client) | Flow, `com.flow_browser.flow` (browser) |
| Prism, `io.github.Boof2015.Prism` (audio metering) | Prism, `org.cutwire.Prism` (live visuals) |
| Letters, `io.github.bramble_apps.Letters` and `org.tunaos.letters` | Letters, `net.codelogistics.letters` (a separate GNOME word processor) |
| Tessera, `io.github.pedrohqb.Tessera` (smart-card drivers) | Tessera, `fr.ethal.tessera` (mosaic generator) |
| Compass, `org.tunaos.compass` (command palette) | COMPASS, `info.compassapp.COMPASS` (TTRPG library) |
| Writing Tools, `io.github.theJayTea.WritingTools` | Writing Tools, `dev.edfloreshz.WritingTools` (a COSMIC app) |
| WPS Office CN, `cn.wps.linux` | WPS 365, `cn.wps.wps_365` (a different product) |
