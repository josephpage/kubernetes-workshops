# Workflows recommandés avec agents IA

Ce document décrit comment demander efficacement à un agent IA de créer ou faire évoluer un atelier dans ce dépôt.

## Créer un nouvel atelier

Prompt recommandé:

```text
Analyse le dépôt, puis crée un nouvel atelier dans demos/<theme>/<scenario>.
Utilise docs/workshop-template.md.
L'atelier doit durer environ 60 minutes, être en français, inclure validation et nettoyage,
et ne doit pas nécessiter de secret réel.
Avant d'éditer, propose brièvement la structure des fichiers.
```

Résultat attendu:

- un dossier d'atelier dédié;
- un `README.md` complet;
- des manifests ou valeurs Helm minimaux;
- des commandes de validation;
- une procédure de nettoyage.

## Enrichir un atelier existant

Prompt recommandé:

```text
Améliore l'atelier demos/<...> pour qu'il soit jouable par des participants Octo Academy.
Ne change pas le comportement technique sauf si nécessaire.
Ajoute objectifs, prérequis, validation, questions de débrief et nettoyage.
Signale les commandes que tu n'as pas pu tester.
```

## Faire une revue pédagogique

Prompt recommandé:

```text
Fais une revue de cet atelier comme support de formation Kubernetes.
Priorise les problèmes qui empêchent un participant de réussir l'atelier:
prérequis manquants, étapes ambiguës, commandes non vérifiables, risques de coût,
nettoyage incomplet, manque de validation.
Donne les constats avec références de fichiers/lignes.
```

## Faire une revue technique

Prompt recommandé:

```text
Fais une revue technique des manifests Kubernetes/Helm/Terraform de cet atelier.
Priorise les bugs, incompatibilités de versions, risques sécurité, ressources cloud coûteuses,
et écarts avec les pratiques Kubernetes actuelles.
Ne modifie rien sans confirmation.
```

## Demander une implémentation sûre

Prompt recommandé:

```text
Implémente les corrections nécessaires.
Ne lance pas tofu apply, tofu destroy, helmfile apply ou kubectl delete sans me demander.
Tu peux lancer les validations locales non destructrices si elles sont disponibles.
À la fin, résume les fichiers modifiés et les validations exécutées.
```

## Points à préciser à l'agent

- niveau cible: découverte, intermédiaire, avancé;
- durée;
- cluster cible: kind, k3d, AKS, Scaleway Kapsule, autre;
- contraintes réseau ou proxy;
- outils autorisés: Helm, Helmfile, Kustomize, Terraform/OpenTofu;
- si l'atelier est pour autoformation, animation live ou support de formation.
