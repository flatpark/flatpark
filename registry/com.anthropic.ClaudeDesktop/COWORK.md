# Cowork in the Claude Flatpak

Cowork runs Claude's tasks in a small QEMU virtual machine. The VM needs KVM
and a few host programs that the Flatpak sandbox can't reach, so Cowork is off
by default. You can turn it on with three `flatpak override` settings. Read the
next section first, because those settings undo most of what the sandbox does.

## What you give up

| Override | What it gives the app |
|---|---|
| `--device=all` | Every device node, including `/dev/kvm` and `/dev/vhost-vsock` |
| `--filesystem=host-os:ro` | A read-only view of your system's `/usr` and `/etc`, at `/run/host` |
| `--talk-name=org.freedesktop.Flatpak` | The right to run **any** command on your system as you, through the Flatpak portal |

With the last one the app is no longer really sandboxed: anything it runs on
the host has your user's full access. If that isn't acceptable, use the native
package instead (see the end of this page).

## Set it up

1. Turn on hardware virtualization (VT-x or AMD-V) in your firmware settings,
   and check that `/dev/kvm` exists.

2. Install QEMU, the UEFI firmware and virtiofsd on the host:

   | Distribution | Command |
   |---|---|
   | Fedora | `sudo dnf install qemu-system-x86-core edk2-ovmf virtiofsd` |
   | Debian 13, Ubuntu 24.04 and later | `sudo apt install qemu-system-x86 ovmf virtiofsd` |

   The app looks for these exact paths, so check them after installing:
   `/usr/bin/qemu-system-x86_64`, `/usr/share/OVMF/OVMF_CODE_4M.fd` or
   `/usr/share/OVMF/OVMF_CODE.fd`, and `/usr/libexec/virtiofsd` or
   `/usr/bin/virtiofsd`. On arm64 the first two are
   `/usr/bin/qemu-system-aarch64` and `/usr/share/AAVMF/AAVMF_CODE.fd`.
   A distribution that puts the firmware elsewhere (openSUSE does) needs a
   link in `/usr/share/OVMF`.

3. Load the vsock module now and at every boot, and add yourself to the `kvm`
   group (log out and back in afterwards):

   ```sh
   echo vhost_vsock | sudo tee /etc/modules-load.d/vhost_vsock.conf
   sudo modprobe vhost_vsock
   sudo usermod -aG kvm "$USER"
   ```

4. Check that `bwrap` is on your `PATH`. Flatpak pulls it in as the
   `bubblewrap` package on most distributions, but a Flatpak built with its own
   copy installs it as `flatpak-bwrap` instead:

   ```sh
   command -v bwrap || echo "install bubblewrap first"
   ```

5. Add the overrides and restart Claude:

   ```sh
   flatpak override --user --device=all --filesystem=host-os:ro \
     --talk-name=org.freedesktop.Flatpak com.anthropic.ClaudeDesktop
   ```

The first time Cowork starts, the app downloads its VM image (about 1.4 GB) and
unpacks it into `~/.var/app/com.anthropic.ClaudeDesktop/config/Claude/`. It
asks for about 16 GB free there and won't start Cowork with less.

## Turn it off

```sh
flatpak override --user --nodevice=all --nofilesystem=host-os \
  --no-talk-name=org.freedesktop.Flatpak com.anthropic.ClaudeDesktop
```

This turns off only the three Cowork settings; your other overrides for the
app stay, and so does the GPU access the package grants itself. The overrides
file keeps them as "off" entries (`devices=!all;`), which the next
`flatpak override` to turn Cowork on replaces. Once Cowork is unavailable, the app deletes its VM image the next time it starts.

## How it works

Nothing in the app is changed. The launcher checks for all three overrides; if
any one is missing, it starts the app exactly as before. If all three are
present, it preloads `cowork-shim.so` (built from `cowork-shim.c` in this
folder), which:

- sends the app's file checks for QEMU, the firmware and virtiofsd to
  `/run/host/usr/...`, where the host's copies are;
- starts `cowork-host-helper` when the app starts its own
  `cowork-linux-helper`. That script runs the same helper on the host with
  `flatpak-spawn --host`, inside `bwrap` with the app's files at `/app` and the
  document portal at `/run/flatpak/doc`, so the paths the app hands it still
  resolve;
- connects the app to the helper's socket in
  `$XDG_RUNTIME_DIR/app/com.anthropic.ClaudeDesktop/`, the part of the runtime
  directory the sandbox shares with the host.

The host needs `bwrap` (step 4) and the document portal, which
desktops with Flatpak support already run.

## Tested

Tested on Fedora 45 (x86_64, GNOME) only. Debian, Ubuntu and arm64 are
expected to work from the paths above but haven't been tried. Reports are
welcome in a FlatPark issue.

## If you'd rather keep the sandbox

Use Anthropic's native `.deb` (Debian, Ubuntu) or a native install on other
distributions. Cowork works there without any of the above.
