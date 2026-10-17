---
description: The checks every new listing and every change we make to a package goes through before it ships, and how to run each one.
order: 2
---

# Testing playbook

FlatPark doesn't put a human review on every listing and update; it tests
instead. Every **new listing**, and every **change we make to a package**
(permissions, runtime, wrapper, build steps, prebuilt stacks), goes through the
checks below before its PR merges. A version bump from upstream only goes
through the first one, automatically.

Each check exists because something shipped broken without it; the
[incident list](../reference/incidents.md) names which. The record shows that
fixing is fast and finding is slow: data loss appears only after a restart, a
crash only after pressing play. So the checks are about doing those things
before users do.

| Check | Catches |
|---|---|
| [It unpacks as a system install](#it-unpacks-as-a-system-install) | Wrong size, `chown` as root, renamed files, dead pins |
| [It starts and draws](#it-starts-and-draws) | Crash at start, blank or see-through windows, a Qt platform that isn't there |
| [Data survives a restart](#data-survives-a-restart) | Settings and data written to a folder that vanishes |
| [Nothing new in the home folder](#nothing-new-in-the-home-folder) | Folders created where they shouldn't be, files leaking to the host desktop |
| [Window class](#window-class) | Windows not grouped under the app's icon |
| [Bus names: tray, media, second launch](#bus-names-tray-media-second-launch) | No tray icon, dead media controls, a second instance |
| [The main feature](#the-main-feature) | Everything the others miss |

If the main feature can't be tested here (it needs an account, a login or
hardware we don't have), the app isn't listed until someone who can has tested
it, or its developer confirms it works.

**Batch changes** (a runtime upgrade, a prebuilt re-cut) run the first check on
every affected app and the whole list on one app of each stack; see
[batch changes](batch-changes.md).

## For agents

Run every check on a build installed from a local repository
([submitting an app](../packagers/submitting.md#test)), never on the host, and
never with `FLATPAK_USER_DIR`. Before launching from an IDE terminal, strip
`ELECTRON_RUN_AS_NODE` and `ELECTRON_NO_ATTACH_CONSOLE`
(`env -u … flatpak run`). Check `~/.local/share/flatpak/overrides/global`
first: a global override can make a permission look granted when the package
doesn't grant it. When done, `flatpak kill <app-id>` and clean up as in
[cleaning up after a run](../packagers/cleanup.md).

In the PR, say honestly what you tested and what you couldn't; a line per
check is enough. Problems a reviewer finds come up in review.

### It unpacks as a system install

```sh
./scripts/check-apply-extra.sh <app-id>
```

Downloads the real pinned files, checks `sha256` and `size`, and runs
`apply_extra.sh` as root without capabilities, offline, with only the runtime
and `/app/extra` visible: what a system-wide install does and a `--user`
install never shows. CI runs it on every PR that changes a pin and before every
automatic update. Then install with `publish.sh --verify`.

### It starts and draws

Launch on a private display so nothing lands on the user's desktop, and look at
the window:

```sh
Xwayland :99 -hidpi -geometry 1400x900 &
DISPLAY=:99 flatpak run <app-id> &
sleep 8; ffmpeg -loglevel error -f x11grab -video_size 1400x900 -i :99 -frames:v 1 /tmp/shot.png
flatpak kill <app-id>; kill %1
```

- Set `DISPLAY=:99` in the **host** environment. `--env=DISPLAY=:99` still binds
  the real display's socket and the window opens on the user's screen.
- Electron: add `--nosocket=wayland --socket=x11 --env=XDG_SESSION_TYPE=x11`.
  Tauri: `--env=GDK_BACKEND=x11`. GTK apps whose manifest has only
  `fallback-x11` need `--socket=x11` too.
- A rootful `Xwayland :99` accepts XTEST input: click about 0.3 s after moving
  the pointer, type slowly (about 0.12 s a key), and expect the first click on a
  new dialog only to focus it. A host input method can grab XTEST keys.
- Look at the screenshot: a blank, black or see-through window is a failure
  even if the process runs. For WebKit apps, check the web process is alive
  (`cat /proc/<pid>/task/*/children`).
- Close the display as soon as the test ends; an idle rootful Xwayland shows as
  a black window on the user's desktop.

### Data survives a restart

1. Start the app and change something it keeps: a setting, a note, a login.
2. Quit, `flatpak kill <app-id>`, and start it again. The change must be there.
3. Repeat from a **fresh first run** with no `~/.var/app/<app-id>` and no
   granted dotdir on the host: `:create` and `--persist` behave differently
   when the folder doesn't exist yet.

Then look where it wrote: `~/.var/app/<app-id>/` and any dotdir the package
grants. An app that writes into `$HOME/.something` without a grant writes into
a folder that vanishes on exit
([permissions](../packagers/permissions.md#home-directory-dotdirs)).

### Nothing new in the home folder

```sh
ls -A ~ > /tmp/home-before; ls -A ~/.config/autostart ~/.local/share/applications >> /tmp/home-before
# … run the app, use it, quit …
ls -A ~ > /tmp/home-after;  ls -A ~/.config/autostart ~/.local/share/applications >> /tmp/home-after
diff /tmp/home-before /tmp/home-after
```

Anything new must be the app's own data in a granted folder. Folders for tools
the user doesn't have, desktop entries or autostart files with
`Exec=/app/extra/…`, and shortcuts on the desktop are failures.

### Window class

Measure the class of the app's main window and compare it with
`StartupWMClass` in the desktop file:

- X11 (on `:99`): walk every window with `XQueryTree` and read
  `XGetClassHint`. Don't filter on `XFetchName`; Electron main windows set only
  `_NET_WM_NAME`.
- Wayland compositors: the client list (`hyprctl clients -j`, the compositor's
  equivalent).

They must be equal.

### Bus names: tray, media, second launch

```sh
DISPLAY=:99 flatpak run --log-session-bus <app-id> 2>&1 | grep -E 'Filtering|RequestName|ownership'
busctl --user list | grep -E 'StatusNotifierItem|org.mpris|<app-id>'
```

- **Any `Filtering …` line for a name the app tries to own is a failure.**
- **Tray:** if the app has one, a `StatusNotifierItem` name or registration
  appears.
- **Media:** if the app plays audio or video, play something and check an
  `org.mpris.MediaPlayer2.*` name appears. Chromium registers it only during
  playback: start the app with `--remote-debugging-port=9333` and play a
  generated tone over CDP with `new Audio(<blob URL of a WAV>)`. On a machine
  with no audio device, load a null sink first
  (`pactl load-module module-null-sink`).
- **Second launch:** for a single-instance app, start it again; the second must
  exit at once and leave one owner on the bus.

### The main feature

Do what the app is for, as stated in the PR: play a track, open and save a
document, connect to a server, take a screenshot, sync. Use the paths a user
would use:

- **File dialogs:** apps that call the file chooser portal open the dialog on
  the real desktop, out of reach of `:99`. A fake portal on a private session bus
  can answer it, but a private bus can start a second document portal and,
  when closed, unmount `/run/user/$UID/doc`; check the mount afterwards and
  `systemctl --user restart xdg-document-portal` if it's gone.
- **Saved passwords:** check an item was created over Secret Service, and delete
  test items afterwards.
- **Helpers the app shells out to** (`ffmpeg`, `gs`, `git`): run the feature
  that uses them. An app that only checks a command exists reports it
  available even when it can't run.
- **Can't test it:** say exactly what and why in the PR. Hold the listing until
  a tester or the developer confirms; don't merge on the hope it works. For
  now a tester builds the PR's branch locally
  ([submitting an app](../packagers/submitting.md#build)); there is no test
  remote yet.

### What CI does and doesn't

`pr-checks` covers the mechanical part: it validates descriptors, audits
packaging declarations, checks links, builds the changed apps, and runs the
unpack check on changed pins. A check that inspects files or a build without
running the app can be added there.

Running the app is not CI's job. Launching, drawing, data across restarts, the
home-folder diff, bus names and the main feature are tested as above, by the
packager, and recorded in the PR.
