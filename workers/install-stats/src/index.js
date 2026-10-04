// dl.flatpark.org/delta-indexes/* — counts app installs and updates without
// touching what the client gets back.
//
// Every flatpak pull sends `Flatpak-Ref: app/<id>/<arch>/<branch>` on each
// request, plus `Flatpak-Upgrade-From: <old commit>` when it is an update. Of
// all the requests a pull makes, exactly one goes to delta-indexes/ (the
// summary advertises indexed deltas, so ostree asks for the target commit's
// index before fetching anything else), which is why the route sits there and
// not on objects/* — one Worker run per pull instead of hundreds, since an
// install also fetches every dirtree and file object of the app. A no-op
// `flatpak update` pulls nothing and is never seen; appstream and any other
// non-app refs are ignored.
//
// Nothing about the client is stored: no IP, no user agent, not the commit it
// is upgrading from. The country comes from Cloudflare's edge and is only ever
// summed. The commit being *pulled* is recorded: the repo keeps one version per
// ref, so pulls of one commit ≈ installations that reached that version, which
// is what the rollup's active-install estimate is built from.
//
// The request itself is passed straight through to the origin (the R2 custom
// domain), cache and status untouched. Counting is best-effort by design: a
// failure to record never fails the pull, and the route runs fail-open, so a
// Worker outage or an exhausted quota just means uncounted pulls.

// delta-indexes/<2>/<41>.index — the target commit in OSTree's filename-safe
// base64 ('_' for '/', no padding), split after two characters.
const DELTA_INDEX_RE = /\/delta-indexes\/([A-Za-z0-9+_]{2})\/([A-Za-z0-9+_]{41})\.index$/;

export function targetCommit(pathname) {
  const m = DELTA_INDEX_RE.exec(pathname);
  if (!m) return "";
  const bin = atob((m[1] + m[2]).replace(/_/g, "/") + "=");
  return Array.from(bin, (c) => c.charCodeAt(0).toString(16).padStart(2, "0")).join("");
}

const APP_REF_RE = /^app\/([A-Za-z][A-Za-z0-9_-]*(?:\.[A-Za-z0-9_-]+){2,})\/([A-Za-z0-9_]+)\/([A-Za-z0-9._-]+)$/;

export function dataPoint(request) {
  if (request.method !== "GET") return null;
  const m = APP_REF_RE.exec(request.headers.get("flatpak-ref") || "");
  if (!m) return null;
  const [, id, arch, branch] = m;
  const kind = request.headers.get("flatpak-upgrade-from") ? "update" : "install";
  return {
    indexes: [id],
    // Column order is the SQL schema: blob1 = id, blob2 = kind, ... — append
    // only, never reorder, or the rollup reads old rows wrong. blob6 (commit)
    // arrived 2026-10-04; rows from before it read back as "".
    blobs: [id, kind, arch, branch, request.cf?.country || "", targetCommit(new URL(request.url).pathname)],
  };
}

export default {
  async fetch(request, env) {
    try {
      const point = dataPoint(request);
      if (point) env.INSTALLS.writeDataPoint(point);
    } catch (e) {
      console.log(JSON.stringify({ msg: "count failed", error: String(e) }));
    }
    return fetch(request);
  },
};
