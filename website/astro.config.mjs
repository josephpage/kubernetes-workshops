// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';
import { remarkMermaid } from './scripts/remark-mermaid.mjs';

export default defineConfig({
  site: 'https://kubernetes.josephpage.dev',
  base: '/',
  trailingSlash: 'ignore',
  markdown: {
    remarkPlugins: [remarkMermaid],
    // Astro >= 5.5 : ne pas passer les blocs mermaid à Shiki.
    syntaxHighlight: { type: 'shiki', excludeLangs: ['mermaid'] },
  },
  // Anciennes URLs Docusaurus (/docs/...) -> nouvelles routes.
  redirects: {
    '/docs': '/introduction/',
    '/docs/ateliers/crossplane': '/ateliers/crossplane/',
    '/docs/ateliers/kratix': '/ateliers/kratix/',
    '/docs/ateliers/kubeception': '/ateliers/kubeception/',
    '/docs/ateliers/kong': '/ateliers/kong/',
    '/docs/comparatifs/kratix-vs-crossplane-comparison': '/comparatifs/kratix-vs-crossplane-comparison/',
    '/docs/comparatifs/platform-engineering-recommendations': '/comparatifs/platform-engineering-recommendations/',
    '/docs/conventions/workshop-template': '/conventions/workshop-template/',
    '/docs/conventions/workshop-quality-checklist': '/conventions/workshop-quality-checklist/',
    '/docs/conventions/agent-workflows': '/conventions/agent-workflows/',
    '/docs/conventions/repo-analysis': '/conventions/repo-analysis/',
    '/docs/environnements/azure-managed': '/environnements/azure-managed/',
    '/docs/environnements/scaleway-kapsule': '/environnements/scaleway-kapsule/',
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
        './src/styles/custom.css',
      ],
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/josephpage/kubernetes-workshops' },
        { icon: 'external', label: 'OCTO Technology', href: 'https://octo.com' },
      ],
      // Active « Modifier cette page » ; chaque page générée porte son propre
      // editUrl (frontmatter) qui pointe vers le README source.
      editLink: {
        baseUrl: 'https://github.com/josephpage/kubernetes-workshops/edit/main/',
      },
      lastUpdated: true,
      head: [
        { tag: 'meta', attrs: { property: 'og:image', content: 'https://kubernetes.josephpage.dev/img/social-card.jpg' } },
        { tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
        { tag: 'script', attrs: { type: 'module', src: '/scripts/mermaid-init.js' } },
      ],
      sidebar: [
        {
          label: 'Ateliers',
          items: [{ autogenerate: { directory: 'ateliers' } }],
        },
        {
          label: 'Introduction',
          items: [{ slug: 'introduction' }],
        },
        {
          label: 'Comparatifs & recommandations',
          items: [{ autogenerate: { directory: 'comparatifs' } }],
        },
        {
          label: 'Conventions & contribution',
          items: [{ autogenerate: { directory: 'conventions' } }],
        },
        {
          label: 'Environnements (clusters)',
          items: [{ autogenerate: { directory: 'environnements' } }],
        },
      ],
      plugins: [
        starlightLinksValidator({
          // Les URLs localhost sont dans le contenu (ex: http://localhost:30080)
          // Ce n'est pas des liens internes cassés, donc on désactive cette erreur.
          errorOnLocalLinks: false,
        }),
      ],
    }),
  ],
});
