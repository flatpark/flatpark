// UI translation layer.
//
// English is the default locale and stays unprefixed (`/apps/foo/`), so every
// URL that existed before i18n still resolves; other locales live under a
// prefix (`/zh-Hans/apps/foo/`). This mirrors what Flathub does, and is the
// reason `localizePath` treats `defaultLang` as a special case rather than
// prefixing uniformly.
//
// Dictionaries are per-locale JSON — the format Weblate and friends expect —
// so community translation can be bolted on later without a migration.
import en from './locales/en.json';
import zhHans from './locales/zh-Hans.json';

export { defaultLang, languages, locales, prefixedLocales } from './config.mjs';
import { defaultLang, languages } from './config.mjs';

export type Lang = 'en' | 'zh-Hans';

const dictionaries: Record<Lang, Record<string, string>> = { en, 'zh-Hans': zhHans };

export const isLang = (value: string): value is Lang => value in languages;

/** Locale of a rendered page, read back off its own URL. */
export function getLangFromUrl(url: URL): Lang {
  const first = url.pathname.split('/')[1] ?? '';
  return isLang(first) && first !== defaultLang ? first : (defaultLang as Lang);
}

/**
 * Turn a default-locale path into the `lang` equivalent. Paths are written
 * throughout the site in their English form (`/setup/`), and every link goes
 * through here so a page never has to know which locale it is rendering as.
 */
export function localizePath(path: string, lang: Lang): string {
  const p = path.startsWith('/') ? path : `/${path}`;
  return lang === defaultLang ? p : `/${lang}${p}`;
}

/** Inverse of `localizePath` — used to build hreflang alternates. */
export function stripLang(pathname: string): string {
  const [, first, ...rest] = pathname.split('/');
  if (!first || !isLang(first) || first === defaultLang) return pathname;
  return `/${rest.join('/')}`;
}

/**
 * `t('key')`, with `{name}` placeholders filled from `vars`. A key missing from
 * a translation falls back to English rather than blanking the page, so a
 * partially translated locale still renders; a key missing everywhere renders
 * as itself, which is loud enough to catch in review.
 */
/**
 * Label for a catalog section. `enrich.mjs` bakes a stable slug into the app
 * JSON — the client-side category filter matches on it — and the display text
 * is resolved here so it follows the reader's language.
 */
export function sectionLabel(lang: Lang, slug: string | undefined | null): string {
  if (!slug) return '';
  const t = useTranslations(lang);
  const key = `section.${slug}`;
  const label = t(key);
  // An unmapped slug renders as itself rather than as `section.<slug>`.
  return label === key ? slug : label;
}

/**
 * Label + detail for one sandbox permission. `enrich.mjs` emits a `key` for the
 * ones it recognises alongside the English `label`/`detail`; anything it could
 * not classify carries no key and falls back to the English text it baked in.
 */
export function permissionText(
  lang: Lang,
  perm: { key?: string; label?: string; detail?: string; value?: string; flag?: string; readOnly?: boolean },
): { label: string; detail: string } {
  const t = useTranslations(lang);
  const vars = { value: perm.value ?? '', flag: perm.flag ?? '' };
  const resolve = (key: string) => {
    const out = t(key, vars);
    return out === key ? null : out; // `t` echoes the key when nothing matches
  };
  const translated = perm.key ? resolve(`perm.${perm.key}`) : null;
  // Only wrap what we actually translated: the baked English label already
  // carries its own "(read-only)", so wrapping the fallback would double it.
  const label =
    translated === null
      ? (perm.label ?? '')
      : perm.readOnly
        ? t('perm.read_only', { label: translated })
        : translated;
  const detail = (perm.key ? resolve(`perm.${perm.key}.detail`) : null) ?? perm.detail ?? '';
  return { label, detail };
}

// Packaging transparency (see site/tools/enrich.mjs packagingOf): the badge
// colour per level and the localized title/detail of one declared item. A
// declared `detail` is a { en, zh-Hans } map; a missing locale falls back to
// English. The derived support-files item has no detail, only `value`.
export const packagingDot: Record<string, string> = {
  unmodified: 'bg-emerald-500',
  adapted: 'bg-slate-400',
  modified: 'bg-amber-500',
  reduced: 'bg-red-500',
};

export function packagingText(
  lang: Lang,
  item: { kind: string; detail?: Record<string, string> | null; value?: string },
): { label: string; detail: string } {
  const t = useTranslations(lang);
  const label = t(`pack.kind.${item.kind}`);
  const detail = item.detail
    ? (item.detail[lang] ?? item.detail[defaultLang] ?? '')
    : item.value
      ? t(`pack.kind.${item.kind}.auto`, { value: item.value })
      : '';
  return { label, detail };
}

export function useTranslations(lang: Lang) {
  const dict = dictionaries[lang] ?? dictionaries[defaultLang as Lang];
  const base = dictionaries[defaultLang as Lang];
  return function t(key: string, vars?: Record<string, string | number>): string {
    let out = dict[key] ?? base[key] ?? key;
    if (vars) {
      for (const [name, value] of Object.entries(vars)) {
        out = out.split(`{${name}}`).join(String(value));
      }
    }
    return out;
  };
}
