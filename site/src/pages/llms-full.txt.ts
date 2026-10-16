// Every published English doc in one file, in sidebar order, for an assistant
// that wants the whole library in a single fetch. Each page keeps its source
// URL so a reader can tell where one ends and the next begins.
import { loadCatalog } from '../lib/data.mjs';
import { buildNav, getDocsFor } from '../lib/docs';

export async function GET() {
  const { repo } = loadCatalog();
  const site = (repo.homepage || 'https://flatpark.org').replace(/\/$/, '');
  const docs = await getDocsFor('en');
  const index = docs.find((d) => d.base === 'README');
  const ordered = [
    ...(index ? [index] : []),
    ...buildNav(docs).flatMap((s) => [...(s.index ? [s.index] : []), ...s.pages]),
  ];
  const parts = ordered.map((d) => `<!-- ${site}/docs/${d.base}.md -->\n\n${(d.entry.body ?? '').trim()}\n`);
  return new Response(parts.join('\n---\n\n'), {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
