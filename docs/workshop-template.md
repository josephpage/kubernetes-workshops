# Template d'atelier Kubernetes

Copier ce template dans le dossier du nouvel atelier, puis supprimer les sections non pertinentes.

## Résumé

Décrire en quelques lignes le problème traité et le résultat attendu.

- Niveau: découverte | intermédiaire | avancé
- Durée cible: 30 min | 60 min | 90 min | autre
- Public: consultants OCTO | participants Octo Academy | animateurs
- Environnement cible: cluster local | cluster managé | sandbox fournie

## Objectifs pédagogiques

À la fin de l'atelier, les participants sauront:

- objectif 1;
- objectif 2;
- objectif 3.

## Concepts manipulés

- Kubernetes: Pods, Deployments, Services, Ingress, Gateway API, RBAC, NetworkPolicy, etc.
- Outillage: kubectl, Helm, Helmfile, OpenTofu/Terraform, k9s, stern, etc.
- Exploitation: observabilité, rollout, debug, sécurité, haute disponibilité, coûts.

## Prérequis

Outils locaux:

```bash
kubectl version --client
helm version
```

Accès nécessaires:

- kubeconfig pointant vers le cluster de travail;
- droits Kubernetes requis;
- variables d'environnement ou fichiers d'exemple à créer.

## Architecture cible

Décrire les composants déployés et leurs interactions.

Ajouter un schéma simple si le scénario implique plusieurs flux réseau ou composants.

## Déroulé

### 1. Préparer l'environnement

Expliquer ce que le participant prépare.

```bash
kubectl config current-context
kubectl create namespace <namespace>
```

Résultat attendu:

```text
namespace/<namespace> created
```

### 2. Déployer les composants

```bash
helmfile apply
```

Résultat attendu:

```text
UPDATED RELEASES:
```

### 3. Observer le comportement

```bash
kubectl get all -n <namespace>
```

Expliquer ce qu'il faut observer et pourquoi.

### 4. Modifier ou provoquer un incident

Décrire la manipulation qui crée un apprentissage: changement de configuration, montée de version, panne simulée, politique réseau, certificat, scaling, etc.

### 5. Corriger et valider

```bash
kubectl wait --for=condition=Available deployment/<name> -n <namespace> --timeout=120s
```

## Validation

Commandes à exécuter pour prouver que l'atelier est réussi:

```bash
kubectl get pods -n <namespace>
kubectl describe <resource> <name> -n <namespace>
curl -i https://<host>
```

Critères de réussite:

- critère observable 1;
- critère observable 2;
- critère observable 3.

## Questions de débrief

- Pourquoi ce composant est-il nécessaire?
- Que se passe-t-il si cette ressource est supprimée?
- Quel signal permet de diagnostiquer le problème?
- Quelle différence entre la solution de l'atelier et une mise en production réelle?

## Nettoyage

Documenter une commande de nettoyage sûre et limitée au périmètre de l'atelier.

```bash
helmfile destroy
kubectl delete namespace <namespace>
```

Pour les ressources cloud:

```bash
tofu destroy
```

Indiquer explicitement les coûts ou ressources qui peuvent rester actifs.

## Pour aller plus loin

- variante plus avancée;
- piste de production;
- documentation officielle pertinente;
- atelier complémentaire dans ce dépôt.

## Notes pour l'animateur

- erreurs fréquentes;
- temps généralement passé par étape;
- points à vérifier avant la session;
- variantes selon le niveau du groupe.
