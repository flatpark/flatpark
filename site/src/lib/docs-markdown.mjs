// Markdown (Sätteri mdast) plugin for pages from the docs library (`../docs`).
//
// Docs link to each other with relative `.md` paths, so the links work on
// GitHub and for an agent reading the repo. Here they become site URLs:
//   - a published doc  -> its /docs/ URL, under the page's locale prefix;
//   - anything else in the repo (registry/, scripts/, docs/internal/, docs/specs/)
//     -> the file on GitHub;
//   - a target that doesn't exist -> the build fails (docsLinkCheck).
// Root-relative site links (`/setup/`) get the locale prefix in a translation.
//
// A `## Details` heading starts the part of a page written for agents and
// for readers who want everything; it is folded into a <details> block.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defaultLang } from '../i18n/config.mjs';
import { docUrl, splitDocId } from './docs-paths.mjs';

const SCHEME = /^[a-z][a-z0-9+.-]*:/i;

// Broken links fail the build. The check reads the files rather than riding
// on the plugin below: the content loader only logs a render error and carries
// on, and it caches rendered pages, so an unchanged page with a broken link
// would never reach the plugin again.
const LINK = /\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)|^\s*\[[^\]]+\]:\s*<?(\S+?)>?(?:\s|$)/gm;

function markdownFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((d) => {
    const p = join(dir, d.name);
    return d.isDirectory() ? markdownFiles(p) : d.name.endsWith('.md') ? [p] : [];
  });
}

export function findBrokenDocsLinks(docsRoot, repoRoot) {
  const out = [];
  for (const file of markdownFiles(docsRoot)) {
    // Code blocks quote links as examples; they are not links.
    const text = readFileSync(file, 'utf8').replace(/^(```|~~~)[^]*?^\1/gm, '').replace(/`[^`\n]*`/g, '');
    for (const m of text.matchAll(LINK)) {
      const url = m[1] ?? m[2];
      if (!url || SCHEME.test(url) || url.startsWith('#') || url.startsWith('/')) continue;
      const pathPart = url.split(/[?#]/)[0];
      if (!existsSync(resolve(dirname(file), decodeURI(pathPart)))) {
        out.push(`${relative(repoRoot, file)}: ${url}`);
      }
    }
  }
  return out;
}

export function docsLinkCheck({ docsRoot, repoRoot }) {
  return {
    name: 'flatpark-docs-link-check',
    hooks: {
      'astro:build:start': () => {
        const broken = findBrokenDocsLinks(docsRoot, repoRoot);
        if (broken.length) throw new Error(`broken links in docs/:\n  ${broken.join('\n  ')}`);
      },
    },
  };
}

/** Plugin factory: returns the plugin for files under `docsRoot`, nothing otherwise. */
export function docsMarkdownPlugin({ docsRoot, repoRoot, repoUrl }) {
  const unpublished = ['internal', 'specs'].map((d) => resolve(docsRoot, d) + sep);
  return (factory) => {
    const src = factory.fileURL && fileURLToPath(factory.fileURL);
    if (!src || !src.startsWith(docsRoot + sep)) return null;
    const { lang } = splitDocId(relative(docsRoot, src).replace(/\.md$/, ''));
    const prefix = lang === defaultLang ? '' : `/${lang}`;

    function rewrite(url) {
      if (!url || SCHEME.test(url) || url.startsWith('#') || url.startsWith('//')) return url;
      if (url.startsWith('/')) return prefix + url;
      const cut = url.search(/[?#]/);
      const pathPart = cut < 0 ? url : url.slice(0, cut);
      const hash = cut < 0 ? '' : url.slice(cut);
      const target = resolve(dirname(src), decodeURI(pathPart));
      if (!existsSync(target)) {
        return url; // reported by docsLinkCheck
      }
      const published =
        target.startsWith(docsRoot + sep) && !unpublished.some((d) => target.startsWith(d)) && target.endsWith('.md');
      if (published) {
        const { base } = splitDocId(relative(docsRoot, target).replace(/\.md$/, ''));
        return prefix + docUrl(base) + hash;
      }
      const kind = statSync(target).isDirectory() ? 'tree' : 'blob';
      return `${repoUrl}/${kind}/main/${relative(repoRoot, target)}${hash}`;
    }

    return {
      name: 'flatpark-docs',
      link(node, ctx) {
        const url = rewrite(node.url);
        if (url !== node.url) ctx.setProperty(node, 'url', url);
      },
      definition(node, ctx) {
        const url = rewrite(node.url);
        if (url !== node.url) ctx.setProperty(node, 'url', url);
      },
      after(root, ctx) {
        const heading = root.children.find(
          (n) => n.type === 'heading' && n.depth === 2 && ctx.textContent(n).trim() === 'Details',
        );
        if (!heading) return;
        ctx.replaceNode(heading, {
          type: 'html',
          value: '<details class="doc-details" data-doc-details><summary>Details</summary>',
        });
        ctx.appendChild(root, { type: 'html', value: '</details>' });
      },
    };
  };
}
