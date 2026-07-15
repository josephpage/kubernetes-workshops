# Kratix vs Crossplane — Quel socle de Platform Engineering pour des ressources mixtes ?

**Contexte** : une entreprise de ~200 développeurs et ~100 ops/devops qui doit offrir une plateforme de self-service d'infrastructure (Internal Developer Platform) couvrant **deux familles de ressources** :

1. des ressources **Cloud complètement automatisées** (ex. base de données managée Scaleway provisionnée en self-service) ;
2. des ressources **à approbation humaine** via un outil de ticketing, avec **dépendances** entre les deux (ex. un `Secret` injecté dans le `Namespace` créé après approbation d'un ticket).

Les deux ateliers de ce dépôt — [`demos/kratix`](../demos/kratix/README.md) et [`demos/crossplane`](../demos/crossplane/README.md) — réalisent **exactement ce scénario**, ce qui en fait un comparatif terme à terme. Ce rapport synthétise les conclusions.

> **Verdict** : pour ce cas d'usage précis (ressources mixtes Cloud + ticketing + dépendances), **Crossplane est la solution à retenir**. Le ticketing et les dépendances épousent nativement sa boucle de réconciliation et son protocole `RunFunction`, là où Kratix demande du code sur-mesure pour les mêmes besoins. Kratix reste pertinent pour des topologies multi-cluster isolées et l'orchestration de processus hors-Kubernetes.

---

## Tableau de synthèse

| Critère | Kratix | Crossplane | Avantage |
|---|---|---|---|
| **Qualité logicielle** | Pipelines = shell/Python **inline dans le YAML**, parsing YAML « à la main » (`get_val` par split de string), pas de tests | Functions = **vrais projets Python** (pytest, Dockerfile, `pyproject.toml`), compositions déclaratives sans code, `crossplane render` pour valider hors cluster | Crossplane |
| **Facilité de maintenance** | 2 clusters + StateStore S3 + FluxCD + **workflows `delete` à écrire** pour chaque Promise + polling/`workflow-control` à programmer | 1 cluster, **garbage collection native** (ownerReferences), **retry natif** (réconciliation), suppression implicite | Crossplane |
| **Résilience** | Polling synchrone 180 s dans un pod (fragile : pod tuable, ressources consommées) ou async via `workflow-control.yaml` (mieux, mais à coder) | Function **stateless**, deadline courte, la **réconciliation est le retry** — rien à programmer | Crossplane |
| **Sécurité** | RBAC **granulaire par pipeline** (positif) mais **code inline** + client K8s Python dans le pod (surface d'attaque plus large) | `required resources` : la function **déclare** son besoin, Crossplane **résout** (pas de client K8s ni RBAC dans le code) ; mais `ClusterRole` large sur namespaces/secrets à restreindre en production | Nuancé |
| **Adéquation au cas mixte (ticketing + dépendances)** | Ticketing = polling/`workflow-control` **à implémenter** ; dépendances = client K8s + RBAC dédié, **aucun support natif** | Ticketing = réconciliation native (le retry est gratuit) ; dépendances = **`required resources` natifs** du protocole `RunFunction` | Crossplane |
| **DX / self-service (300 utilisateurs)** | API finale identique (`kubectl get postgressqlinstances`) ; Promises monolithiques (API + workflows dans un objet) | API finale identique ; XRD + Composition **séparés** (plus verbeux mais plus clair) | Égal |
| **Maturité / écosystème** | Syntasso, projet plus récent et plus niche, écosystème de Promises limité | Projet **CNCF Graduated** (oct. 2025), soutenu par **Upbound**, large catalogue de providers (AWS/Azure/GCP/Scaleway…), v2 consolidée | Crossplane |
| **Coût d'exploitation** | 2 clusters + bucket S3 + agent GitOps = plus de pièces mobiles à surveiller | 1 cluster, moins d'intermédiaires entre l'intention et la réalisation | Crossplane |

---

## Analyse par critère

### Qualité logicielle
Côté Crossplane, une Composition Function est un **vrai projet** : `pyproject.toml`, tests unitaires (`pytest`), `Dockerfile`, packaging OCI (`xpkg`), et validation hors cluster via `crossplane render`. L'exercice 1 (base de données) est **purement déclaratif** (`function-patch-and-transform`) : aucun code à exécuter. Côté Kratix, les pipelines sont du shell/Python **embarqués dans le YAML de la Promise** — la Promise `ticketing` parse le YAML d'entrée par `l.strip().startswith(key + ':')`, ce qui est fragile et non testable. Pour une équipe de 100 ops/devops qui doit auditer et faire évoluer le code, l'écart est net.

### Facilité de maintenance
Crossplane élimine plusieurs catégories entières de code à maintenir : la suppression (`workflow delete` Kratix → garbage collection native via `ownerReferences`), le retry (`write_retry_after` + `workflow-control.yaml` → réconciliation native ~60 s), et la copie de secrets entre clusters (en mono-cluster, les Managed Resources référencent directement le Secret de l'utilisateur). Kratix impose 2 clusters, un bucket S3, un agent GitOps (FluxCD/ArgoCD) et des workflows `delete` explicites par Promise — autant de pièces mobiles et de code à garder à jour.

### Résilience
La Promise `ticketing` de Kratix implémente un **polling synchrone de 180 s dans un pod** : le pod consomme des ressources pendant 3 minutes, peut être tué par Kubernetes, et échoue en `exit 1` si l'approbation ne vient pas (backoff exponentiel). La Promise `namespace-secret` corrige cela avec `workflow-control.yaml` (async, idempotent) — mais c'est **à coder**. Côté Crossplane, une Composition Function est **stateless** : elle répond en quelques secondes, et la **boucle de réconciliation est le retry** — il n'y a littéralement rien à programmer pour gérer l'attente. L'état vit dans le `status` observé de la XR, ce qui rend la function idempotente par construction.

### Sécurité
Côté Kratix, le RBAC est **granulaire par pipeline** (la Promise `scaleway-db` déclare `secrets: get`, la Promise `namespace-secret` déclare `ticketrequests: get`) — c'est un bon point. Mais le code **inline** et l'usage d'un client K8s Python dans le pod élargissent la surface. Côté Crossplane, le mécanisme de `required resources` est un net progrès : la function **déclare** sa dépendance (ex. « j'ai besoin de la TicketRequest X ») et c'est **Crossplane qui va chercher la ressource** puis rappelle la function — pas de client K8s, pas de RBAC dans le code applicatif. Le revers : la capacité v2 à composer des ressources Kubernetes arbitraires (Namespace, Secret…) exige un `ClusterRole` cluster-wide sur `secrets` (cf. `platform/rbac.yaml`), qu'il faut **restreindre en production** via Kyverno/OPA ou des namespaces dédiés.

### Adéquation au cas mixte (critère discriminant)
Ce critère est **le cœur du besoin** et où l'écart est le plus marqué :
- **Ticketing / approbation humaine** : Crossplane en fait un cas standard de réconciliation (création du ticket au premier passage, vérification à chaque réconciliation, idempotence via le `status.ticketId`). Kratix doit le construire à la main (polling fragile ou `workflow-control` + SDK).
- **Dépendances** : Crossplane offre les **`required resources`** du protocole `RunFunction` — la function déclare son besoin, Crossplane résout la ressource et rappelle la function **dans la même réconciliation**. Kratix **n'a aucun support natif des dépendances** : la Promise `namespace-secret` instancie un `CustomObjectsApi()` Python, gère les `ApiException` 404, et programme ses propres retries. Le README Kratix le reconnaît explicitement : *« Kratix ne gère pas nativement les dépendances. »*

### Maturité et écosystème
Crossplane est un projet **CNCF Graduated** (depuis octobre 2025), soutenu par **Upbound**, avec un large catalogue de providers officiels et communautaires. La v2 utilisée ici (mode Pipeline, Composition Functions, composition de ressources K8s arbitraires) est consolidée. Kratix (Syntasso) est plus récent, plus orienté « orchestrateur de plateforme », avec un écosystème de Promises encore limité. Pour une entreprise qui industrialise sur 300 utilisateurs, la maturité et la disponibilité de talents/prescriptions pèsent.

---

## Recommandation

**Retenir Crossplane** comme socle de Platform Engineering pour ce cas d'usage (ressources Cloud automatisées + ticketing avec dépendances), sous les conditions de mise en production suivantes :

1. **Restreindre le RBAC** : le `ClusterRole` sur `namespaces`/`secrets` doit être encadré (Kyverno/OPA, namespaces dédiés, ou `provider-kubernetes` avec kubeconfig restreint) pour limiter le blast radius.
2. **Industrialiser le CI/CD des Functions** : build multi-arch (`linux/amd64` pour les clusters managés), registry privé, tests `pytest` + `crossplane render` en gate de merge — les ateliers montrent déjà la voie.
3. **HA du control plane** : le cluster Crossplane devient point de défaillance unique ; prévoir un cluster managé multi-AZ et une stratégie de backup/restore des XRs.
4. **Isolation multi-cluster si nécessaire** : reproduire le modèle hub/worker de Kratix avec `provider-kubernetes` (ObjectS ciblant un kubeconfig distant) plutôt que d'exposer le control plane aux équipes applicatives.
5. **Governance des XRD/Compositions** : versionner les abstractions dans un dépôt Git dédié, avec revue ops — ce sont les nouveaux « modules Terraform » de la plateforme.

## Quand quand même choisir Kratix

Kratix reste une option valable si **au moins une** de ces conditions domine :
- **topologie multi-cluster isolée** exigée d'emblée (séparation physique control plane / workloads, régulations, blast radius) — l'architecture hub-and-spoke + StateStore est native ;
- **orchestration de processus hors-Kubernetes** au premier plan (le « Promise-as-a-process » est son angle mort) ;
- **exigence d'audit GitOps dur** : Kratix écrit tous les manifests dans un StateStore (S3/Git), offrant un journal immuable de tout ce qui a été appliqué — propriété utile en contexte régulé.

Dans ces cas, on accepte le surcoût de maintenance (workflows `delete`, polling/async à coder, dépendances à orchestrer) comme le prix d'une isolation et d'un audit renforcés.
