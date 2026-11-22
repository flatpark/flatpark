// Atom feeds (RFC 4287), built from the same app data as the pages so a feed
// never announces an app or a version the catalog doesn't show. Two feeds:
// new listings (feed.xml) and upstream releases (updates.xml). Atom rather than
// RSS because it has one unambiguous date format and a required entry id;
// every feed reader that takes RSS takes Atom too.

const esc = (s) =>
  String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    // XML 1.0 forbids most C0 controls even escaped; a stray one in upstream
    // metainfo would make the whole feed unparseable.
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '');

// AppStream release dates are often a bare YYYY-MM-DD; git gives full ISO.
// Atom wants RFC 3339, so normalise both, and drop what doesn't parse.
export function toRfc3339(value) {
  if (!value) return '';
  const s = String(value).trim();
  const t = Date.parse(/^\d{4}-\d{2}-\d{2}$/.test(s) ? `${s}T00:00:00Z` : s);
  return Number.isFinite(t) ? new Date(t).toISOString().replace(/\.\d{3}Z$/, 'Z') : '';
}

export function siteOrigin(repo, site) {
  return String(site || repo?.homepage || 'https://flatpark.org').replace(/\/$/, '');
}

// The ordered blocks enrich.mjs parses out of an AppStream <description>
// ({ type: 'p', runs } / { type: 'list', items }), as ProseBlocks.astro renders
// them on the page.
const runsHtml = (runs = []) =>
  runs.map((r) => ('code' in r ? `<code>${esc(r.code)}</code>` : esc(r.text))).join('');
export function blocksHtml(blocks = []) {
  return blocks
    .map((b) =>
      b.type === 'list'
        ? `<ul>${(b.items || []).map((it) => `<li>${runsHtml(it)}</li>`).join('')}</ul>`
        : `<p>${runsHtml(b.runs)}</p>`,
    )
    .join('');
}

// The app's first screenshot, AppStream's default, which upstream picks to show
// the app best; the page has the rest. enrich.mjs has rewritten its url to the
// copy published under /screenshots/, or left upstream's absolute url when the
// fetch failed. Feed readers have no base URL, so both become absolute.
export function screenshotHtml(app, origin) {
  const shot = (app.screenshots || []).find((s) => s?.url);
  if (!shot) return '';
  const src = esc(new URL(shot.url, origin + '/').href);
  const alt = esc(shot.caption || app.name);
  return `<p><img src="${src}" alt="${alt}" style="max-width:100%;height:auto"></p>`;
}

// The entry body, the same in both feeds: a table (readers strip style but keep
// tables) with the icon, if any, beside the summary and the install line below,
// then the first screenshot and the description. Readers render it as HTML, so
// it goes in escaped as type="html".
export function appHtml(app, origin) {
  const summary = esc(app.summary);
  const install = app.installCmd ? `<pre><code>${esc(app.installCmd)}</code></pre>` : '';
  const icon = app.icon
    ? `<td><img src="${esc(new URL(app.icon, origin + '/').href)}" alt="" width="64" height="64"></td>`
    : '';
  const rows = [
    icon || summary ? `<tr>${icon}<td valign="middle">${summary}</td></tr>` : '',
    install ? `<tr><td${icon ? ' colspan="2"' : ''}>${install}</td></tr>` : '',
  ].join('');
  const head = rows ? `<table>${rows}</table>` : '';
  return head + screenshotHtml(app, origin) + blocksHtml(app.description);
}

export function renderAtom({ title, subtitle, selfUrl, altUrl, origin, entries }) {
  const updated = entries.reduce((m, e) => (e.updated > m ? e.updated : m), '') ||
    toRfc3339(new Date().toISOString());
  const out = [
    '<?xml version="1.0" encoding="utf-8"?>',
    '<feed xmlns="http://www.w3.org/2005/Atom">',
    `  <id>${esc(selfUrl)}</id>`,
    `  <title>${esc(title)}</title>`,
    subtitle ? `  <subtitle>${esc(subtitle)}</subtitle>` : '',
    `  <link rel="self" type="application/atom+xml" href="${esc(selfUrl)}"/>`,
    `  <link rel="alternate" type="text/html" href="${esc(altUrl)}"/>`,
    `  <icon>${esc(origin)}/logo.svg</icon>`,
    `  <updated>${updated}</updated>`,
    '  <author><name>FlatPark</name></author>',
  ];
  for (const e of entries) {
    out.push(
      '  <entry>',
      `    <id>${esc(e.id)}</id>`,
      `    <title>${esc(e.title)}</title>`,
      `    <link rel="alternate" type="text/html" href="${esc(e.link)}"/>`,
      `    <published>${e.published || e.updated}</published>`,
      `    <updated>${e.updated}</updated>`,
      ...(e.author ? [`    <author><name>${esc(e.author)}</name></author>`] : []),
      ...(e.categories || []).map((c) => `    <category term="${esc(c)}"/>`),
      e.summary ? `    <summary>${esc(e.summary)}</summary>` : '',
      `    <content type="html">${esc(e.html)}</content>`,
      '  </entry>',
    );
  }
  out.push('</feed>', '');
  return out.filter((l) => l !== '').join('\n') + '\n';
}

export function atomResponse(xml) {
  return new Response(xml, { headers: { 'Content-Type': 'application/atom+xml; charset=utf-8' } });
}

// Newest listings first. An app without a listing date (a shallow local
// build) can't be placed in time, so it stays out of the feed.
export function newAppEntries(apps, origin, limit = 50) {
  return apps
    .map((a) => ({ app: a, added: toRfc3339(a.added) }))
    .filter((x) => x.added)
    .sort((x, y) => y.added.localeCompare(x.added))
    .slice(0, limit)
    .map(({ app, added }) => ({
      id: `${origin}/apps/${app.id}/`,
      title: app.name,
      link: `${origin}/apps/${app.id}/`,
      published: added,
      updated: added,
      author: app.developer || '',
      categories: [app.section || app.category].filter(Boolean),
      summary: app.summary || '',
      html: appHtml(app, origin),
    }));
}

// Upstream releases, newest first, a few per app so one fast-shipping app
// can't push everyone else out. Release dates past the build time are
// upstream typos or pre-announcements, not something that has shipped.
export function releaseEntries(apps, origin, { limit = 100, perApp = 3, now = Date.now() } = {}) {
  const cutoff = toRfc3339(new Date(now).toISOString());
  const rows = [];
  for (const app of apps) {
    const seen = new Set();
    for (const r of (app.releases || []).slice(0, perApp)) {
      const date = toRfc3339(r.date);
      if (!date || date > cutoff || seen.has(r.version)) continue;
      seen.add(r.version);
      rows.push({ app, r, date });
    }
  }
  return rows
    .sort((x, y) => y.date.localeCompare(x.date) || x.app.name.localeCompare(y.app.name))
    .slice(0, limit)
    .map(({ app, r, date }) => ({
      id: `${origin}/apps/${app.id}/#release-${encodeURIComponent(r.version)}`,
      title: `${app.name} ${r.version}`,
      link: `${origin}/apps/${app.id}/`,
      published: date,
      updated: date,
      author: app.developer || '',
      categories: [app.section || app.category].filter(Boolean),
      summary: app.summary || '',
      html: appHtml(app, origin),
    }));
}
