import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

// The docs library is the repo's top-level `docs/`, read in place: agents read
// those files from the repo and the site renders the same files, so there is
// nothing to sync. `internal/` (operations notes) and `specs/` (plans being
// worked through) stay in the repo and are never published.
//
// The id is the path without `.md`, kept verbatim. The default id generator
// slugifies (lowercasing `zh-Hans`, dropping the dot in `guide.zh-Hans`), and
// `src/lib/docs.ts` needs the real path back to find a page's locale, its
// section and the file to link for editing.
const docs = defineCollection({
  loader: glob({
    pattern: ['**/*.md', '!internal/**', '!specs/**'],
    base: '../docs',
    generateId: ({ entry }) => entry.replace(/\.md$/, ''),
  }),
  // The title is the page's own `# H1`, so the file reads the same on GitHub;
  // front matter only carries what the body can't.
  schema: z.object({
    description: z.string().optional(),
    order: z.number().default(0),
    publish: z.boolean().default(true),
  }),
});

export const collections = { docs };
