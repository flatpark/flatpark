// Path rules for the docs library, in plain JS so `astro.config.mjs` (the
// remark plugin) and the pages share one copy.
//
// A doc's id is its path under `docs/` without `.md`: `users/guide`, a
// translation `users/guide.zh-Hans`, a section index `users/README`, the
// library index `README`. Its site URL drops the README and the locale suffix:
// `/docs/users/guide/`, `/docs/users/`, `/docs/`; a translation is served under
// the locale prefix like every other page.
import { defaultLang, prefixedLocales } from '../i18n/config.mjs';

/** Split an id into the English id and the locale it is written in. */
export function splitDocId(id) {
  const dot = id.lastIndexOf('.');
  const suffix = dot > id.lastIndexOf('/') ? id.slice(dot + 1) : '';
  return prefixedLocales.includes(suffix)
    ? { base: id.slice(0, dot), lang: suffix }
    : { base: id, lang: defaultLang };
}

/** The doc's path under /docs/, without slashes: '' for the library index. */
export function docSlug(base) {
  if (base === 'README') return '';
  return base.endsWith('/README') ? base.slice(0, -'/README'.length) : base;
}

/** English site URL of a doc, from its English id. */
export function docUrl(base) {
  const slug = docSlug(base);
  return slug ? `/docs/${slug}/` : '/docs/';
}
