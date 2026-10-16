// Each published doc's Markdown source, next to its page: `/docs/users/guide.md`
// beside `/docs/users/guide/`. The path is the file's own path under `docs/`,
// so the relative `.md` links inside it resolve to these files too. English
// and translations alike; an agent fetching the site gets what the repo has.
import { getCollection } from 'astro:content';

export async function getStaticPaths() {
  const docs = (await getCollection('docs')).filter((e) => e.data.publish);
  return docs.map((entry) => ({ params: { path: entry.id }, props: { body: entry.body ?? '' } }));
}

export function GET({ props }: { props: { body: string } }) {
  return new Response(props.body, {
    headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
  });
}
