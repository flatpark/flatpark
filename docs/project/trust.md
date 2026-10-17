---
description: How FlatPark repackages, pins, signs, and sandboxes the apps it hosts.
order: 4
---

# Trust & safety

FlatPark's whole model is repackaging official downloads — not rebuilding them.
Here is exactly what that means for what you install.

## extra-data only

FlatPark downloads the **vendor's own release** at install time and wraps it as a
Flatpak. The application you run is the official binary, not a FlatPark rebuild.
When the vendor ships an **AppImage**, FlatPark unpacks the filesystem appended to
it offline — the AppImage is read, never executed, and no FUSE is involved.

Some packages ship a little more than the vendor's download: a wrapper script,
or a library the Flatpak runtime doesn't provide (a tray-icon library, say).
Shared support libraries come from FlatPark's public
[`flatpark/prebuilt`](https://github.com/flatpark/prebuilt) repo, built by
GitHub Actions from pinned source. That is packaging scaffolding around the app
— it never replaces or patches the vendor's binary.

A few apps that people want have no official Linux release. For those, a
public `flatpark/<app>-release` repository builds the app exactly the way
upstream does, without changes and within upstream's licence, and the package
downloads that release at install time like any other.

Open-source apps get nothing injected into their process; their bugs are
reported upstream. A closed-source app occasionally needs an adaptation for a
feature to work in the sandbox (an `LD_PRELOAD` shim, for example). It is
reviewed, the app's page shows it, and the description says exactly what it is
and why.

## Pinned and signed

Each release is pinned by `sha256` and size in the manifest, and your Flatpak
client checks both when it downloads the file. If a vendor quietly changes the
file behind a URL, the change does **not** reach you: the install or update
fails until the new file has been checked and pinned.

New releases are found twice a day, or within minutes when the developer's
release workflow notifies FlatPark. Each one is downloaded, pinned and unpacked
the way an install would unpack it; only when that works is it merged and
published, automatically. Every update is a public commit in the repository.

The published repo is **GPG-signed**, and your client verifies that signature on
install and update.

## Tight sandbox

FlatPark prefers the minimum `finish-args` that still let an app work. A broad
grant like `--filesystem=home` or running host commands is the default only
after review, when the app's main feature needs it or leaving it out would take
more overrides than a user can be expected to manage. Every app page lists its
exact permissions with a plain-language risk label, and marks the risky ones in
colour, so you can see what an app can reach before installing it.

Capabilities an app doesn't strictly need are **left off by default**. Where an
app can do more with a broader permission, its page documents the `flatpak
override` command that grants it, so the choice stays yours — see the
[flatpak override](../users/override.md).

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
  added or changed, or the vendor's installer run at first launch with parts
  of it stood in for or its result changed. Only
  closed-source apps may be modified; open-source apps that would need it are
  not listed, because the fix belongs upstream.
- **Reduced isolation** — the app can run commands on your system outside the
  sandbox, or runs with its own internal sandbox (such as Chromium's) turned
  off. The app page says what and why.

Leaving out parts of a vendor package that cannot work inside Flatpak at all —
a setuid sandbox helper, a `pkexec` updater, a file-manager extension — is not
counted as a change. Neither is anything the app or its own installer does by
itself, such as a Windows installer run unmodified into its Wine prefix at first
launch. Running the installer with parts stood in for is a change: thinkorswim
and IBKR Desktop run their vendor's installer with a stand-in `df` so it
accepts the sandbox, and their pages say so.

## Community package, not endorsement

FlatPark is independent and **not affiliated with the apps it packages**. An
app's presence here is not an endorsement by its vendor unless the app's own
page says so. Each package links to the upstream source and website so you can
check provenance yourself.

## Verifying what you install

- Read the **permissions** panel on the app's page.
- Follow the **Source** and **Website** links to upstream.
- Install via the signed remote (see [setting up](../users/setup.md)); your client
  checks the signature for you.
