# FlatPark: Yet another Flatpak hub

FlatPark is a community Flatpak remote. Each app is the developer's official
release, downloaded from their servers at install time and run in a sandbox,
usually within minutes of upstream shipping it.

## Mission

**Installing apps on Linux should be easy.**

- Every developer can put their app straight into the hands of Linux users.
- Every app a user wants can be found on FlatPark.

## What we believe

- **Plenty of software is a good thing.** AI has made software easier to write
  than ever, and the Linux desktop has more apps than it has ever had.
- **Publishing is the developer's right.** Shipping an app should need nobody's
  permission, any more than putting up a web page does.
- **The apps users need should be installable.** When a vendor only ships
  through its own site, the community packages it for users, from the vendor's
  official release.
- **Choosing is the user's right.** A store's job is to lay out the facts, not
  to decide for its users.
- **A store's power is for service, not gatekeeping.** Recommendation and
  traffic should make things easier and help good apps be seen, never become a
  tool for holding others down.

See [About FlatPark](docs/project/about.md) and the
[principles](docs/project/principles.md).

## Install

```sh
flatpak --user remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak --user install flatpark <app-id>
```

`--user` installs into your home (no admin); drop it from both commands for a
system-wide install. Browse the catalog at <https://flatpark.org>.

## Package an app with your agent

You don't need to know Flatpak to add an app. This repository's documentation
is written for AI agents to follow, and the
[packaging playbook](docs/packagers/playbook.md) takes an agent from a manifest
to a tested PR. Open this repo in your agent (e.g. Claude Code) and ask:

> I want to publish **\<app or upstream URL\>** to FlatPark. Start from
> `docs/README.md` and follow the packaging playbook.

Your part is mostly testing: running the app and checking that what you use it
for works. That makes the people who requested an app the best ones to package
it, especially when testing needs an account, particular hardware or knowing
the field. If there's an issue for the app, comment `/claim` on it first
(`/claim <App>` or `/claim <#>` on a scan issue) so nobody else starts on the same one.

## For developers

- **No gatekeeper.** If it's your official release, it's safe and it works in
  the sandbox, it can be listed: no matter how many users it has, how old it
  is, or how it was written, AI included. You can also
  [let your agent do the packaging](#package-an-app-with-your-agent).
- **The full Flatpak experience.** Your users install and update your app like
  any other Flatpak, in a sandbox, with the permissions listed on its page. It
  works with the tools they already use: GNOME Software, KDE Discover,
  [Bazaar](https://gitlab.gnome.org/World/bazaar),
  [Warehouse](https://github.com/flattool/warehouse),
  [Flatseal](https://github.com/tchx84/Flatseal) and plain `flatpak update`.
- **Updates within minutes.** FlatPark checks every app's releases twice a day.
  Add the [publish-action](docs/developers/publish-action.md) to your release
  workflow and each release reaches your users a few minutes after you publish
  it. No token, no secret.
- **Your app, your call.** You decide whether it's listed, how it's packaged
  and what is said about it. See [your app on FlatPark](docs/developers/your-app.md).

## For users

- **The apps you need, as a Flatpak.** Many apps you rely on, like trading and
  banking clients, only ship an installer from the vendor's own site. FlatPark
  packages them for you from that official download, so they install and
  update like any other Flatpak. Missing one?
  [Open an issue](https://github.com/flatpark/flatpark/issues), or
  [package it yourself](#package-an-app-with-your-agent) with your agent.
- **If you trust the app, you can trust FlatPark.** Our goal is to get you the
  developer's official release, exactly as published. Each download is pinned
  by checksum and size, and comes straight from the developer's servers; the
  repository is GPG-signed. See [trust & safety](docs/project/trust.md).
- **Reviewed.** Every app is built, run and reviewed before it's listed, and
  checked for malicious behaviour. A malicious release is removed at once. See
  [security](docs/project/security.md).
- **Kept up to date.** Every app's releases are checked twice a day, and new
  versions are published automatically once they unpack cleanly.
- **The latest runtime.** When a new freedesktop, GNOME or KDE runtime comes
  out, every app on it moves to it promptly and is tested, so no FlatPark app
  keeps an old runtime on your disk.

## Contributing

1. **Use the apps.** Install and use them. If something doesn't work, whether
   or not it has anything to do with Flatpak,
   [open an issue](https://github.com/flatpark/flatpark/issues) and we'll handle
   it.
2. **Request an app.** If an app you want has no Flatpak, open an issue asking
   for it.
3. **Lend your agent.** If you have spare tokens, point your agent at
   [finding apps](docs/packagers/finding-apps.md#for-agents) and let it search
   for good apps that Flatpak users can't get yet. It files what it finds as
   `[App Discover]` issues.
4. **Package an app.** New apps are very welcome. Pick one from the
   [issues](https://github.com/flatpark/flatpark/issues?q=is%3Aissue+is%3Aopen+%22%5Bapp+discover%5D%22)
   or bring your own, and
   [let your agent package it](#package-an-app-with-your-agent).
5. **Everything else.** PRs for the website, the documentation and translations
   are just as welcome, and so is any other improvement.

See [CONTRIBUTING.md](CONTRIBUTING.md) and the [documentation](docs/README.md).

## Badge

If your app is on FlatPark, you can link to it from your README or website with
this badge:

[![Get it on FlatPark](site/public/badges/get-it-on-flatpark.svg)](https://flatpark.org)

Markdown (replace `<app-id>`):

```md
[![Get it on FlatPark](https://flatpark.org/badges/get-it-on-flatpark.svg)](https://flatpark.org/apps/<app-id>)
```

HTML:

```html
<a href="https://flatpark.org/apps/<app-id>">
  <img alt="Get it on FlatPark" height="56" src="https://flatpark.org/badges/get-it-on-flatpark.svg">
</a>
```

A PNG (2×, 308×112) is at
<https://flatpark.org/badges/get-it-on-flatpark.png> for places that don't render
SVG.

## License

FlatPark's own code is [MIT](LICENSE). It does **not** license the packaged
applications themselves — those remain their vendors' property and are fetched
from official sources at install time.
