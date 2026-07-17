// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';
import { remarkMermaid } from './scripts/remark-mermaid.mjs';

export default defineConfig({
  site: 'https://kubernetes.josephpage.dev',
  markdown: {
    remarkPlugins: [remarkMermaid],
    // Les blocs mermaid sont transformés par remarkMermaid : Shiki ne doit pas les traiter.
    syntaxHighlight: { type: 'shiki', excludeLangs: ['mermaid'] },
  },
  integrations: [
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
        { tag: 'script', attrs: { type: 'module', src: '/scripts/mermaid-init.js' } },
      ],
      sidebar: [
        { label: 'Ateliers', autogenerate: { directory: 'ateliers' } },
        {
          label: 'Guides',
          items: [
            { label: 'Introduction', slug: 'introduction' },
            { label: 'Comparatifs & recommandations', autogenerate: { directory: 'comparatifs' } },
            { label: 'Conventions & contribution', autogenerate: { directory: 'conventions' } },
          ],
        },
        { label: 'Environnements (clusters)', autogenerate: { directory: 'environnements' } },
      ],
      plugins: [starlightLinksValidator()],
    }),
  ],
});
