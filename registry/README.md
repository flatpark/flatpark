# App registry

One directory per app, named by its Flatpak app ID. Each holds a `flatpark.yml`
descriptor plus the packaging files it points at — the Flatpak manifest, the
AppStream metainfo, a `.desktop` file, an icon, and usually an `apply_extra.sh`,
a launcher wrapper, and a `resolve-update.sh`. Apps are added and updated through
pull requests — see [CONTRIBUTING.md](../CONTRIBUTING.md).
