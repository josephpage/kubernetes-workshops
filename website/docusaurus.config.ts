import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'Kubernetes Workshops',
  tagline:
    'Ateliers pratiques Kubernetes — OCTO Technology & Octo Academy',
  favicon: 'img/favicon.ico',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://kubernetes.josephpage.dev',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',
  trailingSlash: false,

  // GitHub pages deployment config.
  organizationName: 'josephpage', // Usually your GitHub org/user name.
  projectName: 'kubernetes-workshops', // Usually your repo name.

  onBrokenLinks: 'throw',

  // Les READMEs source contiennent des chevrons type <file> qui casseraient
  // le parseur MDX : "detect" fait parser les .md en CommonMark classique.
  markdown: {
    format: 'detect',
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'fr',
    locales: ['fr'],
  },

  themes: [
    // Blocs ```mermaid rendus en diagrammes.
    '@docusaurus/theme-mermaid',
    // Recherche plein texte locale (aucun service externe, compatible
    // GitHub Pages).
    [
      '@easyops-cn/docusaurus-search-local',
      {
        hashed: true,
        language: ['en', 'fr'],
        indexBlog: false,
        highlightSearchTermsOnTargetPage: true,
      },
    ],
  ],

  plugins: [
    // Clic sur une image du contenu pour l'agrandir.
    'docusaurus-plugin-image-zoom',
  ],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          // Pas d'editUrl global : chaque page synchronisée porte son propre
          // custom_edit_url (injecté par scripts/sync-docs.mjs) qui pointe
          // vers le README source.
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Kubernetes Workshops',
      logo: {
        alt: 'Logo Kubernetes Workshops',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'ateliers',
          position: 'left',
          label: 'Ateliers',
        },
        {
          type: 'docSidebar',
          sidebarId: 'guides',
          position: 'left',
          label: 'Guides',
        },
        {
          type: 'docSidebar',
          sidebarId: 'environnements',
          position: 'left',
          label: 'Environnements',
        },
        {
          href: 'https://github.com/josephpage/kubernetes-workshops',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Introduction',
              to: '/docs/',
            },
            {
              label: 'Ateliers',
              to: '/docs/ateliers/kratix',
            },
            {
              label: 'Environnements',
              to: '/docs/environnements/azure-managed',
            },
          ],
        },
        {
          title: 'Liens',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/josephpage/kubernetes-workshops',
            },
            {
              label: 'OCTO Technology',
              href: 'https://octo.com',
            },
          ],
        },
      ],
      copyright:
        '© OCTO Technology — contenu pédagogique des formations Kubernetes.',
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'hcl', 'docker', 'yaml'],
    },
    mermaid: {
      theme: {light: 'neutral', dark: 'dark'},
    },
    zoom: {
      selector: '.markdown img',
      background: {
        light: 'rgb(255, 255, 255)',
        dark: 'rgb(20, 25, 33)',
      },
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
