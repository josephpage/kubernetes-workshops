# Instructions pour agents IA

Ce dépôt sert à construire des ateliers pratiques Kubernetes pour OCTO Technology et Octo Academy. Les agents doivent produire des contenus pédagogiques fiables, reproductibles et maintenables, pas seulement du code qui fonctionne une fois.

## Lecture rapide du dépôt

- `clusters/` contient les clusters de support, provisionnés avec OpenTofu/Terraform.
- `clusters/modules/` contient les modules partagés.
- `demos/` contient les ateliers applicatifs et scénarios joués sur Kubernetes.
- `docs/` contient les templates et checklists de création d'ateliers.

## Règles de contribution

1. Préserver les changements utilisateur existants. Ne jamais réinitialiser le dépôt ni supprimer des fichiers non liés à la tâche.
2. Ne jamais commiter de secrets: `.env`, kubeconfig, certificats privés, clés cloud, tokens, fichiers `terraform.tfvars`, `terraform.tfstate`.
3. Préférer des exemples explicites avec valeurs factices: `example.com`, `REPLACE_ME`, `changeme`.
4. Garder les ateliers autonomes: chaque dossier d'atelier doit expliquer son objectif, ses prérequis, son déroulé, ses vérifications et son nettoyage.
5. Ne pas lancer de commande qui crée, modifie ou détruit des ressources cloud sans validation humaine explicite.
6. Quand une version Kubernetes, Helm chart, provider Terraform/OpenTofu ou API externe compte, la vérifier avant de l'actualiser.

## Commandes utiles

Depuis un dossier cluster:

```bash
tofu init
tofu validate
tofu plan
```

Depuis un dossier utilisant Helmfile:

```bash
helmfile lint
helmfile template
helmfile diff
```

Pour inspecter les manifests Kubernetes:

```bash
kubectl apply --dry-run=client -f <file>
kubectl diff -f <file>
```

Ces commandes peuvent nécessiter des dépendances locales ou un accès cluster. Si elles échouent pour cette raison, le signaler clairement au lieu de masquer l'échec.

## Format attendu pour un atelier

Tout nouvel atelier doit idéalement contenir:

- `README.md`: guide pédagogique complet;
- manifests Kubernetes, Helm chart, Helmfile ou Terraform selon le besoin;
- fichiers `.env.example` ou `values.example.yaml` si une configuration locale est nécessaire;
- section `Validation` avec commandes observables;
- section `Nettoyage`;
- section `Pour aller plus loin`.

Utiliser [docs/workshop-template.md](docs/workshop-template.md) comme base.

## Style pédagogique

- Écrire en français par défaut.
- Utiliser des étapes courtes et testables.
- Introduire les concepts au moment où ils sont manipulés.
- Privilégier des commandes copiables, puis expliquer le résultat attendu.
- Ajouter des questions de débrief pour aider l'animateur à vérifier la compréhension.
- Indiquer clairement le niveau cible: découverte, intermédiaire ou avancé.

## Validation avant livraison

Avant de terminer une contribution, vérifier au minimum:

- les liens relatifs;
- les commandes documentées;
- l'absence de secrets;
- la présence d'une procédure de nettoyage;
- la cohérence avec les conventions du dépôt.

Pour un changement Terraform/OpenTofu, exécuter `tofu fmt` et `tofu validate` quand l'environnement le permet.

Pour un changement Helm/Helmfile, exécuter `helmfile lint` ou `helmfile template` quand l'environnement le permet.

Pour un changement Kubernetes YAML brut, exécuter un dry-run client quand l'environnement le permet.

## Quand demander une validation humaine

Demander confirmation avant:

- créer ou détruire des ressources cloud;
- modifier des états Terraform;
- changer les versions majeures de Kubernetes, chart Helm, provider ou CRD;
- ajouter une dépendance externe structurante;
- publier ou exposer un endpoint public.
