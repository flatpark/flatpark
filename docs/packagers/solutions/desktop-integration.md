---
description: Windows not grouped, media controls missing, no tray icon, a second instance starting, file associations.
order: 1
---

# Desktop integration

The app runs, but the desktop doesn't treat it as one: its windows land under a
generic icon, media keys do nothing, the tray icon never shows, a second launch
opens a second copy, or double-clicking a file doesn't open it. Each comes down
to a name the desktop and the app have to agree on: a window class, a D-Bus
name, a desktop-file field. Measure the name on the running app and write it
into the package.

## For agents

### Windows not grouped under the app's icon

The desktop matches a window to its launcher through `StartupWMClass` in the
desktop file (X11 `WM_CLASS`, Wayland `app_id`). A wrong value leaves windows
under a generic icon and the launcher looking idle.

- **Measure it**, on X11 with `XQueryTree` and `XGetClassHint` over all windows,
  or with the compositor's client list (`hyprctl clients -j`). Electron main
  windows set only `_NET_WM_NAME`, so a scan that filters on `XFetchName` misses
  them.
- **Electron:** the main window's class is the app's name as Electron sees it
  (`edrlab-thoriumreader`, `min`, `codeburn-desktop`), not the binary name and
  not the app id. It can differ from the name in the UI and from upstream's own
  `.desktop` file (CodeBurn's says `CodeBurn`); the userData directory under
  `~/.var/app/<id>/config/` has the same name, which makes a second check. The
  name of the file the wrapper runs only names an invisible leader window.
- **Branded Chromium browsers** ignore `CHROME_DESKTOP`; the class is hardcoded
  (Brave Origin's is `brave-origin`).
- **Tauri and GTK apps without a GApplication id** take the class from
  `argv[0]`. A `launch` symlink makes it `launch`; name the symlink after the
  app id and set `StartupWMClass` to the same
  ([Flow](../../../registry/io.github.aedev.flow.desktop/apply_extra.sh)).
- **Apps with a compiled GApplication id** use that id (a Flutter template's
  `com.example.<app>`); keep `StartupWMClass` equal to it.

### Media controls (MPRIS) missing

Players register `org.mpris.MediaPlayer2.<name>` on the session bus. Flatpak
lets an app own `org.mpris.MediaPlayer2.<app-id>.*` and nothing else, so any
other name is filtered and media keys and desktop widgets never see the player.
`--log-session-bus` shows `Failed to get the ownership of org.mpris…`.

| Toolkit | Name it registers | Grant |
|---|---|---|
| Electron, Chromium | `org.mpris.MediaPlayer2.chromium.instance2` (sandbox PID 2), only while media plays | `--own-name=org.mpris.MediaPlayer2.chromium.*` ([Folia](../../../registry/top.izuna.foliamajor/top.izuna.foliamajor.yml)) |
| WebKitGTK (Tauri) | `org.mpris.MediaPlayer2.<id>.Sandboxed.instance-N`, where `<id>` is the GApplication id, else the program name if it is a dotted id, else `org.webkit.app-<hash>` | Name the launcher symlink after the app id; no grant needed ([Flow](../../../registry/io.github.aedev.flow.desktop/apply_extra.sh)) |
| Flutter (audio plugins) | `org.mpris.MediaPlayer2.<app-id>.instance2` | Covered by default; a narrower `--own-name=…<app-id>.*` is harmless ([Vynody](../../../registry/io.github.axel10.vynody/io.github.axel10.vynody.yml)) |

- **Test with sound playing.** Chromium registers the name only during
  playback, so an idle launch proves nothing. Start the app with
  `--remote-debugging-port`, play a generated tone through
  `new Audio(blobURL)` over CDP, and watch `busctl --user list`.
- **Cover art missing:** Chromium writes the art to `$TMPDIR` and hands the
  desktop a `file://` URL, and the sandbox's `/tmp` is private. Set
  `TMPDIR="$XDG_RUNTIME_DIR/app/$FLATPAK_ID"` in the wrapper, a path that is
  the same inside and outside; never grant `/tmp`.

### Tray icon missing

Tray icons use the StatusNotifierItem protocol: the app owns a name and
registers it with `org.kde.StatusNotifierWatcher`. Every tray app needs
`--talk-name=org.kde.StatusNotifierWatcher`; what it owns depends on the
toolkit:

| Toolkit | Needs |
|---|---|
| Tauri `tray-icon` | libayatana-appindicator, which the GNOME runtime lacks: the `ayatana-stack` [prebuilt](../prebuilt.md), plus `--filesystem=xdg-run/tray-icon:create` for the icon files ([AeroFTP](../../../registry/com.aeroftp.AeroFTP/com.aeroftp.AeroFTP.yml)). Without the library, `tray-icon` panics at start. |
| Flutter `tray_manager` / desktop tray plugin | `--own-name=org.fluttertray.*` ([Vynody](../../../registry/io.github.axel10.vynody/io.github.axel10.vynody.yml)) |
| Avalonia (.NET) | Owns `org.kde.StatusNotifierItem-2-0`: `--own-name=org.kde.*` ([XerahS](../../../registry/com.xerahs.XerahS/com.xerahs.XerahS.yml)) |
| Qt 6 (Enpass 6.12), Electron 45 and later, Chromium 155 and later | Register under their unique connection name; the watcher grant alone is enough |
| Wails v3 | Unique connection name; the watcher grant alone |

Check with `--log-session-bus` and `busctl --user list | grep StatusNotifier`.
A Tauri app that uses `tray-icon` only as a symbol from Tauri's own ACL table
has no tray; look for `TrayIconBuilder` in its source before adding the stack.

### A second launch starts a second copy

Single-instance apps own a well-known name on the session bus; a second launch
finds it taken and hands its arguments over. If the package doesn't grant that
name, the first instance can't own it, and every launch starts a full copy.
Nothing logs an error.

- **tauri-plugin-single-instance 2.4 and later** owns
  `<tauri identifier>.SingleInstance` exactly; older versions used
  `org.<identifier with . and - as _>.SingleInstance`. Check the version in
  upstream's `Cargo.lock` and grant that name.
- **A compiled GApplication id different from the Flatpak id** (a Flutter app
  still on the template's `com.example.<app>`, a Wails app's `org.wails.<name>`):
  `g_application_register` is refused and the app may exit silently. Grant
  `--own-name=<compiled id>`.
- Test by launching twice: the second should exit at once, and
  `busctl --user list` shows one owner.

### Opening files from the file manager

- In the desktop file, put only `%f`, `%F`, `%u` or `%U` in `Exec=`. Flatpak
  adds `--file-forwarding` and the `@@ … @@` markers itself when it exports the
  file; writing them yourself makes the install fail
  (`Invalid Exec argument @@u`), and `--file-forwarding` isn't a `finish-args`
  option.
- `%U` hands the app a `file:///run/user/…/doc/…` URI and `%F` a plain path.
  Many apps that parse `argv` themselves only understand paths; test which one
  the app accepts.
- Forwarded files arrive through the document portal, so no `--filesystem`
  grant is needed for them.

### Apps that write desktop entries or autostart files

Some apps register a URL handler or a login item by writing a `.desktop` file
with `Exec=/app/extra/…`, which is a broken path on the host. Mask the
directories they write to, `--nofilesystem=xdg-data/applications` and
`--nofilesystem=xdg-config/autostart`, when the package otherwise grants home;
launch at login is a feature the sandbox can't offer that way. A Wine prefix's
installer can also drop shortcuts on the host's desktop unless the prefix's
desktop folder is redirected inside the sandbox.
