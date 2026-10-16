// Locale-aware access to the docs library (the `docs` content collection).
//
// English is the source. A translation sits next to its page
// (`users/guide.zh-Hans.md`) and replaces it under that locale; an untranslated
// page renders its English body under the localised URL, so the sidebar, the
// hreflang set and the sitemap are the same in every locale.
import { getCollection, type CollectionEntry } from 'astro:content';
import { defaultLang, type Lang } from '../i18n';
import { docSlug, docUrl, splitDocId } from './docs-paths.mjs';

type Entry = CollectionEntry<'docs'>;

export interface Doc {
  /** English id: `users/guide`, `users/README`, `README`. */
  base: string;
  /** Path under /docs/: `users/guide`, `users`, ''. */
  slug: string;
  /** Top-level directory, '' for the library index. */
  section: string;
  isIndex: boolean;
  title: string;
  description: string;
  order: number;
  entry: Entry;
  /** The file this locale renders, relative to the repo root. */
  file: string;
}

export interface NavSection {
  section: string;
  index?: Doc;
  title: string;
  pages: Doc[];
}

// Sidebar order. A new top-level directory still shows up, after these.
const SECTION_ORDER = ['users', 'developers', 'packagers', 'reviewers', 'reference', 'project'];

/** The page's `# H1`, which is its title on GitHub as well. */
function titleOf(entry: Entry): string {
  const m = /^#\s+(.+?)\s*#*\s*$/m.exec(entry.body ?? '');
  return m ? m[1].replace(/[*_`]/g, '') : entry.id;
}

function toDoc(base: string, entry: Entry): Doc {
  const slug = docSlug(base);
  return {
    base,
    slug,
    section: slug.split('/')[0] ?? '',
    isIndex: base === 'README' || base.endsWith('/README'),
    title: titleOf(entry),
    description: entry.data.description ?? '',
    order: entry.data.order,
    entry,
    file: `docs/${entry.id}.md`,
  };
}

/** Every published doc as it should appear in `lang`. */
export async function getDocsFor(lang: Lang): Promise<Doc[]> {
  const all = (await getCollection('docs')).filter((e) => e.data.publish);
  const english = new Map<string, Entry>();
  const translated = new Map<string, Entry>();
  for (const entry of all) {
    const { base, lang: entryLang } = splitDocId(entry.id);
    if (entryLang === defaultLang) english.set(base, entry);
    else if (entryLang === lang) translated.set(base, entry);
  }
  return [...english.entries()].map(([base, entry]) => toDoc(base, translated.get(base) ?? entry));
}

const byOrder = (a: Doc, b: Doc) => a.order - b.order || a.title.localeCompare(b.title);

/** Sidebar: one group per top-level directory, its README as the heading. */
export function buildNav(docs: Doc[]): NavSection[] {
  const sections = new Map<string, NavSection>();
  for (const doc of docs) {
    if (!doc.section) continue;
    const s = sections.get(doc.section) ?? { section: doc.section, title: doc.section, pages: [] };
    if (doc.isIndex && doc.slug === doc.section) {
      s.index = doc;
      s.title = doc.title;
    } else {
      s.pages.push(doc);
    }
    sections.set(doc.section, s);
  }
  const rank = (name: string) => {
    const i = SECTION_ORDER.indexOf(name);
    return i < 0 ? SECTION_ORDER.length : i;
  };
  return [...sections.values()]
    .map((s) => ({ ...s, pages: s.pages.sort(byOrder) }))
    .sort((a, b) => rank(a.section) - rank(b.section) || a.section.localeCompare(b.section));
}

export { docUrl };
