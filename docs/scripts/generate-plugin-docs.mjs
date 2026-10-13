// Builds the plugin reference of the documentation site from the READMEs in
// lib/plugins/<plugin>/README.md, which are the authoritative API references.
//
// Reads  .vitepress/plugin-groups.json  (group -> plugin list, in sidebar order)
// Writes plugins/<group>/<slug>.md      (one page per plugin; git-ignored)
//        .vitepress/generated/plugin-sidebar.json  (sidebar groups; git-ignored)
//
// Plugins that are not listed in the groups file end up in a "More" group, so
// every plugin with a README has a page.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const docsDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pluginsDir = path.resolve(docsDir, '..', 'lib', 'plugins');
const groups = JSON.parse(
  fs.readFileSync(path.join(docsDir, '.vitepress', 'plugin-groups.json'), 'utf8'),
);

const slugOf = (name) => name.replace(/_/g, '-');
const titleOf = (name) =>
  name.split('_').map((w) => w[0].toUpperCase() + w.slice(1)).join(' ');
const readmeOf = (name) => path.join(pluginsDir, name, 'README.md');

const listed = new Set(groups.flatMap((g) => g.plugins.map((p) => p.plugin)));
const more = fs
  .readdirSync(pluginsDir)
  .filter((name) => !listed.has(name) && fs.existsSync(readmeOf(name)))
  .sort()
  .map((name) => ({ text: titleOf(name), slug: slugOf(name), plugin: name }));
const all = more.length
  ? [...groups, { group: 'More', dir: 'more', collapsed: true, plugins: more }]
  : groups;

// Start from a clean slate so renamed or removed plugins leave no stale page.
for (const g of all) {
  fs.rmSync(path.join(docsDir, 'plugins', g.dir), { recursive: true, force: true });
}

const sidebar = [];
let pages = 0;
for (const g of all) {
  const items = [];
  for (const p of g.plugins) {
    const readme = readmeOf(p.plugin);
    if (!fs.existsSync(readme)) continue;
    const outDir = path.join(docsDir, 'plugins', g.dir);
    fs.mkdirSync(outDir, { recursive: true });
    const source = `lib/plugins/${p.plugin}/README.md`;
    const body = fs.readFileSync(readme, 'utf8');
    fs.writeFileSync(
      path.join(outDir, `${p.slug}.md`),
      `<!-- Generated from ${source} by scripts/generate-plugin-docs.mjs. Do not edit. -->\n\n${body}\n` +
        `\n---\n\nSource: [\`${source}\`](https://github.com/legionir/sweetmelon/blob/main/${source})\n`,
    );
    items.push({ text: p.text, link: `/plugins/${g.dir}/${p.slug}` });
    pages++;
  }
  if (items.length) {
    sidebar.push({ text: g.group, collapsed: g.collapsed ?? true, items });
  }
}

const genDir = path.join(docsDir, '.vitepress', 'generated');
fs.mkdirSync(genDir, { recursive: true });
fs.writeFileSync(path.join(genDir, 'plugin-sidebar.json'), JSON.stringify(sidebar, null, 2) + '\n');
console.log(`Generated ${pages} plugin pages in ${sidebar.length} groups.`);
