---
description: Blank or see-through windows, web views that crash, an interface that is too small, and boxes instead of characters.
order: 2
---

# Rendering and fonts

Drawing problems inside the sandbox mostly come from three places: WebKitGTK's
rendering paths, apps that work out the screen's size themselves, and toolkits
that look for fonts their own way instead of asking fontconfig. The fixes are
environment variables and a fonts configuration shipped with the package; check
which toolkit the app uses before copying a fix from another one.

## For agents

### WebKitGTK (Tauri, Wails): blank, see-through, or crashing

| Symptom | Cause | Fix |
|---|---|---|
| The window opens blank or white on some GPUs | WebKitGTK's DMABUF renderer fails in the sandbox with many drivers | `export WEBKIT_DISABLE_DMABUF_RENDERER=1` in the wrapper ([Tabularis](../../../registry/dev.tabularis.Tabularis/tabularis-wrapper)) |
| On GNOME 51 a `transparent: true` window shows the desktop through it, all of it or only the parts that haven't changed; content only flashes while scrolling | Most likely WebKitGTK 2.54's compositor, which redraws only each frame's damaged regions: a transparent window shows the desktop wherever nothing was redrawn (Rayburst's upstream traced it there). How often depends on the app and on the acceleration setting; see below | Lowers the odds, doesn't fix it: keep acceleration on, `WEBKIT_DISABLE_DMABUF_RENDERER="${WEBKIT_DISABLE_DMABUF_RENDERER:-0}"` and the same for `WEBKIT_DISABLE_COMPOSITING_MODE` ([ArtCraft](../../../registry/ai.artcraft.app/artcraft-wrapper)) |
| On GNOME 51 an opaque window's web content dies when switching views; afterwards every start shows an empty window | The same unaccelerated path crashes `WebKitWebProcess`; the crash leaves IndexedDB in a state that kills it on every start | Same fix. To recover a user, delete `~/.var/app/<id>/data/<tauri identifier>/databases` |

- Check the app's `src-tauri/tauri.conf.json` for `transparent` before choosing
  between the first two rows. An opaque window takes the first row, even if a
  similar app uses the second.
- The transparent-window fault is intermittent, so one clean start proves
  nothing; launch each setting several times. Measured on WebKitGTK 2.54.1
  (GNOME 51, Intel, Hyprland), as see-through starts out of the total:

  | App | Acceleration on | Off (`DMABUF=1`) |
  |---|---|---|
  | ArtCraft | 0/4 | 4/4 |
  | mDNS Browser | 0/3 | 2/3 |
  | Sigma File Manager, Cockpit Tools | 0/5 | 1/5 |
  | Lap 0.3.3 (opaque on Linux since 0.4.1) | 2/3 | 0/3 |

  No environment variable fixes it. The app has to turn off WebKit's
  `UseDamagingInformationForCompositing` feature through `WebKitSettings`, as
  Rayburst does (`src-tauri/src/webkit.rs`; rayburst#650, #705), or use an
  opaque window. Point upstream at that.
- WebKit reads these variables by value, so `0` means "don't disable". Writing
  them as `${VAR:-0}` leaves `flatpak override --env=VAR=1` to the user.
- To see whether the web process is alive: `cat /proc/<app pid>/task/*/children`.
  Only a `WebKitNetworkProcess` left means the content process died.
- Forcing X11 (`GDK_BACKEND=x11`) doesn't help with any of these; they are not
  Wayland problems.
- Some apps set these variables themselves before GTK starts, and then a
  wrapper export is overwritten. Rayburst 4.1.2 removes
  `WEBKIT_DISABLE_DMABUF_RENDERER`, forces DMA-BUF in shared-memory mode and
  paints on the CPU unless its own "hardware rendering" setting is on
  (`src-tauri/src/webkit.rs`). Grep the app's startup code for `WEBKIT_`
  before adding a wrapper variable, and test with none set
  (`flatpak run --command=<binary>`) as well.

### The interface is tiny on a HiDPI screen

- **GTK apps:** `GDK_SCALE=2` (integer) or the desktop's scaling.
- **Qt apps:** `QT_SCALE_FACTOR`; a Qt build with only the `xcb` plugin runs
  through XWayland and follows `Xft.dpi`.
- **Java apps:** `-Dsun.java2d.uiScale=<n>` in the app's options, or the app's
  own variable.
- **Apps that compute DPI from the screen's size in millimetres** (X11 only)
  ignore all of the above: XWayland always reports a size that works out to
  96 dpi. An app-specific setting is the fix when one exists; an `LD_PRELOAD`
  library that answers `XDisplayWidthMM` from `Xft.dpi` works, but injects code
  and is for closed-source apps only, declared.
- Document the variable in the metainfo as a `flatpak override --env=…`
  command; don't set a fixed scale for everyone.

### Boxes instead of characters (CJK and other scripts)

The runtime has no CJK fonts. The host's fonts reach the sandbox under
`/run/host/fonts`, and the runtime's `/etc/fonts/fonts.conf` points there
through `conf.d/50-flatpak.conf`. Toolkits that use libfontconfig find them;
toolkits that read font directories themselves don't.

| Toolkit | Behaviour | Fix |
|---|---|---|
| GTK, Qt, Electron, Flutter | Real fontconfig, follows includes | Nothing; host fonts work |
| GPUI (Zed-style) and other cosmic-text / fontdb apps (iced, winit) | Parses **one** fontconfig file and only its `<dir>` entries, no includes | Ship a `fonts.conf` listing every directory: `/usr/share/fonts`, `/run/host/fonts`, `/run/host/local-fonts`, `/run/host/user-fonts`, `<dir prefix="xdg">fonts</dir>`, `~/.fonts`, and any font shipped as extra-data; `export FONTCONFIG_FILE` to it unconditionally ([Navop](../../../registry/dev.navop.Navop/navop-wrapper)) |
| Slint up to 1.16 | Two font databases: the app's fontdb (as above) and Slint's own, which scans only `/usr/share/fonts` and `~/.fonts` | Both: the `fonts.conf` above, and `SLINT_DEFAULT_FONT=<directory with a CJK font>` ([meatshell](../../../registry/io.github.yituorou.meatshell/meatshell-wrapper)) |
| Slint 1.17 and later | Uses real fontconfig, but its fallback chain needs a directory | `SLINT_FONT_PATH=<directory>`; `SLINT_DEFAULT_FONT` now takes a single file and silently ignores a directory |

- If a CJK font must ship with the package, pin the `noto-fonts`
  [prebuilt stack](../prebuilt.md) as extra-data, never a font CDN (a jsDelivr
  pin went 404 and broke every app using it, [#1316](https://github.com/flatpark/flatpark/issues/1316)). `apply_extra.sh` unpacks
  it with `bsdtar --no-same-owner -xf noto-fonts.tar.xz`, and `fonts.conf` or
  the Slint variable names `/app/extra/noto-fonts/share/fonts`
  ([FluxDown](../../../registry/com.fluxdown.app/apply_extra.sh)). A face it
  lacks is added to the stack under a new tag.
- Override `FONTCONFIG_FILE` unconditionally: a user's own value is exactly what
  breaks it. Offer an app-specific escape (`NAVOP_FONTCONFIG_FILE`).
- `fc-list` inside the sandbox listing the font proves nothing for these
  toolkits; look at the rendered window.
- The app's log often says which font it chose (`RUST_LOG=<crate>=debug`);
  a correct family name with boxes on screen means the second database (Slint)
  is the problem.

### Crash at start inside fontconfig

A SIGSEGV before any window, with `FT_Set_Var_Design_Coordinates` and
`tt_apply_mvar` in the stack: the binary carries its own FreeType
(`nm -D --defined-only <binary> | grep -c ' FT_'` is non-zero), and the
runtime's fontconfig ends up mixing two FreeTypes. Ordinary fonts work;
variable fonts crash.

Ship a `fonts.conf` that includes `/etc/fonts/fonts.conf` and rejects variable
fonts (`<rejectfont>` with globs `*-VF.*`, `*_VF.*`, `*[*]*`, `*Variable*`),
point `FONTCONFIG_FILE` at it, and run `fc-cache` before the app starts:
`<rejectfont>` only applies when fonts are added to the set, and the sandbox
rescans host fonts whose cache it can't use.
