---
description: Copy and paste, saved passwords and keyrings, screen capture, accessibility, and host commands.
order: 3
---

# Clipboard, secrets and system services

Apps reach many desktop services through the session bus or a socket, and the
sandbox passes on only what the package grants. A missing grant rarely shows as
an error: paste does nothing, a password isn't saved, a recording fails with a
vague message. The fixes below are grants and launch flags; none of them
change the app.

## For agents

### Copy and paste

| Symptom | Cause | Fix |
|---|---|---|
| A Tauri app with `tauri-plugin-clipboard-manager` can't paste or copy images; text may work or not | The plugin uses arboard, which tries Wayland's data-control protocol first. Flatpak's Wayland socket filters privileged protocols, data-control included, so arboard falls back to X11, and `--socket=fallback-x11` withholds X11 on a Wayland session | `--socket=x11` instead of `fallback-x11`. The window stays Wayland-native |
| A Tauri app with the third-party `tauri-plugin-clipboard` exits at start with `DisplayNotSet` | That plugin opens an X11 display when it starts and panics without one | `--socket=x11` |
| An egui app pastes text but not images | egui's text clipboard uses the plain Wayland data device; only images go through arboard | `fallback-x11` can stay; document `--socket=x11` as an override |

Check the app's `src-tauri/Cargo.toml` for a clipboard crate before choosing
the socket, and verify with
`flatpak run --command=sh <app-id> -c 'echo $DISPLAY'` (empty means no X11).
This is not compositor-specific; the same build behaves the same everywhere.

### Saved passwords and keyrings

- **Secret Service** (`org.freedesktop.secrets`, served by GNOME Keyring or
  KWallet) is how sandboxed apps store secrets: `--talk-name=org.freedesktop.secrets`.
- **Electron and Chromium on an unrecognised desktop** (Hyprland, Sway, …):
  `safeStorage` picks its backend from `XDG_CURRENT_DESKTOP`, falls back to
  plain text, and reports "Encryption is not available", so saving a password
  fails even with the grant. A native install behaves the same. Pass
  `--password-store=gnome-libsecret` from the wrapper on desktops other than
  KDE, unless the user already passed one (Min's wrapper does this).
- **The kernel keyring** (`keyctl`, `add_key`; the Rust `keyring` crate's
  `linux-native` backend) is blocked by Flatpak's seccomp filter. An app using
  only that backend can't store secrets in a Flatpak; the fix is upstream
  switching to Secret Service.
- When testing, look for a new item over Secret Service and delete test items
  afterwards.

### Screen capture and recording

- Screenshots and screen sharing go through the Screenshot and ScreenCast
  portals and need no grant. The user's answers are kept in the
  [permission store](../../users/permission-store.md).
- An app that records the PipeWire node by connecting to the default PipeWire
  socket itself (for example by spawning `gst-launch-1.0 pipewiresrc path=<node>`)
  rather than through the fd the portal hands out needs
  `--filesystem=xdg-run/pipewire-0` ([XerahS](../../../registry/com.xerahs.XerahS/com.xerahs.XerahS.yml)).
- The runtime's FFmpeg has no `-f pipewire` input; an app that needs one records
  through GStreamer instead.
- Apps that capture by their own X11 calls get only XWayland windows; a
  Wayland desktop needs the portal path.

### Accessibility

Apps built on AccessKit (GPUI and many Rust toolkits) ask `org.a11y.Bus` where
the accessibility bus is. Without `--talk-name=org.a11y.Bus` screen readers
don't see the window. Grant it when the binary carries `org.a11y.atspi` or
`accesskit` symbols ([Navop](../../../registry/dev.navop.Navop/dev.navop.Navop.yml)).

### Commands on the host

An app that needs a host program (`git`, `lsof`, a CLI it manages) can't run it
from the sandbox. A small script on `PATH` that runs the real command with
`flatpak-spawn --host` works, at the cost of `--talk-name=org.freedesktop.Flatpak`,
which lets the app run anything on the host: declare it as `host-command` and
argue for it in the PR ([permissions](../permissions.md#declaring-high-risk-permissions)).
Keep detection inside the sandbox: an app that checks whether a tool is
installed should see the sandbox's answer, and only the actual run goes to the
host.

Things that don't work from a Flatpak however it is granted: seeing host
processes (`pgrep`, `/proc`), and launching at login through the app's own
autostart file.
