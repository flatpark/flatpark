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
// Nothing about the client is stored: no IP, no user agent, no commit. The
// country comes from Cloudflare's edge and is only ever summed.
//
// The request itself is passed straight through to the origin (the R2 custom
// domain), cache and status untouched. Counting is best-effort by design: a
// failure to record never fails the pull, and the route runs fail-open, so a
// Worker outage or an exhausted quota just means uncounted pulls.

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
    // only, never reorder, or the rollup reads old rows wrong.
    blobs: [id, kind, arch, branch, request.cf?.country || ""],
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
