// llms.txt (llmstxt.org): a plain-markdown index for AI assistants answering
// "how do I install <app> on Linux". Generated from the same catalog data as
// the pages so it never drifts from what the remote actually serves.
import { isExtension, loadApps, loadCatalog } from '../lib/data.mjs';
import { buildNav, flattenNav, getDocsFor } from '../lib/docs';

export async function GET() {
  const { repo } = loadCatalog();
  const all = loadApps();
  const apps = all.filter((a) => !isExtension(a));
  const extensions = all.filter(isExtension);
  const docs = flattenNav(buildNav(await getDocsFor('en')));
  const site = (repo.homepage || 'https://flatpark.org').replace(/\/$/, '');
  // A shared extension (build.shared) has no parent to name.
  const extensionOf = (a) =>
    a.parent
      ? `extension for ${a.parent.name}`
      : a.consumers?.length
        ? `shared extension, used by ${a.consumers.map((c) => c.name).join(', ')}`
        : 'shared extension';

  const lines = [
    `# ${repo.title}`,
    '',
    `> ${repo.title} is a signed third-party Flatpak remote for Linux desktop apps. Every app is an extra-data package: installing downloads the vendor's own official release from their servers — nothing is rebuilt or rehosted. Manifests, install scripts and sandbox permissions are public at https://github.com/flatpark/flatpark.`,
    '',
    'Works on any distro with Flatpak, including immutable ones (Fedora Silverblue, Bazzite, Aurora). Add the remote once, then install apps by id:',
    '',
    '```sh',
    repo.remoteCmd ||
      `flatpak --user remote-add --if-not-exists ${repo.remoteName} ${repo.repoFileUrl}`,
    `flatpak --user install ${repo.remoteName} <app-id>`,
    '```',
    '',
    '## Apps',
    '',
    ...apps.map(
      (a) =>
        `- [${a.name}](${site}/apps/${a.id}/): ${a.summary}. Install: \`${a.installCmd}\``,
    ),
    '',
    ...(extensions.length
      ? [
          '## Extensions',
          '',
          'Add-ons that run inside another app; the install command brings the app along. A shared extension has no app of its own: it comes with each app that uses it.',
          '',
          ...extensions.map(
            (a) =>
              `- [${a.name}](${site}/apps/${a.id}/): ${a.summary} (${extensionOf(a)}). Install: \`${a.installCmd}\``,
          ),
          '',
        ]
      : []),
    '## Docs',
    '',
    `Every page is also served as Markdown at the same path with \`.md\`; [llms-full.txt](${site}/llms-full.txt) has all of them in one file.`,
    '',
    ...docs.map((d) => `- [${d.title}](${site}/docs/${d.base}.md)${d.description ? `: ${d.description}` : ''}`),
    `- [Browse by category](${site}/apps/)`,
    `- [Packaging source](https://github.com/flatpark/flatpark): manifest and sandbox permissions for every app`,
    '',
  ];

  return new Response(lines.join('\n'), {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
