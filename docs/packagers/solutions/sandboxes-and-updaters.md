---
description: Apps with their own sandbox, in-app updaters, and apps built to manage the host.
order: 4
---

# Nested sandboxes and updaters

Two things apps bring with them often clash with Flatpak. An app's **own
sandbox** (Chromium's, a code agent's) needs kernel features that Flatpak
blocks inside its sandbox, so it fails to start. An **in-app updater** tries to
replace files Flatpak owns, or nags about versions Flatpak already manages.
Neither can be fixed by granting more; the answers are a supported switch in
the app, zypak for Chromium, or the developer changing the app.

## For agents

### What Flatpak blocks

Measured inside `org.freedesktop.Platform`:

| Call | In the sandbox | With `--allow=devel` |
|---|---|---|
| `unshare` (user, mount, PID namespaces), `clone(CLONE_NEWUSER)` | EPERM | EPERM |
| `mount`, `pivot_root`, `chroot`, `setns` | EPERM | EPERM |
| `ptrace` | EPERM | allowed |
| `seccomp` filters and user notification, landlock | allowed | allowed |
| `add_key`, `keyctl` (kernel keyring) | blocked | blocked |

No permission lifts the namespace and mount rules. A sandbox built on seccomp
or landlock works inside Flatpak; one built on namespaces (bubblewrap,
minijail, Chromium's) doesn't. The helper usually dies right after announcing
its backend, with no further log; `strings` on it shows `bwrap`,
`unshare-user` or `minijail_enter_pivot_root`.

### Chromium and Electron: zypak

Chromium's sandbox wants namespaces. zypak replaces it with Flatpak's own
sub-sandbox (the Spawn portal), so the app keeps a sandbox:

- Use `base: org.electronjs.Electron2.BaseApp`, which ships zypak, for every
  Chromium-based app, browsers included; `org.chromium.Chromium.BaseApp` has
  no zypak.
- Start the app with `zypak-wrapper <binary>`. Never `--no-sandbox` for an
  Electron or Chromium app.
- For browsers, the wrapper also sets what a Chromium launcher would:
  `CHROME_WRAPPER=<this wrapper>` and `ZYPAK_SPAWN_LATEST_ON_REEXEC=1` (so a
  restart from `chrome://restart` comes back through the wrapper), and
  `ZYPAK_EXPOSE_WIDEVINE_PATH`, which must end in `WidevineCdm`. zypak removes
  its own `ZYPAK_*` variables after reading them, so they don't show in the
  app's environment.

### Other embedded Chromium (CEF, JxBrowser)

These start Chromium themselves, not through zypak. When it refuses to start
(`SandboxNotSupportedException`, a blank login dialog), the options are the
embedder's own switch to disable the sandbox, or passing `--no-sandbox` to the
Chromium it launches. Both lower isolation (`sandbox-off`) and are declared; if
the switch can only be reached by injecting code, that is closed-source only.
Don't modify the embedded binaries: JxBrowser verifies them on every start and
unpacks fresh copies.

### WebKitGTK 6 (Wails v3)

WebKitGTK 6 always sandboxes its web process, through the Flatpak portal, and
names it after the app's GApplication id. Wails' default id is
`org.wails.<name>`; the portal rejects a name outside the app id, and the app
aborts at start ("failed to receive credentials"). The fix is upstream setting
Wails' `Linux.ApplicationID` to the Flatpak id. Until then the only workaround
is `WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1`, which turns the web sandbox
off: declare it as `sandbox-off`, and get the maintainer's agreement first.

### Apps whose own sandbox has no switch

If the main feature depends on the app's own namespace sandbox and there is no
supported way to turn it off, the app can't be listed. If only a side feature
needs it (file previews in a file manager, for example), the app can be listed
with that feature off, and its description says so.

### In-app updaters

An updater inside a Flatpak can't replace the app (it is read-only), and a
version prompt is noise, since `flatpak update` handles updates.

- **The app has a setting or flag to turn it off:** use it. A flag in the
  wrapper is Unmodified (the VS Code forks in the catalog, Cursor and Kiro
  among them, take `--disable-updates`); writing the setting
  into the app's config before first launch is `seeded-config`.
- **Tauri's updater plugin** has no off switch: its endpoint is compiled in, and
  the process-wide levers (proxy or CA variables) also break the app's own
  HTTPS. It usually fails quietly at start and only errors when the user checks
  manually. The fix is upstream skipping the check when `FLATPAK_ID` is set; the
  metainfo can tell users to update with `flatpak update`.
- **Never patch an open-source app's updater out.** For a closed-source app,
  disabling it in its files is `file-change`, declared.

### Apps built to manage the host

Apps whose purpose is to control the host itself (system settings, packages,
other apps' processes, a server panel) mostly can't work in the sandbox:
`pgrep` and `/proc` show only the sandbox, host CLIs can't run without
`host-command`, and their developers often want them unconfined. Ask the
developer before packaging one; if they want it to run unconfined, don't list
it.
