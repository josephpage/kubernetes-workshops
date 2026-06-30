# Kubernetes Workshops

Ce dépôt rassemble des ateliers pratiques Kubernetes destinés aux consultants OCTO Technology et aux personnes qui suivent les formations Kubernetes d'Octo Academy.

L'objectif n'est pas seulement de stocker des manifests: chaque atelier doit être rejouable, pédagogique, vérifiable, et suffisamment cadré pour être maintenu avec l'aide d'agents IA.

## Structure

- `clusters/`: environnements d'exécution pour les ateliers, principalement provisionnés avec OpenTofu/Terraform.
- `clusters/modules/`: modules réutilisables pour les composants transverses: cert-manager, Grafana/Prometheus, kubeseal.
- `demos/`: ateliers et démonstrations applicatives déployés sur un cluster Kubernetes existant.
- `docs/`: conventions pédagogiques, templates et checklists pour créer de nouveaux ateliers.
- `AGENTS.md`: instructions de travail pour les agents IA.

## Démarrer

1. Lire [AGENTS.md](AGENTS.md) pour comprendre les règles de contribution, de sécurité et de validation.
2. Lire [docs/repo-analysis.md](docs/repo-analysis.md) pour comprendre l'état actuel et les axes d'évolution.
3. Utiliser [docs/workshop-template.md](docs/workshop-template.md) comme squelette pour tout nouvel atelier.
4. Vérifier l'atelier avec [docs/workshop-quality-checklist.md](docs/workshop-quality-checklist.md) avant de le proposer.

## Principes pédagogiques

Un atelier doit privilégier la pratique guidée:

- un objectif métier ou opérationnel clair;
- des prérequis explicites;
- un temps cible;
- un chemin nominal reproductible;
- des commandes de vérification;
- des questions de compréhension;
- une section de nettoyage pour éviter les coûts cloud inutiles.

Les ateliers doivent pouvoir être joués par des personnes en formation, mais aussi servir de base à des consultants OCTO qui veulent approfondir, adapter ou animer le sujet.

## Sécurité

Ne commitez pas de secrets, kubeconfigs, tokens, états Terraform, fichiers `.env` réels ou certificats privés. Les fichiers d'exemple doivent utiliser des valeurs factices et explicites.

Les commandes destructrices ou coûteuses, comme `tofu apply`, `tofu destroy`, `kubectl delete` large périmètre, doivent être documentées avec leur impact et ne doivent pas être lancées par défaut par un agent.
