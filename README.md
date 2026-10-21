# Yet another Flatpak hub

FlatPark is a community Flatpak remote for Linux desktop apps that ship an
official download: a `.deb`, a tarball or an AppImage at a stable release URL.
Every app is the developer's own release, fetched from their servers at install
time and run in a sandbox. FlatPark doesn't build apps from source.

The goal is a remote that runs efficiently and is easy to take part in. Speed
matters most: apps often land minutes after an upstream release, and a fix
reaches users just as fast. Packaging, review, publishing and upgrades are
built to be driven by AI agents. See [About FlatPark](docs/project/about.md) and
the [principles](docs/project/principles.md).

## Install

```sh
flatpak --user remote-add --if-not-exists flatpark https://dl.flatpark.org/flatpark.flatpakrepo
flatpak --user install flatpark <app-id>
```

`--user` installs into your home (no admin); drop it from both commands for a
system-wide install. Browse the catalog at <https://flatpark.org>.

## For developers

- **AI is welcome.** An app is judged by what it does and how it's packaged,
  not by whether it was written with AI. You can also let your agent do the
  packaging: open this repo in it and ask it to publish your app.
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

- **If you trust the app, you can trust FlatPark.** Our goal is to get you the
  developer's official release, exactly as published. Each download is pinned
  by checksum and size, and comes straight from the developer's servers; the
  repository is GPG-signed. See [trust & safety](docs/project/trust.md).
- **Reviewed.** Every app is built, run and reviewed before it's listed, and
  checked for malicious behaviour. A malicious release is removed at once. See
  [security](docs/project/security.md).
- **Kept up to date.** Every app's releases are checked twice a day, and new
  versions are published automatically once they unpack cleanly.
- **The current runtime.** When a new freedesktop, GNOME or KDE runtime comes
  out, every app on it moves to it promptly and is tested, so no FlatPark app
  keeps an old runtime on your disk.
- **Missing an app?** If an app you want has no Flatpak,
  [open an issue](https://github.com/flatpark/flatpark/issues) and we'll look
  into it. Or package it yourself and open a PR.

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
   `[app discover]` issues.
4. **Package an app.** New apps are very welcome. Pick one from the
   [issues](https://github.com/flatpark/flatpark/issues?q=is%3Aissue+is%3Aopen+%22%5Bapp+discover%5D%22)
   or bring your own. Open this repo in your agent (e.g. Claude Code) and ask:

   > I want to publish **\<app or upstream URL\>** to FlatPark. Start from
   > `docs/README.md` and follow the packaging playbook.

   The [packaging playbook](docs/packagers/playbook.md) takes it from manifest
   to tested PR.
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
