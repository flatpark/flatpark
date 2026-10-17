---
description: What an app needs before it can be listed, and when an app already on Flathub can be.
order: 1
---

# Can it be packaged?

Check these before writing anything. An app can be listed when:

- **Upstream publishes an official Linux build** at a stable public URL, not
  behind a login: a tarball, zip, `.deb`, `.rpm`, AppImage or installer.
- **Its main feature works inside the sandbox.** It doesn't depend on a host
  toolchain or service the sandbox can't reach, or on a capability Flatpak
  can't grant.
- **It runs on the current runtime** the rest of the catalog uses.
- **It may be downloaded and used**, and has a legitimate purpose. Closed-source
  apps are welcome.
- **It isn't already on Flathub from its own developer** (unless the developer
  asks), and if a third party packages it there, that package is missing a
  feature, has fallen behind or has stopped working
  ([below](#apps-already-on-flathub)).

The toolkit doesn't matter (Electron and Tauri apps are welcome), the licence
doesn't matter, and neither does how the app was written: an app is judged by
what it does, not by whether someone calls it AI-made
([listing policies](../project/policies.md)).

## Apps already on Flathub

- **The developer publishes it on Flathub themselves** (the app is verified
  there, or upstream maintains the Flathub manifest): we don't package it
  again. If the developer asks us to, we do; the developer decides about their
  own app.
- **A third party packages it on Flathub:** we can package it when that
  package falls short:
  - it is missing or breaks a feature: Enpass on Flathub can't verify the
    browser behind its extension, which ours does
    ([how](permissions.md#declaring-high-risk-permissions));
  - it has fallen far behind upstream, or no longer works at all.

  The reason goes in the PR, and the app's description says how our package
  differs from the Flathub one.
- **An app already on FlatPark whose developer later publishes it on Flathub**
  stays, unless the developer asks for it to be removed.

## For agents

### Checking

- **Flathub:** search [flathub.org](https://flathub.org) by the app's **name**,
  not a guessed id; ids differ more often than expected. Then:

  ```sh
  curl -s -o /dev/null -w '%{http_code}\n' https://flathub.org/api/v2/appstream/<id>   # 404 = not there
  curl -s https://flathub.org/api/v2/verification/<id>/status                         # "verified": true = the developer's
  ```

  A Flathub manifest repository whose commits come from upstream's maintainers
  counts as the developer's own even without the badge.
- **The download:** find the official one, on the vendor's site or the
  project's releases. A mirror, a personal account or a third-party repack
  doesn't qualify.
- **What the binary needs:** unpack it and read `readelf -d` on the main binary
  ([choosing a format](formats/README.md#choosing-the-runtime)).
- **Upstream's tracker:** search its issues for Flatpak and Flathub. A
  maintainer's earlier answer often names the real blocker.

### What doesn't work in the sandbox

These have stopped listings. When the main feature needs one of them, the app
isn't listed; when only a side feature does, the app can be, and its
description says what doesn't work.

- **A host toolchain or runtime as the main feature:** an IDE that needs the
  host's .NET SDK, a front end for host `qemu`, an R IDE whose engine must load
  the host's R. A read-only grant of the host tree doesn't help.
- **Capabilities:** packet capture and VPNs need `CAP_NET_RAW` or
  `CAP_NET_ADMIN`, which Flatpak never grants. A proxy client's TUN mode can't
  work; its local proxy port can.
- **Its own sandbox, built on namespaces:** Flatpak blocks the mount and
  namespace syscalls an app's own `bwrap` or minijail needs, whatever the
  permissions. Chromium-based apps use zypak instead; others have to turn their
  sandbox off (closed-source only, declared) or do without the feature.
- **Directly managing the host:** apps whose purpose is to change system
  settings, install system packages or control other apps' processes. Their
  developers usually want them to run unconfined, and that is a reason not to
  list them.
- **An open-source app that needs code injected or files changed** to work.
  The fix belongs upstream; it isn't listed until then.

### The app id

- **Use upstream's own identifier** when it has one: the id of its own Flatpak,
  or a Tauri app's `identifier` in `tauri.conf.json`. Then our package and any
  upstream one are the same application, not two rival ones.
- Otherwise reverse-DNS of the project's home: `io.github.<owner>.<App>` for a
  GitHub project, the vendor's domain for a company.
- **A rename is a new package.** A Flatpak ref is keyed on the id, so users don't
  move to a new id by themselves. Add the new id as its own directory and keep
  the old one until the new one is out, then de-list it. There is no automatic
  migration yet: users of the old id install the new one themselves, so say so
  in the old app's last release note or the de-listing PR. An approval
  carries over; cite the original link in the new
  [approvals](../reference/upstream-approvals.md) row.
- An id containing someone else's trademark (`com.youtube.…`) is avoided even if
  upstream uses it; pick a neutral one.

### Content and licences

- **Closed source** is fine with `policy.proprietary: true`, as long as the
  licence allows downloading from the vendor for personal use.
- **Downloaders and streaming clients** get a look at the service's terms and
  copyright first.
- **Piracy, malware and trademark impersonation** are never listed.
