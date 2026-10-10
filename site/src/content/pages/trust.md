---
title: Trust & safety
description: How FlatPark repackages, pins, signs, and sandboxes the apps it hosts.
group: Project
order: 3
---

FlatPark's whole model is repackaging official downloads — not rebuilding them.
Here is exactly what that means for what you install.

## extra-data only

FlatPark downloads the **vendor's own release** at install time and wraps it as a
Flatpak. The application you run is the official binary, not a FlatPark rebuild.
When the vendor ships an **AppImage**, FlatPark unpacks the filesystem appended to
it offline — the AppImage is read, never executed, and no FUSE is involved.

Some packages ship a little more than the vendor's download: a wrapper script, or
a library the Flatpak runtime doesn't provide (a tray-icon library, say). Shared
support libraries come from FlatPark's audited
[`flatpark/prebuilt`](https://github.com/flatpark/prebuilt) repo, built from pinned
source. That is packaging scaffolding around the app — it never replaces or
patches the vendor's binary.

Open-source apps get nothing injected into their process. A closed-source app
occasionally needs a small injected adaptation to work in the sandbox (an
`LD_PRELOAD` shim, for example); when it does, the app's description says
exactly what it is and why.

## Pinned and signed

Each release is pinned by `sha256` and size in the manifest, so a build cannot
silently swap the binary. Because the pin names an exact checksum, a vendor
quietly changing the file behind a URL does **not** flow through to you — the
build fails instead. New upstream releases are picked up by a daily check that
opens a pull request to re-pin, which a maintainer reviews and merges.

The published repo is **GPG-signed**, and your client verifies that signature on
install and update.

## Tight sandbox

FlatPark prefers the minimum `finish-args` that still let an app work, and avoids
broad grants like `--filesystem=home`. Every app page lists its exact
permissions with a plain-language risk label, so you can see what an app can
reach before installing it.

Capabilities an app doesn't strictly need are **left off by default**. Where an
app can do more with a broader permission, its page documents the `flatpak
override` command that grants it, so the choice stays yours — see the
[user guide](/guide/).

<span id="packaging"></span>

## Packaging changes

Every app page shows a packaging level under **Packaging**, next to its
permissions. It describes what the package does around — or to — the vendor's
build, separately from the permissions it is granted:

- **Unmodified** — the vendor's build runs as shipped. The launcher may set an
  environment variable or a command-line flag, nothing more.
- **Adapted** — the package adds something next to the app without changing it:
  a library or tool the Flatpak runtime lacks, fonts, or preset settings such as
  turning off an in-app updater that cannot work inside Flatpak.
- **Modified** — the package changes how the vendor's build runs: code injected
  into the app's process (an `LD_PRELOAD` library), files in the vendor's build
  added or changed, or the vendor's own installer run at first launch. Only
  closed-source apps may be modified; open-source apps that would need it are
  not listed, because the fix belongs upstream.
- **Reduced isolation** — the app can run commands on your system outside the
  sandbox, or runs with its own internal sandbox (such as Chromium's) turned
  off. The app page says what and why.

Leaving out parts of a vendor package that cannot work inside Flatpak at all —
a setuid sandbox helper, a `pkexec` updater, a file-manager extension — is not
counted as a change.

## Community package, not endorsement

FlatPark is independent and **not affiliated with the apps it packages**. An
app's presence here is not an endorsement by its vendor unless the app's own
page says so. Each package links to the upstream source and website so you can
check provenance yourself.

## Verifying what you install

- Read the **permissions** panel on the app's page.
- Follow the **Source** and **Website** links to upstream.
- Install via the signed remote (see the [user guide](/guide/)); your client
  checks the signature for you.
