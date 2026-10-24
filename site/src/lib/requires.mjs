// Other Flatpak apps a package runs with (flatpark.yml `requires:`), such as
// a Wine package's org.winehq.Wine from Flathub. Flatpak has no dependency
// between apps, so the install command installs them alongside.

/** The descriptor's `requires:` entries that name a remote and a ref. */
export function requiresOf(fy) {
  return (Array.isArray(fy?.requires) ? fy.requires : [])
    .filter((r) => r?.remote && r?.ref)
    .map((r) => ({ remote: String(r.remote), ref: String(r.ref), name: String(r.name || r.ref) }));
}

/** cmd followed by one `flatpak install` per remote for what the apps require. */
export function installWith(cmd, apps) {
  const byRemote = new Map();
  for (const r of apps.flatMap((a) => a.requires ?? [])) {
    const refs = byRemote.get(r.remote) ?? new Set();
    refs.add(r.ref);
    byRemote.set(r.remote, refs);
  }
  return [cmd, ...[...byRemote].map(([remote, refs]) => `flatpak install ${remote} ${[...refs].join(' ')}`)].join(' && ');
}
