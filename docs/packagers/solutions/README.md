---
description: Problems packages run into inside the sandbox, what causes them, and the fixes that have worked, by symptom and by stack.
order: 6
---

# Common problems

Most of what goes wrong in a package has gone wrong before. These pages collect
the problems FlatPark packages have hit, each with how to recognise it, why it
happens, and the fix that worked, with a package that does it.

Start from the symptom:

- [Desktop integration](desktop-integration.md): windows not grouped, no media
  controls, no tray icon, a second instance, file associations.
- [Rendering and fonts](rendering-and-fonts.md): blank or transparent windows,
  crashes when switching views, tiny UI, boxes instead of characters.
- [Clipboard, secrets and system services](system-services.md): copy and paste,
  saved passwords, keyrings, screen capture, accessibility.
- [Nested sandboxes and updaters](sandboxes-and-updaters.md): an app's own
  sandbox, an in-app updater, apps that manage the host.
- [By stack](by-stack.md): a checklist for Electron, Chromium browsers, Tauri,
  Wails, GPUI, Slint, Flutter, Qt, .NET, Java and Wine apps.

Two rules apply to every fix here:

- **Fix from the outside.** Wrapper variables and flags, `finish-args`, extra
  downloads and prebuilt stacks are fine for any app. Injecting code or changing
  the vendor's files is never done to an open-source app, and only as a last,
  declared resort for a closed-source one ([permissions](../permissions.md#declaring-changes-to-how-the-app-runs)).
- **Stop when workarounds pile up.** One workaround is normal; a second or third
  for the same app means stop and ask whether it should be listed at all.

## For agents

### Diagnosing

- **Run it in the sandbox, not on the host.** `flatpak run --command=sh <app-id>`
  gives a shell with the app's exact sandbox; `flatpak enter <app-id> sh` joins
  a running one.
- **D-Bus problems are silent.** `flatpak run --log-session-bus <app-id>` prints
  every call the bus proxy filters (`Filtering message due to arg0`, failed
  `RequestName`). Missing tray icons, media controls and second instances
  almost always show up here.
- **Read the binary before guessing.** `strings` finds environment variables
  the app reads (`SLINT_*`, `<APP>_UI_FONT`, `WEBKIT_*`), D-Bus names it owns
  (`org.SingleInstance.DBus`), and the toolkit version. Rust apps built with
  `tracing` take `--env=RUST_LOG=<crate>=debug`.
- **Measure, don't derive.** Window classes, bus names and file paths differ
  from what the vendor's desktop file or docs say often enough that every
  value written into a package is checked on the running app.
- **Compare with a real control.** To prove a setting is unnecessary, build
  without it; don't point the app at a different value, which can take another
  path entirely.
- **Check global overrides first** when a test shows a permission the package
  doesn't grant: `cat ~/.local/share/flatpak/overrides/global`.
- **Test on a private display.** A rootful `Xwayland :99` accepts XTEST input
  and screenshots; run the app with the host's `DISPLAY=:99` (not
  `--env=DISPLAY`), and stop the display when done.
