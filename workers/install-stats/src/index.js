// dl.flatpark.org/delta-indexes/* — counts app installs and updates, and
// appstream refreshes, without touching what the client gets back.
//
// Every flatpak pull sends `Flatpak-Ref: app/<id>/<arch>/<branch>` on each
// request, plus `Flatpak-Upgrade-From: <old commit>` when it is an update. Of
// all the requests a pull makes, exactly one goes to delta-indexes/ (the
// summary advertises indexed deltas, so ostree asks for the target commit's
// index before fetching anything else), which is why the route sits there and
// not on objects/* — one Worker run per pull instead of hundreds, since an
// install also fetches every dirtree and file object of the app. A no-op
// `flatpak update` pulls nothing and is never seen. Runtime refs are ignored.
//
// Appstream refreshes (`Flatpak-Ref: appstream2/<arch>`) take the same path
// and are recorded under the id "appstream2". The appstream ref gets a new
// commit whenever the catalogue changes, and every machine with the remote
// pulls it once when it next refreshes, so pulls of one appstream commit ≈
// machines in use — the way Flathub estimates its active users from runtime
// updates. The rollup keeps only registry ids, so these rows never mix into
// an app's counts.
//
// What is recorded, per pull, all of it either repo data or coarse enough to
// be shared by many machines: the ref, the commit pulled and the commit it
// upgrades from (both public repo commits; the second tells how many
// installations predate counting, since each one's first update starts from
// a commit we never saw it reach), the flatpak and libostree versions from
// the user agent, the distro id/version/arch flatpak sends in
// Flatpak-Os-Info (from os-release), Cloudflare's country and network (ASN,
// the ISP or hosting provider — what tells CI runners and scrapers from
// desktops), and the origin's response status. Not the IP, not the raw user
// agent, nothing finer than country for location. Client-sent values are
// reduced to short tokens before they are stored, so a header can never put
// arbitrary text into the dataset.
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
const APPSTREAM_REF_RE = /^(appstream2)\/([A-Za-z0-9_]+)$/;
const COMMIT_RE = /^[0-9a-f]{64}$/;

// A short token or "": what a client-sent value is reduced to.
const token = (s) => (/^[A-Za-z0-9._+-]{1,32}$/.test(s ?? "") ? s : "");
// "libostree/2026.4 flatpak/1.18.4" -> the version after `name/`, or "".
const version = (ua, name) => new RegExp(`\\b${name}/([0-9][0-9.]{0,15})`, "i").exec(ua)?.[1] ?? "";

export function dataPoint(request, status = 0) {
  if (request.method !== "GET") return null;
  const ref = request.headers.get("flatpak-ref") || "";
  const m = APP_REF_RE.exec(ref) ?? APPSTREAM_REF_RE.exec(ref);
  if (!m) return null;
  const [, id, arch, branch = ""] = m;
  const from = (request.headers.get("flatpak-upgrade-from") || "").trim();
  const ua = request.headers.get("user-agent") || "";
  // "debian;unknown;x86_64": os-release ID, VERSION_ID, machine arch
  const [osId, osVersion, osArch] = (request.headers.get("flatpak-os-info") || "").split(";");
  return {
    indexes: [id],
    // Column order is the SQL schema: blob1 = id, blob2 = kind, ... — append
    // only, never reorder, or the rollup reads old rows wrong. blob6 (commit)
    // arrived 2026-10-04 and blob7–15 later; older rows read them back as "".
    blobs: [
      id,
      from ? "update" : "install",
      arch,
      branch,
      request.cf?.country || "",
      targetCommit(new URL(request.url).pathname),
      COMMIT_RE.test(from) ? from : "", // blob7: commit upgraded from
      version(ua, "flatpak"), // blob8
      version(ua, "libostree"), // blob9
      token(osId), // blob10
      token(osVersion), // blob11
      token(osArch), // blob12
      request.cf?.asn ? String(request.cf.asn) : "", // blob13
      String(request.cf?.asOrganization || "").slice(0, 64), // blob14
      status ? String(status) : "", // blob15: origin response status
    ],
  };
}

export default {
  async fetch(request, env) {
    // Recorded after the origin answers, so the row carries its status. A
    // failed fetch rejects exactly as an un-proxied request would.
    const response = await fetch(request);
    try {
      const point = dataPoint(request, response.status);
      if (point) env.INSTALLS.writeDataPoint(point);
    } catch (e) {
      console.log(JSON.stringify({ msg: "count failed", error: String(e) }));
    }
    return response;
  },
};
