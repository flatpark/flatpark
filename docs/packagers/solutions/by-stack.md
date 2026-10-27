---
description: A checklist per stack (Electron, Chromium browsers, Tauri, Wails, GPUI, Slint, Flutter, Qt, .NET, Java, Wine) of what to set and what to test.
order: 5
---

# By stack

Apps built the same way break the same way. Find the app's stack (the `.deb`'s
dependencies, `readelf -d` on the binary and `strings` usually tell), then go
through its list: what to put in the manifest and wrapper, and what to test
before the PR. Each item links to the page that explains it.

## For agents

### Electron

- Runtime `org.freedesktop.Platform`, `base: org.electronjs.Electron2.BaseApp`
  at the same version; start with `zypak-wrapper <binary> --ozone-platform-hint=auto "$@"`
  ([Folo](../../../registry/is.folo.Folo/folo-wrapper)).
- `unset ELECTRON_RUN_AS_NODE` in the wrapper. A few apps exit on any
  `ELECTRON_*` variable (VS Code's terminal exports
  `ELECTRON_NO_ATTACH_CONSOLE`); clear them all for those. Test with
  `env -u ELECTRON_RUN_AS_NODE -u ELECTRON_NO_ATTACH_CONSOLE flatpak run …`
  from an IDE terminal, or the test fails for a reason users never hit.
- `StartupWMClass`: measured; it is the product name
  ([desktop integration](desktop-integration.md#windows-not-grouped-under-the-apps-icon)).
- `export TMPDIR="$XDG_RUNTIME_DIR/app/$FLATPAK_ID"` in the wrapper if the app
  has a tray icon or plays media. Chromium writes the tray icon and the cover
  art to files in `$TMPDIR` and hands the desktop their paths, which the host
  can't read in the sandbox's private `/tmp`
  ([tray placeholder](desktop-integration.md#tray-icon-shows-a-placeholder)).
- Media: `--own-name=org.mpris.MediaPlayer2.chromium.*`, if the app plays media
  ([media controls](desktop-integration.md#media-controls-mpris-missing)).
- Saved passwords on Hyprland and Sway: `--password-store=gnome-libsecret`
  ([keyrings](system-services.md#saved-passwords-and-keyrings)).
- Data in a `~/.dotdir` (`os.homedir()`): grant it with `:create` or `--persist`
  ([permissions](../permissions.md#home-directory-dotdirs)).
- A setuid `chrome-sandbox` in a `.deb`: clear the bit (`chmod -R a-s`).
- Seeding an electron-store config (to switch the updater off, say): it merges
  with the defaults at the top level only, so `{"options":{"autoUpdates":false}}`
  replaces the whole `options` object and the app may not open. Seed the full
  block for the version shipped.
- electron-builder `.deb` vs AppImage: the `.deb` ships `resources/package-type`,
  which makes electron-updater try to install `.deb` updates. The AppImage tree
  has no such file, and with no `APPIMAGE` variable set the updater stays off,
  so prefer the AppImage when upstream offers both
  ([P3X OneNote](../../../registry/com.patrikx3.onenote/flatpark.yml)).

### Chromium-based browsers

- Same base and zypak as Electron, plus `CHROME_WRAPPER`,
  `ZYPAK_SPAWN_LATEST_ON_REEXEC=1` and `ZYPAK_EXPOSE_WIDEVINE_PATH`
  ([zypak](sandboxes-and-updaters.md#chromium-and-electron-zypak)).
- Check the profile directory name the browser really uses before pointing
  anything at it; branded builds differ from the main product.
- `StartupWMClass` measured; `CHROME_DESKTOP` is ignored by branded builds.
- User flags: read a `<name>-flags.conf` from the app's config directory in the
  wrapper, the way native packages do.

### Tauri (WebKitGTK)

- Runtime `org.gnome.Platform`. Keep the `.deb`'s `usr` tree whole when it has
  `usr/lib/<Name>/` ([Debian packages](../formats/deb.md#what-to-keep)).
- Rendering: `WEBKIT_DISABLE_DMABUF_RENDERER=1`, unless the window is
  `transparent` or the app crashes on GNOME 51, then `:-0`
  ([WebKitGTK](rendering-and-fonts.md#webkitgtk-tauri-wails-blank-see-through-or-crashing)).
- Name the launcher symlink after the app id, and use it as `StartupWMClass`
  ([Flow](../../../registry/io.github.aedev.flow.desktop/apply_extra.sh)).
- Tray: the `ayatana-stack` prebuilt and `xdg-run/tray-icon:create`, only if it
  really has a tray ([tray](desktop-integration.md#tray-icon-missing)).
- Clipboard plugin: `--socket=x11` ([copy and paste](system-services.md#copy-and-paste)).
- Single instance: grant `<identifier>.SingleInstance`
  ([second instance](desktop-integration.md#a-second-launch-starts-a-second-copy)).
- Updater plugin: can't be turned off from outside
  ([updaters](sandboxes-and-updaters.md#in-app-updaters)).
- Use the `identifier` in `tauri.conf.json` as the app id.

### Wails v3

- Links WebKitGTK 6 and GTK 4, so `org.gnome.Platform` even if the `.deb` says
  webkit2gtk-4.1.
- Aborts at start unless the app's `Linux.ApplicationID` is the Flatpak id
  ([WebKitGTK 6](sandboxes-and-updaters.md#webkitgtk-6-wails-v3)).
- Tray uses the unique connection name; only the watcher grant.

### GPUI (Zed-style) and other cosmic-text apps

- A shipped `fonts.conf` listing every font directory, and `FONTCONFIG_FILE`
  pointing at it ([fonts](rendering-and-fonts.md#boxes-instead-of-characters-cjk-and-other-scripts)).
- `--talk-name=org.a11y.Bus` ([accessibility](system-services.md#accessibility)).
- `--device=dri` for GPU rendering.

### Slint

- Check the Slint version in the binary first: up to 1.16 needs both the
  `fonts.conf` and `SLINT_DEFAULT_FONT=<directory>`; 1.17 and later needs only
  `SLINT_FONT_PATH=<directory>` ([fonts](rendering-and-fonts.md#boxes-instead-of-characters-cjk-and-other-scripts)).
- `SLINT_BACKEND=winit-software` as a documented override for GPUs where
  rendering fails ([meatshell](../../../registry/io.github.yituorou.meatshell/meatshell-wrapper)).

### Flutter

- Usually a relocatable bundle in a tarball; the freedesktop runtime is enough.
  Tarballs often record a real uid: `--no-same-owner`
  ([Vynody](../../../registry/io.github.axel10.vynody/apply_extra.sh)).
- A compiled GApplication id different from the Flatpak id needs
  `--own-name=<compiled id>`, or the app exits silently
  ([second instance](desktop-integration.md#a-second-launch-starts-a-second-copy)).
- Tray: `--own-name=org.fluttertray.*`; MPRIS uses an app-id prefix.
- File associations: usually `%F`; many Flutter apps don't parse `file://` URIs
  ([opening files](desktop-integration.md#opening-files-from-the-file-manager)).
- Fonts work through fontconfig; no `fonts.conf` needed.

### Qt

- Prefer an AppImage that carries its own Qt on the freedesktop runtime over a
  `.deb` linked to the system Qt ([choosing a format](../formats/README.md#the-qt-exception)).
- Bundled Qt with only the `xcb` plugin: `--socket=x11`,
  `--unset-env=QT_QPA_PLATFORM`, `QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"`
  ([Mark Shot](../../../registry/io.github.jswysnemc.MarkShot/mark-shot-wrapper)).
- A bundled Qt may lack the portal platform theme; its file dialogs then see
  only the granted folders.

### .NET

- Self-contained .NET 5 and older look for OpenSSL 1.1 and abort on a runtime
  with only OpenSSL 3 ("No usable version of libssl"): the
  `openssl-1.1-compat` [prebuilt](../prebuilt.md), appended **last** to
  `LD_LIBRARY_PATH`. Check `tfm` in `<App>.runtimeconfig.json`; .NET 6 and later
  don't need it.
- Never delete a file listed in `<App>.deps.json`, even an unused native
  library: the host checks every entry at start and aborts if one is missing.
- Avalonia tray: `--own-name=org.kde.*` ([tray](desktop-integration.md#tray-icon-missing)).

### Java

- Use the JRE upstream bundles, if it does; otherwise pin a JRE (Zulu,
  Temurin) as a second extra-data download and point the launcher at it.
- `user.home` is the real `$HOME`, not redirected: settings in a `~/.app` or
  `~/.config/<app>` directory need `--persist` or a grant
  ([permissions](../permissions.md#home-directory-dotdirs)).
- An embedded Chromium (JxBrowser, JCEF) brings the nested-sandbox problem
  ([embedded Chromium](sandboxes-and-updaters.md#other-embedded-chromium-cef-jxbrowser)).
- HiDPI: `-Dsun.java2d.uiScale` in the app's options file, or the app's own
  setting.

### Windows apps (Wine)

- Packaged on [Cellar](../../../registry/org.flatpark.Cellar/org.flatpark.Cellar.yml):
  the vendor's Windows installer is the managed extra-data download, and
  `cellar-cli` a second, fixed one outside the managed block. Cellar runs the
  installer, unmodified, into the user's prefix on first launch.
- Wine is not bundled: it is `org.winehq.Wine` from Flathub, one install every
  Wine app shares. Grant its install paths read-only
  (`~/.local/share/flatpak/app/org.winehq.Wine:ro` and
  `/var/lib/flatpak/app/org.winehq.Wine:ro`), keep the runtime on the
  version its branch is built on (`stable-26.08` on 26.08), and list it under
  `requires:` in `flatpark.yml`. Cellar shows the install command in a dialog
  when it is missing.
- Grant the folders the app works in (`xdg-music` for a player), not home.
- Redirect the prefix's desktop folder into the sandbox, or installers drop
  shortcuts on the host's desktop.
- Text in boxes in a WPF, CEF or Electron window while GDI text is fine: those
  go through DirectWrite, which only sees fonts registered under
  `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts`. Cellar registers
  the fonts it installs; a font copied into `C:\windows\Fonts` by hand isn't.
- WPF falls back to a physical Arial and crashes in `TypefaceMap` without one,
  so a WPF app's prefix needs the Microsoft core fonts, not Liberation
  (`[fonts] core = "microsoft"`). If it flickers under wined3d, set
  `HKCU\Software\Microsoft\Avalon.Graphics` `DisableHWAcceleration=1`.
- Hebrew, Thai and Sinhala drawn as boxes under a CJK UI font is a Wine
  limit, not the package: GDI shapes complex scripts against the base font only
  and falls back to font linking just when the font lacks the script.
- Every Wine command against a prefix runs with that prefix's `LC_ALL`. Wine
  started under another locale rewrites the font-link defaults when its code
  page changes; the Flatpak's `LC_CTYPE=C.UTF-8` alone means code page 1252.
