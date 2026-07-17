# Website

Site de documentation des ateliers, construit avec [Astro](https://astro.build/) et
[Starlight](https://starlight.astro.build/), publié sur GitHub Pages à
l'adresse <https://kubernetes.josephpage.dev>.

## Contenu généré depuis les sources du dépôt

Le contenu du site n'est **pas** édité ici : il est régénéré à chaque
`dev`/`build`/`check` par [`scripts/sync-docs.mjs`](scripts/sync-docs.mjs) à
partir des Markdown à la racine du dépôt (qui restent la seule source de
vérité) :

| Source (racine du dépôt)        | Page du site                  |
| ------------------------------- | ----------------------------- |
| `README.md`                     | `/introduction/`              |
| `demos/<atelier>/README.md`     | `/ateliers/<atelier>/`        |
| `docs/kratix-vs-crossplane-comparison.md`, `docs/platform-engineering-recommendations.md` | `/comparatifs/…` |
| `docs/workshop-*.md`, `docs/agent-workflows.md`, `docs/repo-analysis.md` | `/conventions/…` |
| `clusters/<cluster>/README.md`  | `/environnements/<cluster>/`  |

Le script extrait le titre H1 en frontmatter `title`, pose un `editUrl`
pointant vers le fichier source sur GitHub, et réécrit les liens relatifs
(routes du site pour les fichiers synchronisés, URLs GitHub pour le reste).

Dans `src/content/docs/`, les chemins générés (`introduction.md`,
`ateliers/`, `comparatifs/`, `conventions/`, `environnements/`) sont
git-ignorés ; `index.mdx` (page d'accueil) est écrit à la main et commité.

## Commandes

```bash
npm install       # installer les dépendances
npm run dev       # serveur de développement (sync automatique)
npm run build     # build de production dans dist/ (sync automatique)
npm run preview   # servir dist/ en local
npm run check     # typecheck astro (sync automatique)
```

## Thème et fonctionnalités

- **Thème OCTO** : [`src/styles/octo.css`](src/styles/octo.css) — couche A
  (palettes marine/cyan via les variables officielles Starlight, robuste) et
  couche B (header marine, hero en dégradé ; s'appuie sur des sélecteurs
  internes du thème, à revalider après chaque montée de version de Starlight).
- **Recherche** : Pagefind, intégré à Starlight (index construit au build).
- **Mermaid** : rendu côté client par
  [`src/scripts/mermaid-init.js`](src/scripts/mermaid-init.js) — mermaid est
  auto-hébergé (paquet npm bundlé par Vite en chunk séparé, téléchargé
  uniquement sur les pages contenant un diagramme) ; les blocs ` ```mermaid `
  sont préparés au build par [`scripts/remark-mermaid.mjs`](scripts/remark-mermaid.mjs).
- **Validation de liens** : `starlight-links-validator` fait échouer le build
  sur tout lien interne cassé.

Options futures : `starlight-image-zoom` si des images arrivent dans le
contenu ; dates « dernière mise à jour » émises par le sync depuis le git des
sources.

## Déploiement

Le workflow [`.github/workflows/deploy-website.yml`](../.github/workflows/deploy-website.yml)
construit le site (`npm ci`, `npm run check`, `npm run build`) et publie
`website/dist/` sur GitHub Pages à chaque push sur `main` touchant le site ou
ses sources. Le domaine `kubernetes.josephpage.dev` est configuré dans les
réglages GitHub Pages du dépôt.
