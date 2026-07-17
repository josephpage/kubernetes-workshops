# Website

Ce site de documentation est construit avec [Astro](https://astro.build/) et [Starlight](https://starlight.astro.build/), un thème de documentation moderne pour Astro.

## Installation

```bash
npm install
```

## Développement local

```bash
npm run dev
```

Cette commande démarre un serveur de développement local et génère automatiquement le contenu depuis les fichiers Markdown sources du dépôt.

## Build

```bash
npm run build
```

Cette commande génère le site statique dans le répertoire `dist/`.

## Preview

```bash
npm run preview
```

Prévisualise le site buildé localement.

## Vérification des types

```bash
npm run check
```

Exécute la vérification TypeScript sur le code du site.

## Synchronisation du contenu

Le contenu du site est synchronisé depuis les fichiers Markdown sources du dépôt via `scripts/sync-docs.mjs`. Le script est exécuté automatiquement avant `dev`, `build` et `check`.

### Mapping des sources

| Source | Destination |
|--------|-------------|
| `README.md` | `introduction.md` |
| `demos/kratix/README.md` | `ateliers/kratix.md` |
| `demos/crossplane/README.md` | `ateliers/crossplane.md` |
| `demos/kubeception/README.md` | `ateliers/kubeception.md` |
| `demos/kong/README.md` | `ateliers/kong.md` |
| `docs/kratix-vs-crossplane-comparison.md` | `comparatifs/kratix-vs-crossplane-comparison.md` |
| `docs/platform-engineering-recommendations.md` | `comparatifs/platform-engineering-recommendations.md` |
| `docs/workshop-template.md` | `conventions/workshop-template.md` |
| `docs/workshop-quality-checklist.md` | `conventions/workshop-quality-checklist.md` |
| `docs/agent-workflows.md` | `conventions/agent-workflows.md` |
| `docs/repo-analysis.md` | `conventions/repo-analysis.md` |
| `clusters/azure-managed/README.md` | `environnements/azure-managed.md` |
| `clusters/scaleway-kapsule/README.md` | `environnements/scaleway-kapsule.md` |

Les fichiers générés dans `src/content/docs/` (sauf `index.mdx` et `404.md`) sont ignorés par git.

## Déploiement

Le déploiement se fait via GitHub Pages via `.github/workflows/deploy-website.yml`. Le site est disponible à l'adresse https://kubernetes.josephpage.dev.

## Mermaid

Les diagrammes Mermaid sont rendus côté client via un script chargé depuis [jsDelivr](https://cdn.jsdelivr.net/npm/mermaid@11/). C'est une dépendance CDN acceptable pour ce site (3 diagrammes seulement).

## Améliorations futures

- [`starlight-image-zoom`](https://github.com/HiDeoo/starlight-image-zoom): pour le zoom sur les images (aucune image dans le contenu actuellement).
