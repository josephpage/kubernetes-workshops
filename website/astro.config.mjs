// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';
import { remarkMermaid } from './scripts/remark-mermaid.mjs';

// Charge le script d'init Mermaid sur chaque page, bundlé par Vite
// (mermaid auto-hébergé : chunk séparé, chargé seulement si la page
// contient un diagramme — voir src/scripts/mermaid-init.js).
const mermaidRuntime = {
  name: 'mermaid-runtime',
  hooks: {
    'astro:config:setup': ({ injectScript }) => {
      injectScript('page', "import '/src/scripts/mermaid-init.js';");
    },
  },
};

export default defineConfig({
  site: 'https://kubernetes.josephpage.dev',
  markdown: {
    remarkPlugins: [remarkMermaid],
    // Les blocs mermaid sont transformés par remarkMermaid : Shiki ne doit pas les traiter.
    syntaxHighlight: { type: 'shiki', excludeLangs: ['mermaid'] },
  },
  integrations: [
    mermaidRuntime,
    starlight({
      title: 'Kubernetes Workshops',
      description: 'Ateliers pratiques Kubernetes — OCTO Technology & Octo Academy',
      defaultLocale: 'root',
      locales: {
        root: { label: 'Français', lang: 'fr' },
      },
      logo: { src: './src/assets/logo.svg', alt: 'Logo Kubernetes Workshops' },
      favicon: '/favicon.ico',
      customCss: [
        '@fontsource/outfit/500.css',
        '@fontsource/outfit/600.css',
        '@fontsource/outfit/700.css',
        './src/styles/octo.css',
      ],
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/josephpage/kubernetes-workshops' },
      ],
      // Active « Modifier cette page » ; chaque page générée porte son propre
      // editUrl (frontmatter) qui pointe vers le README source.
      editLink: {
        baseUrl: 'https://github.com/josephpage/kubernetes-workshops/edit/main/',
      },
      head: [
        { tag: 'meta', attrs: { property: 'og:image', content: 'https://kubernetes.josephpage.dev/img/social-card.jpg' } },
        { tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
      ],
      sidebar: [
        { label: 'Ateliers', items: [{ autogenerate: { directory: 'ateliers' } }] },
        {
          label: 'Guides',
          items: [
            { label: 'Introduction', slug: 'introduction' },
            { label: 'Comparatifs & recommandations', items: [{ autogenerate: { directory: 'comparatifs' } }] },
            { label: 'Conventions & contribution', items: [{ autogenerate: { directory: 'conventions' } }] },
          ],
        },
        { label: 'Environnements (clusters)', items: [{ autogenerate: { directory: 'environnements' } }] },
      ],
      // errorOnLocalLinks: les ateliers pointent volontairement vers
      // http://localhost:... (services du cluster local du lecteur).
      plugins: [starlightLinksValidator({ errorOnLocalLinks: false })],
    }),
  ],
});
