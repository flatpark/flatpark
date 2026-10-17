---
description: Which of upstream's downloads to package, and which runtime goes with it.
order: 3
---

# Choosing a format

Most upstreams publish the same release several ways. Pick one download, and the
runtime follows from what that download brings with it.

**Prefer the tarball** (or zip). It is the build upstream made to run from its
own directory on any distribution, so it unpacks into one tree that works where
it lands. A `.deb` is the next choice: usually the same files, laid out for a
distribution. An AppImage carries the most with it and needs an extra tool to
open, so it comes last, with one exception: **Qt apps**, where the AppImage is
often the better choice.

| Format | Unpack | Runtime it usually needs | Page |
|---|---|---|---|
| tar / zip | `bsdtar` | Whatever the app links: freedesktop for Electron and self-contained builds, GNOME for GTK and WebKitGTK | [Tarballs and zips](tar.md) |
| `.deb` | `bsdtar` twice | Same; GNOME for Tauri | [Debian packages](deb.md) |
| AppImage | `appimage-tools` from prebuilt | freedesktop: it brings its own toolkit | [AppImages](appimage.md) |
| `.rpm` | `bsdtar` | Same as `.deb` | [Debian packages](deb.md#rpm) |

## The Qt exception

A Qt app's tarball or `.deb` is linked against a system Qt, so it needs
`org.kde.Platform`. That is a large runtime most users don't have, and only one
app in the catalog uses it. Worse, a Qt binary built for a distribution often
crashes on the KDE runtime's Qt (see the details below). If upstream also ships
an AppImage that **carries its own Qt**, unpack that instead and run it on
`org.freedesktop.Platform`: nothing Qt comes from the runtime, and the app needs
only the small base every Flatpak user already has.

The reference package is
[Mark Shot](../../../registry/io.github.jswysnemc.MarkShot/io.github.jswysnemc.MarkShot.yml)
(Qt 6); its manifest explains each choice.

## For agents

### Choosing the runtime

| The payload | Runtime | Examples |
|---|---|---|
| Electron or another bundled Chromium | `org.freedesktop.Platform` 26.08 + `base: org.electronjs.Electron2.BaseApp` | [Folo](../../../registry/is.folo.Folo/is.folo.Folo.yml), [Electerm](../../../registry/org.electerm.Electerm/org.electerm.Electerm.yml) |
| Self-contained (its own toolkit or Qt) | `org.freedesktop.Platform` 26.08 | Mark Shot, [Compass](../../../registry/org.tunaos.compass/org.tunaos.compass.yml) |
| GTK 3/4, libadwaita, WebKitGTK (Tauri, Wails) | `org.gnome.Platform` 51 | [Tabularis](../../../registry/dev.tabularis.Tabularis/dev.tabularis.Tabularis.yml), [Grab](../../../registry/io.github.linuxuser67.Grab/io.github.linuxuser67.Grab.yml) |
| Linked to a system Qt, no self-contained build | `org.kde.Platform` 6.11, only after testing | [HeidiSQL](../../../registry/com.heidisql.HeidiSQL/com.heidisql.HeidiSQL.yml) |

Find what the binary links before choosing: unpack the download and run
`readelf -d <binary> | grep NEEDED` on the main binary and its bundled
libraries. Every `NEEDED` library has to come from the runtime, the
payload, or `flatpark/prebuilt`. Choose the smallest runtime that covers them;
GNOME and KDE are both much larger than freedesktop, and an app is only worth
one if it uses what they add.

### Why a distribution's Qt binary fails on the KDE runtime

A Qt executable built by a distribution carries `R_X86_64_COPY` relocations for
`QCoreApplication::self` and for the `staticMetaObject` of `QObject`, `QWidget`
and the app's own classes. The KDE runtime's Qt reads and writes its own copies
of those instead of going through the GOT, so the two diverge: the process dies
in `QApplication`'s constructor, and once past that, `qobject_cast` inside the
Qt libraries stops matching — windows close as soon as they open. Environment
variables don't reach it. A self-contained payload never consults the runtime's
Qt and is unaffected. Mark Shot's manifest has the full trace.

HeidiSQL works on the KDE runtime because it is a Lazarus app talking to Qt
through `libQt6Pas`, not a C++ Qt program; it is the exception, not a model.

### Things to check in a self-contained AppImage

- **Which Qt platform plugins it ships.** Many carry only `xcb`. Then use
  `--socket=x11` (not `fallback-x11`, which withholds X11 on a Wayland session),
  `--unset-env=QT_QPA_PLATFORM` in `finish-args`, and
  `QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"` in the wrapper, so a user override
  still wins. Qt 5 bundles often ship the Wayland plugin without
  `libQt5WaylandClient`, which fails the same way; pin those to `xcb` too.
- **What it deliberately leaves out.** AppImages leave the display, GL, fonts,
  glib and audio stacks to the host. Those are exactly what the freedesktop
  runtime provides, which is why it is enough.
- **Whether its launcher sets library paths.** Some AppImages rely on `AppRun`
  to set `LD_LIBRARY_PATH` or `QT_PLUGIN_PATH`. Read it, and reproduce the
  same variables in the wrapper; don't run `AppRun` itself unless it is a
  plain shell script that only sets variables.

### When upstream ships something else

- **Only an installer script or `.run` file:** extract what it would install
  without running it (many are a shell header on a tarball). If it can only be
  run, running it unmodified at first launch is not a change; if it only works
  with parts stood in for (a fake `df`, a patched check), the package is
  [Modified](../../project/trust.md#packaging-changes) and closed-source only.
- **Only a Windows installer:** packaged on top of
  [Cellar](../../../registry/org.flatpark.Cellar/org.flatpark.Cellar.yml),
  FlatPark's Wine runner.
- **Only source:** not packageable here; see the [limits](../basics.md#limits).
