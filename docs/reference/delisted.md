---
description: Every app FlatPark has de-listed or been told not to list, why, and what it would take to bring one back.
order: 3
---

# De-listed apps

Every app that has left FlatPark, and every developer who said no to a listing.
Anyone looking for apps to package checks this page first
([finding apps](../packagers/finding-apps.md#before-you-start)): an app here is
not proposed or packaged again unless the condition for its section is met.

A de-listing PR adds its row here in the same PR
([de-listing](../project/policies.md#de-listing)). The ids are the ones that
were removed; an app that came back under the same id stays in its row, marked
as re-listed.

## Declined

Apps whose developer said no to a FlatPark listing. Don't package them again and
don't ask again; the only way back is a new, public yes from the developer. A
refusal counts however it arrives: unlike an approval, a private email is enough,
and the listing comes down without argument.

Only explicit refusals go here. A thread that went quiet or was closed without a
word, or a "fine, but it won't be official", goes under
[upstream didn't back it](#upstream-didnt-back-it).

| App | ID | Refusal | Date |
|-----|----|---------|------|
| RichEZFast | `com.gtht.RichEZFast` | Guotai Haitong Securities (formerly Guotai Junan), the publisher, emailed the FlatPark maintainer through its legal team and asked FlatPark to stop distributing the app; de-listed in [flatpark#258](https://github.com/flatpark/flatpark/pull/258) | 2026-08 |
| LeePanel | `com.leepanel.desktop` | [gna1280072/LeePanel#14 (comment)](https://github.com/gna1280072/LeePanel/issues/14#issuecomment-5372419342): the app's current and planned features need direct access to the local machine, so a sandboxed build doesn't suit it; de-listed in [flatpark#251](https://github.com/flatpark/flatpark/pull/251) | 2026-08-21 |
| Titanium Inspector | `io.github.justcoding121.TitaniumInspector` | [justcoding121/titanium-web-proxy#1051 (comment)](https://github.com/justcoding121/titanium-web-proxy/issues/1051#issuecomment-5842744780): "we are not going to support a Flatpak install. Please remove the FlatPark listing"; system proxy and root CA trust need the host session; de-listed in [flatpark#448](https://github.com/flatpark/flatpark/pull/448) | 2026-09-26 |
| Avash | `io.github.AdrienAvalon.avash` | [AdrienAvalon/avash#42 (comment)](https://github.com/AdrienAvalon/avash/issues/42#issuecomment-6013722734): "I'd prefer the listing be removed"; upstream is going to Flathub under the same id and won't vouch for a build pipeline it doesn't run; de-listed in [flatpark#547](https://github.com/flatpark/flatpark/pull/547) | 2026-10-06 |
| En Croissant | `org.encroissant.app` | [franciscoBSalgueiro/en-croissant#924 (comment)](https://github.com/franciscoBSalgueiro/en-croissant/issues/924#issuecomment-6389505639): "I'm not going to endorse third party builds of En Croissant for safety reasons"; de-listed in [flatpark#839](https://github.com/flatpark/flatpark/pull/839) | 2026-10-24 |

## Upstream didn't back it

Withdrawn because upstream showed no interest in the listing, wouldn't stand
behind it, or set conditions that weren't met. Not a refusal, but the same rule
applies in practice: it comes back only if upstream asks for it or approves it,
and nobody re-pitches it in the meantime.

| App | ID | What upstream said | De-listed |
|-----|----|--------------------|-----------|
| Orca | `com.stablyai.orca` | [stablyai/orca#7884](https://github.com/stablyai/orca/issues/7884) closed as out of scope for the tracker | [#251](https://github.com/flatpark/flatpark/pull/251), 2026-08-23 |
| goose | `io.github.block.Goose` | [aaif-goose/goose#6602](https://github.com/aaif-goose/goose/issues/6602): the project's collaborators said an official repository is ideal for an app like goose | [#260](https://github.com/flatpark/flatpark/pull/260), 2026-08-26 |
| ZenNotes | `org.zennotes.ZenNotes` | [ZenNotes/zennotes#229](https://github.com/ZenNotes/zennotes/issues/229): a community remote may carry it, "but it will not be a first-party channel" | [#260](https://github.com/flatpark/flatpark/pull/260), 2026-08-26 |
| Rowboat | `com.rowboatlabs.Rowboat` | [rowboatlabs/rowboat#699](https://github.com/rowboatlabs/rowboat/issues/699): no reply from the project | [#260](https://github.com/flatpark/flatpark/pull/260), 2026-08-26 |
| HMCL | `net.huangyuhui.hmcl` | [HMCL-dev/HMCL#6124](https://github.com/HMCL-dev/HMCL/issues/6124): packaging HMCL needs the agreement of named maintainers, which was never given | [#260](https://github.com/flatpark/flatpark/pull/260), 2026-08-26 |
| Trilium Notes | `com.triliumnext.notes` | [TriliumNext/Trilium#5108](https://github.com/TriliumNext/Trilium/issues/5108): no reply from the maintainers | [#260](https://github.com/flatpark/flatpark/pull/260), 2026-08-26 |
| Plezy | `com.edde746.plezy` | [edde746/plezy#2560](https://github.com/edde746/plezy/issues/2560), the listing notice, closed as not planned | [#513](https://github.com/flatpark/flatpark/pull/513), 2026-10-04 |
| GodSVG | `com.godsvg.GodSVG` | [MewPurPur/GodSVG#1856](https://github.com/MewPurPur/GodSVG/issues/1856): the maintainer objected to the AI-written listing notice; withdrawn on our side | [#557](https://github.com/flatpark/flatpark/pull/557), 2026-10-07 |
| Dorion | `dev.spikehd.Dorion` | SpikeHD/Dorion#243, the listing thread, deleted without a reply | [#844](https://github.com/flatpark/flatpark/pull/844), 2026-10-25 |
| Termix | `com.karmaa.termix` | [Termix-SSH/Termix#1574](https://github.com/Termix-SSH/Termix/issues/1574) closed without a reply | [#844](https://github.com/flatpark/flatpark/pull/844), 2026-10-25 |
| Mockoon | `com.mockoon.app` | [mockoon/mockoon#2378](https://github.com/mockoon/mockoon/issues/2378): doesn't mind the listing but can't endorse a distribution they don't control | [#844](https://github.com/flatpark/flatpark/pull/844), 2026-10-25 |

## Upstream ships it itself

Upstream publishes the app on Flathub or runs its own Flatpak, or has said it
will. It comes back only if that channel goes away and upstream doesn't object.

| App | ID | Upstream's channel | De-listed |
|-----|----|--------------------|-----------|
| Frame | `io.github._66HEX.Frame` | Flathub, same id | [#151](https://github.com/flatpark/flatpark/pull/151), 2026-07-27 |
| Legcord | `app.legcord.Legcord` | Flathub, same id | [#165](https://github.com/flatpark/flatpark/pull/165), 2026-08-01 |
| Motrix | `app.motrix.native` | Upstream's own Flatpak ([agalwood/Motrix#2171](https://github.com/agalwood/Motrix/issues/2171)) | [#392](https://github.com/flatpark/flatpark/pull/392), 2026-09-21 |
| Gale | `com.kesomannen.gale` | Upstream's own Flatpak; [Kesomannen/gale#763](https://github.com/Kesomannen/gale/issues/763) calls a second listing unnecessary | [#392](https://github.com/flatpark/flatpark/pull/392), 2026-09-21 |
| novelWriter | `io.novelwriter.novelwriter` | The project will ship its own Flatpak ([saga-soft/novelWriter#3049](https://github.com/saga-soft/novelWriter/issues/3049)) | [#511](https://github.com/flatpark/flatpark/pull/511), 2026-10-03 |
| materialgram | `io.github.kukuruzka165.materialgram` | Flathub | [#604](https://github.com/flatpark/flatpark/pull/604), 2026-10-10 |
| Bottles | `com.usebottles.bottles` | Flathub, same id | [#606](https://github.com/flatpark/flatpark/pull/606), 2026-10-10 |
| CodeBurn | `org.agentseal.CodeBurn` | Flathub ([getagentseal/codeburn#1011](https://github.com/getagentseal/codeburn/issues/1011)) | [#985](https://github.com/flatpark/flatpark/pull/985), 2026-11-05 |
| OneKeePass | `io.github.onekeepass.desktop` | The developer publishes it on Flathub as `com.onekeepass.OneKeePass`; the FlatPark listing never had the developer's approval | [#1516](https://github.com/flatpark/flatpark/pull/1516), 2026-11-23 |

## Renamed

The app is still listed, under a new id; only the old id is gone. The old id
never comes back.

| Old id | Listed now as | De-listed |
|--------|---------------|-----------|
| `io.github.houssemko.Grab` | `io.github.linuxuser67.Grab` | [#479](https://github.com/flatpark/flatpark/pull/479), 2026-09-30 |
| `ai.storyteller.printcraft` | `ai.storyteller.pdfcraft` | [#588](https://github.com/flatpark/flatpark/pull/588), 2026-10-09 |
| `rocks.fastpotify.Fastpotify` | `rocks.spotifast.Spotifast` | [#595](https://github.com/flatpark/flatpark/pull/595), 2026-10-10 |
| `com.motrix.next` | `dev.aninsomniacy.rayburst` | [#614](https://github.com/flatpark/flatpark/pull/614), 2026-10-11 |
| `io.github.gloridust.yetease` | `io.github.gloridust.YetEaseMusic` | [#833](https://github.com/flatpark/flatpark/pull/833), 2026-10-24 |
| `io.github.francisreboucas.constructcad` | `io.github.francisreboucas.constructcraft` | [#1093](https://github.com/flatpark/flatpark/pull/1093), 2026-11-09 |
| `com.longbridgeapp.LongbridgePro` | `com.longbridge.Longbridge` | [#1121](https://github.com/flatpark/flatpark/pull/1121), 2026-11-10 |
| `com.kang.nyaterm.preview` | `com.kang.nyaterm` | [#1396](https://github.com/flatpark/flatpark/pull/1396), 2026-11-19 |
| `com.github.zbcoding.Impasto` | `io.github.zbcoding.Impasto` | [#1518](https://github.com/flatpark/flatpark/pull/1518), 2026-11-23 |
| `ely.zacharyzhang.office.doc` | `ely.zacharyzhang.office` (upstream ships the suite as one package since v0.1.17) | [#1590](https://github.com/flatpark/flatpark/pull/1590), 2026-11-26 |
| `ely.zacharyzhang.office.table` | `ely.zacharyzhang.office` (upstream ships the suite as one package since v0.1.17) | [#1590](https://github.com/flatpark/flatpark/pull/1590), 2026-11-26 |
| `ely.zacharyzhang.office.show` | `ely.zacharyzhang.office` (upstream ships the suite as one package since v0.1.17) | [#1590](https://github.com/flatpark/flatpark/pull/1590), 2026-11-26 |
| `ely.zacharyzhang.office.pdf` | `ely.zacharyzhang.office` (upstream ships the suite as one package since v0.1.17) | [#1590](https://github.com/flatpark/flatpark/pull/1590), 2026-11-26 |
| `ely.zacharyzhang.office.mark` | `ely.zacharyzhang.office` (upstream ships the suite as one package since v0.1.17) | [#1590](https://github.com/flatpark/flatpark/pull/1590), 2026-11-26 |
| `ely.zacharyzhang.office.tree` | `ely.zacharyzhang.office` (upstream ships the suite as one package since v0.1.17) | [#1590](https://github.com/flatpark/flatpark/pull/1590), 2026-11-26 |
| `ely.zacharyzhang.office.mail` | `ely.zacharyzhang.office` (upstream ships the suite as one package since v0.1.17) | [#1590](https://github.com/flatpark/flatpark/pull/1590), 2026-11-26 |

## Stopped or broken

Upstream stopped, the download went away, or the package couldn't be made to
work. It can come back once that has changed; the PR that brings it back says
what changed and marks the row here as re-listed.

| App | ID | Why | De-listed |
|-----|----|-----|-----------|
| Musicat | `io.github.basharovV.musicat` | Menus didn't respond to clicks in the packaged build | [#265](https://github.com/flatpark/flatpark/pull/265), 2026-08-26 |
| Wealthfolio | `com.teymz.wealthfolio` | Menus didn't respond to clicks in the packaged build. **Re-listed** in [#500](https://github.com/flatpark/flatpark/pull/500) | [#265](https://github.com/flatpark/flatpark/pull/265), 2026-08-26 |
| BrowserOS | `com.browseros.BrowserOS` | The new payload no longer unpacked, and the Flatpak request upstream was closed as not planned. **Re-listed** in [#1158](https://github.com/flatpark/flatpark/pull/1158) | [#324](https://github.com/flatpark/flatpark/pull/324), 2026-09-08 |
| DevPod | `sh.loft.devpod` | No release since 2025-06 | [#494](https://github.com/flatpark/flatpark/pull/494), 2026-10-03 |
| AB Download Manager | `com.abdownloadmanager.AbDownloadManager` | The tray needed a `getpid()` shim that broke opening files and links, and open-source apps ship unmodified | [#598](https://github.com/flatpark/flatpark/pull/598), 2026-10-10 |
| Harbor Beta | `site.harbor.Harbor.Beta` | Project shut down | [#675](https://github.com/flatpark/flatpark/pull/675), 2026-10-15 |
| MyGo Cloud Music | `dev.egoist.cloudmusic` | Taken down after a letter from NetEase Cloud Music; releases gone | [#975](https://github.com/flatpark/flatpark/pull/975), 2026-11-04 |
| BenchUp | `io.github.BenchUp3D.BenchUp` | Upstream organisation and its releases are gone | [#1371](https://github.com/flatpark/flatpark/pull/1371), 2026-11-19 |
| Horizon | `dev.playhorizon.Horizon` | Upstream repository and its organisation (`horizon-rust`) are gone; the pinned download 404s | [#1599](https://github.com/flatpark/flatpark/pull/1599), 2026-11-26 |
