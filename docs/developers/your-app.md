---
description: How your app comes to FlatPark, what you decide about it, the developer-approved shield, and linking to it from your own site.
order: 1
---

# Your app on FlatPark

FlatPark packages desktop apps that publish an official Linux build. It doesn't
rebuild your app: the package downloads your own release file from your
servers when someone installs it, unpacks it, and runs it in a Flatpak sandbox.
Users get the binary you shipped, with your checksum, and updates as soon as
you release.

Most apps here were packaged by FlatPark, often before their developers heard
of it. If that is how you found your app here: it's yours to decide what
happens to it.

## What you decide

You have the final word on your own app:

- **Whether it is here at all.** Ask, and it is removed. No reason needed.
- **How it is packaged.** Permissions, default settings, which of your
  downloads is used. If you want the package to behave differently, say so and
  it is changed.
- **What we say about it.** The app's description and anything else on its
  page.

Open an issue at
[github.com/flatpark/flatpark](https://github.com/flatpark/flatpark/issues)
for any of these, or reply on the issue we opened on your project.

## Getting your app listed

Open an issue with a link to your app and its Linux downloads. What makes an app
easy to package:

- an official Linux build at a stable public URL: a tarball, `.deb`, AppImage
  or zip, on GitHub Releases or your own site;
- release file names that keep the same pattern from one version to the next;
- if you use a Flatpak or Tauri app id already, the same id here.

[Can it be packaged?](../packagers/can-it-be-packaged.md) has the full list,
including what can't work in a sandbox.

## The developer-approved shield

When you're happy for your app to be on FlatPark, say so somewhere public we can
link to: an issue, a PR, a discussion. Your app page then shows a blue
**developer-approved** shield, and the link is recorded in the
[approvals list](../reference/upstream-approvals.md). A private email isn't
enough on its own, because anyone reading the page has to be able to check it.

Without the shield, the package is a community package, not an endorsement by
you, and its description says so.

## Linking to FlatPark

If you'd like to offer FlatPark as an install option on your site or README,
the install command is on your app's page, and there is a badge:

```markdown
[![Get it on FlatPark](https://flatpark.org/badges/get-it-on-flatpark.svg)](https://flatpark.org/apps/<app-id>/)
```

```sh
flatpak remote-add --if-not-exists --user flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak install --user flatpark <app-id>
```

## Updates

FlatPark checks your releases twice a day and ships each new version
automatically: it re-pins the download, checks it unpacks, and publishes. If
you release on GitHub, adding [publish-action](publish-action.md) to your
release workflow ships it within minutes instead.

If a release changes in a way the package didn't expect (a renamed binary, a
different archive layout), the update stops at the unpack check, the previous
version stays available, and we fix the package by hand.

## Flathub

If you start publishing your app on Flathub yourself, the FlatPark package
stays unless you ask us to remove it; tell us and it goes. An app you already
publish on Flathub isn't packaged here again, unless you ask for it. When
someone else maintains your app's Flathub package and it is missing a feature,
has fallen behind or has stopped working, FlatPark may offer the app too, and
its description says how the two differ.

## Renaming your app or changing its id

A Flatpak app is identified by its id, so a new id is a new package: installed
copies don't move over by themselves. Tell us before the release that changes
it; the new id is listed next to the old one, and the old one is removed once
the new one is out. Users who installed the old id have to install the new one
themselves.

## Bug reports

Problems with how the app is packaged (it won't start in the sandbox, a
permission is missing, settings aren't kept) are ours: users report them at
[FlatPark's issues](https://github.com/flatpark/flatpark/issues). Problems in
the app itself we pass on to you, with what we found.

## For agents

- **Approval:** set `catalog.upstream_approved: true` in the app's
  `flatpark.yml` and add a row to
  [upstream approvals](../reference/upstream-approvals.md) in the same PR, citing
  the public link. CI fails a `true` flag without a row. An approval carries over
  a rename; cite the original link in the new row.
- **A developer's request about their own app** (permissions, defaults, which
  download) is applied as asked, in its own PR, declaring what needs declaring
  ([permissions](../packagers/permissions.md#when-the-developer-has-asked)).
- **Removal on request:** delete `registry/<id>/` in a PR that links the
  request. Publishing drops the app from the catalog; the weekly `delist-prune`
  removes its refs from the repository. Installed copies keep working until
  users uninstall them.
- **The badge** is served from `site/public/badges/get-it-on-flatpark.svg`.
