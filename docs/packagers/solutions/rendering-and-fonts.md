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
| On GNOME 51 a `transparent: true` window shows the desktop through it; content only flashes while scrolling | Without acceleration, WebKit on GNOME 51 doesn't paint a transparent window's background | The opposite of the above: keep acceleration on, `WEBKIT_DISABLE_DMABUF_RENDERER="${WEBKIT_DISABLE_DMABUF_RENDERER:-0}"` and the same for `WEBKIT_DISABLE_COMPOSITING_MODE` ([Rayburst](../../../registry/dev.aninsomniacy.rayburst/rayburst-wrapper)) |
| On GNOME 51 an opaque window's web content dies when switching views; afterwards every start shows an empty window | The same unaccelerated path crashes `WebKitWebProcess`; the crash leaves IndexedDB in a state that kills it on every start | Same fix. To recover a user, delete `~/.var/app/<id>/data/<tauri identifier>/databases` |

- Check the app's `src-tauri/tauri.conf.json` for `transparent` before choosing
  between the first two rows.
- WebKit reads these variables by value, so `0` means "don't disable". Writing
  them as `${VAR:-0}` leaves `flatpak override --env=VAR=1` to the user.
- To see whether the web process is alive: `cat /proc/<app pid>/task/*/children`.
  Only a `WebKitNetworkProcess` left means the content process died.
- Forcing X11 (`GDK_BACKEND=x11`) doesn't help with any of these; they are not
  Wayland problems.
- Some apps add their own GPU guard that reads a preference and turns
  acceleration off by default; setting both variables in the wrapper makes it
  stand aside (Rayburst logs `external WebKitGTK rendering override`).

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

- If a CJK font must ship with the package, pin it as extra-data; it is tens of
  megabytes.
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
