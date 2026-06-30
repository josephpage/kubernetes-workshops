# Atelier Kratix : Construire son PaaS Interne (IDP) Multi-Cluster sur Scaleway

Cet atelier pratique propose de concevoir une plateforme de self-service d'infrastructure et de services applicatifs (Internal Developer Platform - IDP) en s'appuyant sur **Kratix**.

Nous allons mettre en place une architecture multi-cluster réelle sur **Scaleway**, utiliser l'**Object Storage Scaleway (S3)** comme magasin d'état (StateStore), et explorer deux manières d'automatiser la fourniture de services :
1.  **L'automatisation moderne (GitOps & Crossplane)** : Provisionnement en self-service d'une base de données managée Scaleway.
2.  **L'automatisation avec approbation humaine (Ticketing Gating)** : Une Promise qui crée un ticket d'approbation sur une console de support, attend la validation manuelle d'un administrateur, et récupère dynamiquement les données saisies par l'approbateur pour configurer l'espace de travail cible (Namespace + Quotas).
3.  **La composition de Promises (Pattern Async)** : Une Promise dépendante qui récupère le namespace créé par la Promise 2 et y injecte un `Secret` Kubernetes, en utilisant le SDK Python officiel `kratix-sdk` et le mécanisme natif `workflow-control.yaml` pour la réconciliation asynchrone.

---

## Résumé

-   **Niveau** : Intermédiaire à Avancé.
-   **Durée cible** : 120 minutes.
-   **Public** : Consultants Cloud/DevOps OCTO Technology et participants aux formations d'architecture Kubernetes.
-   **Environnement cible** : 2 clusters managés **Scaleway Kapsule** (Platform & Worker).

---

## Objectifs pédagogiques

À la fin de cet atelier, les participants sauront :
*   Expliquer l'architecture Hub-and-Spoke de Kratix et le rôle des *Promises*, *StateStores* et *Destinations*.
*   Installer et configurer Kratix en mode multi-cluster avec Scaleway Object Storage.
*   Concevoir une Promise d'infrastructure moderne interfacée avec Crossplane.
*   Concevoir une Promise de processus avec gating humain, capable de faire du polling d'API et de récupérer des données dynamiques post-approbation pour enrichir l'état Kubernetes final.
*   Composer des Promises dépendantes en utilisant le SDK Python `kratix-sdk` et le mécanisme natif `workflow-control.yaml` de Kratix (réconciliation asynchrone non-bloquante).
*   Comparer les architectures de synchronisation basées sur FluxCD (S3-native) et ArgoCD (Git-native).

---

## Concepts manipulés

*   **Kratix** : Promises (API + Workflows/Pipelines), Destinations, BucketStateStore / GitStateStore, Status Updates.
*   **GitOps / Réconciliation** : FluxCD (contrôleur Source/Bucket), ArgoCD.
*   **Infrastructure-as-Code** : Crossplane (Providers, Custom Resources), OpenTofu/Terraform.
*   **Cloud Scaleway** : Kapsule (Kubernetes), Object Storage (S3), Database Instances (simulées via Crossplane CRs).

---

## Architecture cible de l'atelier

L'architecture repose sur deux clusters Kubernetes distincts provisionnés sur Scaleway :

```mermaid
flowchart TD
    subgraph Platform Cluster ["Cluster Platform (Control Plane)"]
        Kratix["Kratix Operator"]
        Ticketing["Fake Ticketing API & UI (Port 30080)"]
    end

    subgraph Object Storage ["Scaleway Cloud Storage (S3)"]
        S3Bucket["S3 Bucket 'kratix-state-store'"]
    end

    subgraph Worker Cluster ["Cluster Worker (Cible Applicative)"]
        GitOps["GitOps Agent (FluxCD ou ArgoCD)"]
        Crossplane["Crossplane Operator (Scaleway Provider)"]
    end

    Developer["Développeur"] -->|1. Crée Request| Platform["Platform Cluster"]
    Kratix -->|2. Exécute Pipeline| PipelinePod["Pipeline Pod (Python/yq)"]
    
    %% Scénario 1 : Crossplane
    PipelinePod -->|3a. Écrit Manifests| S3Bucket
    GitOps -->|4a. Réconcilie depuis| S3Bucket
    GitOps -->|5a. Déploie DatabaseInstance| Crossplane
    
    %% Scénario 2 : Ticketing
    PipelinePod -->|3b. REST POST (Création)| Ticketing
    PipelinePod -->|4b. REST GET (Polling)| Ticketing
    Admin["Opérateur Support"] -->|5b. Approuve & Saisit Quotas| Ticketing
    PipelinePod -->|6b. Récupère Quotas & écrit| S3Bucket
    GitOps -->|7b. Déploie Namespace + Quota| WorkerCluster["Worker Cluster"]
```

---

## Prérequis

1.  **Outils locaux** :
    *   `tofu` ou `terraform` (v1.4+)
    *   `kubectl`
    *   `helm`
2.  **Accès Scaleway** :
    *   Un compte Scaleway avec un projet actif.
    *   Des clés API Scaleway valides configurées dans votre environnement :
        ```bash
        export SCW_ACCESS_KEY="votre_access_key"
        export SCW_SECRET_KEY="votre_secret_key"
        export SCW_DEFAULT_PROJECT_ID="votre_project_id"
        ```

---

## Déroulé de l'atelier

### Étape 1 : Provisionner les clusters Scaleway (Platform & Worker)

Pour simplifier l'installation, un orchestrateur Terraform global a été conçu dans le dossier de l'atelier. Il instancie le module `scaleway-kapsule` à deux reprises : une fois pour la Platform (sans Crossplane/ArgoCD) et une fois pour le Worker (avec Crossplane et ArgoCD activés).

#### 1.1 Déployer l'infrastructure
Rendez-vous dans le dossier Terraform de l'atelier :
```bash
cd demos/kratix/terraform
```

Initialisez et appliquez la configuration (en passant vos clés API Scaleway sous forme de variables Terraform) :
```bash
tofu init
tofu apply \
  -var="scaleway_access_key=$SCW_ACCESS_KEY" \
  -var="scaleway_secret_key=$SCW_SECRET_KEY" \
  -auto-approve
```
*Note : Cette étape provisionne deux clusters Kapsule Scaleway physiques complets, configure Traefik, cert-manager, installe Crossplane ainsi qu'ArgoCD sur le cluster worker, et génère automatiquement le secret d'accès S3 sur la Platform. Compter environ 8 à 12 minutes.*

#### 1.2 Configurer vos contextes kubectl
Une fois le déploiement Terraform terminé, le script écrit les fichiers de configuration kubeconfig directement dans votre répertoire personnel `~/.kube/`.

Configurez vos variables d'environnement dans votre terminal pour basculer facilement :
```bash
export KUBECONFIG_PLATFORM=~/.kube/kubeconfig-kratix-platform
export KUBECONFIG_WORKER=~/.kube/kubeconfig-kratix-worker
```

Testez l'accès et vérifiez que vos deux clusters répondent correctement :
```bash
# Vérifier le cluster Platform
kubectl --kubeconfig=$KUBECONFIG_PLATFORM get nodes

# Vérifier le cluster Worker
kubectl --kubeconfig=$KUBECONFIG_WORKER get nodes
```


---

### Étape 2 : Installer Kratix, le StateStore S3 et le service de Ticketing

#### 2.1 Installation de Kratix sur le cluster Platform (Automatique)
Kratix a été installé automatiquement sur votre cluster Platform lors de l'exécution du code Terraform (`tofu apply`) grâce à sa **chart Helm officielle** (`syntasso/kratix`). 

Vous pouvez vérifier que l'opérateur et les CRDs Kratix sont bien présents sur le cluster Platform :
```bash
# Vérifier l'état de l'opérateur
kubectl --kubeconfig=$KUBECONFIG_PLATFORM get pods -n kratix-platform-system

# Vérifier les CRDs Kratix disponibles
kubectl --kubeconfig=$KUBECONFIG_PLATFORM get crds | grep kratix
```


#### 2.2 Récupérer le nom du bucket S3 créé par Terraform
Le bucket S3 a été provisionné automatiquement par Terraform avec un nom unique (ex: `kratix-state-store-xxxxxxxx`). Vous pouvez récupérer son nom exact dans la sortie de votre commande `tofu apply` précédente ou via la commande suivante :
```bash
# Se placer dans le dossier Terraform de l'atelier
cd demos/kratix/terraform
tofu output kratix_state_store_bucket_name
```
Conservez ce nom dans une variable pour les étapes suivantes :
```bash
export BUCKET_NAME="<nom-de-votre-bucket-recupere>"
```

#### 2.3 Déployer le service de Ticketing simulé sur le cluster Platform
Ce service simule un outil de support JIRA/ServiceNow et propose une page web de validation :
```bash
# Se replacer à la racine du dépôt
cd ../../..
kubectl --kubeconfig=$KUBECONFIG_PLATFORM apply -f demos/kratix/ticketing-service/service.yaml

# Attendre que le service démarre
kubectl --kubeconfig=$KUBECONFIG_PLATFORM wait --for=condition=Available deployment/ticketing-service -n ticketing-system --timeout=120s
```
Exposez l'interface web de ticketing sur votre machine locale :
```bash
kubectl --kubeconfig=$KUBECONFIG_PLATFORM port-forward svc/ticketing-service -n ticketing-system 30080:80
```
Vous pouvez maintenant ouvrir `http://localhost:30080` sur votre navigateur. L'interface (Dark Mode premium) devrait indiquer qu'aucun ticket n'est actif pour le moment.

#### 2.4 Configurer le BucketStateStore et la Destination sur la Platform
Kratix a besoin d'authentification pour écrire dans le compartiment S3 Scaleway. Le secret `scaleway-s3-credentials` contenant vos credentials de connexion a été créé automatiquement sur le cluster Platform par Terraform lors de la première étape.

Appliquez directement la configuration du `BucketStateStore` et de la `Destination` (en veillant à utiliser le bon nom de bucket) :

```bash
# Appliquer la configuration en remplaçant BUCKET_NAME
kubectl --kubeconfig=$KUBECONFIG_PLATFORM apply -f - <<EOF
apiVersion: platform.kratix.io/v1alpha1
kind: BucketStateStore
metadata:
  name: scaleway-s3
  namespace: default
spec:
  endpoint: s3.fr-par.scw.cloud
  insecure: false
  bucketName: ${BUCKET_NAME}
  secretRef:
    name: scaleway-s3-credentials
    namespace: default
---
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: worker-1
spec:
  path: worker-1
  stateStoreRef:
    name: scaleway-s3
    kind: BucketStateStore
EOF
```

---

### Étape 3 : Configurer la synchronisation sur le cluster Worker (ArgoCD vs Flux)

Dans une architecture Hub-and-Spoke, le cluster Worker doit réconcilier les ressources que Kratix dépose dans le bucket S3. Deux approches s'affrontent selon vos préférences de tooling :

#### Approche A : FluxCD (Recommandé avec S3)
FluxCD supporte nativement les buckets S3 via son contrôleur `Source`.
*Note : L'installation de **FluxCD** (via Helm) et la création du secret `scaleway-s3-credentials-flux` ont été réalisées automatiquement sur le cluster Worker par Terraform.*

Il vous suffit de configurer la synchronisation du bucket sur le cluster Worker (en remplaçant `BUCKET_NAME` par le nom de votre bucket) :

```bash
# Configurer la réconciliation du bucket
kubectl --kubeconfig=$KUBECONFIG_WORKER apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: Bucket
metadata:
  name: kratix-worker-bucket
  namespace: flux-system
spec:
  interval: 10s
  provider: generic
  bucketName: ${BUCKET_NAME} # /!\ Remplacer par votre bucket
  endpoint: s3.fr-par.scw.cloud
  insecure: false
  secretRef:
    name: scaleway-s3-credentials-flux
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kratix-worker-kust
  namespace: flux-system
spec:
  interval: 10s
  path: ./worker-1
  prune: true
  sourceRef:
    kind: Bucket
    name: kratix-worker-bucket
EOF
```

#### Approche B : ArgoCD (Idéal avec GitStateStore)
ArgoCD n'est pas conçu pour s'abonner nativement à un bucket S3 de fichiers YAML bruts (il est conçu pour Git). Si ArgoCD est l'outil standard de votre organisation :
1.  **Recommandation** : Configurer la Destination Kratix en tant que `GitStateStore` (Kratix pousse sur GitHub/GitLab). ArgoCD s'abonne alors nativement au dépôt Git.
2.  **Alternative (S3 Polling)** : Si vous devez utiliser S3 avec ArgoCD, vous devez déployer un petit CronJob sur le worker qui effectue un `rclone` ou `aws s3 sync` depuis votre bucket vers un dossier local, ou utiliser un Config Management Plugin (CMP) sidecar dans ArgoCD.

*(Dans le cadre de cet atelier, nous utiliserons l'Approche A avec FluxCD pour valider les flux S3 sans complexifier l'installation d'ArgoCD).*

---

### Étape 4 : Exercice 1 - La Promise d'Infrastructure Moderne (Crossplane)

Dans cet exercice, nous allons analyser et déployer la Promise `scaleway-db`. Le but est d'exposer une API simplifiée aux développeurs pour qu'ils puissent commander une base de données PostgreSQL de manière autonome.

*Note : Pour simplifier cet exercice, **Crossplane** ainsi que son **Provider Scaleway** ont été installés et configurés automatiquement sur le cluster Worker via Terraform. Le secret contenant vos clés d'API Scaleway a été automatiquement déployé dans le namespace `crossplane-system` sur le Worker.*

#### 4.1 Comprendre la Promise et la gestion des Secrets
La Promise est définie dans [promises/scaleway-db/promise.yaml](promises/scaleway-db/promise.yaml). Contrairement à des valeurs écrites en texte brut dans la requête, cette Promise source de manière sécurisée les mots de passe de base de données à partir d'un secret Kubernetes sur le cluster Platform.

Cette Promise permet de configurer le **nom** et la **clé** du secret contenant les mots de passe de base de données via l'API grâce aux propriétés `.spec.adminPasswordSecretRef` et `.spec.userPasswordSecretRef`.

Le pipeline Kratix (qui s'exécute sous l'image `alpine/k8s:1.30.2`) possède des permissions RBAC pour lire les secrets de l'espace de travail. Il extrait les références fournies par l'utilisateur (ou utilise les valeurs par défaut `database-passwords` avec les clés `admin-password`/`user-password`), interroge l'API Kubernetes pour lire les secrets et génère les 5 manifests requis pour Crossplane et les secrets sur le cluster Worker :
1.  Les secrets de mots de passe de BDD (`v1/Secret`) répliqués dans le namespace `crossplane-system` sur le Worker.
2.  L'instance de BDD physique (`Instance` de type `rdb.scaleway.upbound.io/v1alpha1`).
3.  La base de données logique (`Database`).
4.  L'utilisateur applicatif (`User`).
5.  Les privilèges d'accès associés (`Privilege`).

#### 4.2 Validation de l'Exercice 1

1.  **Créer le secret contenant vos mots de passe** sur le cluster Platform (dans le namespace de travail, ici `default`) :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_PLATFORM create secret generic database-passwords \
      --from-literal=admin-password="MonSuperPasswordAdmin123" \
      --from-literal=user-password="MonSuperPasswordUser123"
    ```

2.  **Appliquer la Promise** sur la Platform :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_PLATFORM apply -f promises/scaleway-db/promise.yaml
    ```

3.  **Soumettre une demande de base de données** en tant que développeur :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_PLATFORM apply -f promises/scaleway-db/request-example.yaml
    ```

4.  **Vérifier la génération des manifests** :
    Le pipeline Kratix doit s'exécuter et générer le fichier `database.yaml` dans votre compartiment S3 sous la structure `worker-1/resources/...`.

5.  **Vérifier le déploiement sur le Worker** :
    Le contrôleur FluxCD va appliquer les ressources sur le cluster worker. Vérifiez que l'instance de base de données est en cours de création :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_WORKER get instances.rdb.scaleway.upbound.io
    kubectl --kubeconfig=$KUBECONFIG_WORKER get databases.rdb.scaleway.upbound.io
    kubectl --kubeconfig=$KUBECONFIG_WORKER get users.rdb.scaleway.upbound.io
    ```

#### 4.3 Supprimer une instance de base de données

Quand vous supprimez une requête `PostgresSQLInstance`, la Promise exécute le workflow `delete` qui génère les manifests de suppression. Ces derniers sont envoyés au Worker via le StateStore et synchronisés par FluxCD.

Pour démolir l'instance créée à l'étape précédente :

```bash
kubectl --kubeconfig=$KUBECONFIG_PLATFORM delete postgressqlinstances.scaleway.octo.com <nom-de-la-ressource>
```

Kratix va alors :
1.  Exécuter le pipeline `delete` qui génère les manifests avec `deletionPolicy: Delete`.
2.  Écrire ces manifests dans `/kratix/output/database.yaml`.
3.  FluxCD sur le Worker synchronise les changements.
4.  **Crossplane supprime la ressource Kubernetes ET l'instance PostgreSQL réelle chez Scaleway** (et ses secrets associés).

**Observation pédagogique** : Cette suppression est **irréversible**. Vous verrez en temps réel :
- Sur le Platform : la ressource `PostgresSQLInstance` disparaît.
- Sur le Worker : les Custom Resources Crossplane (`Instance`, `Database`, `User`, `Privilege`) sont supprimées.
- Chez Scaleway : l'instance PostgreSQL et ses données sont effectivement détruites.

##### Alternative en Production : `deletionPolicy: Orphan`

Dans un environnement de production réel, on utilise souvent `deletionPolicy: Orphan` pour protéger les données. Cela signifie :
- **Ressources Kubernetes** : supprimées.
- **Ressource réelle (PostgreSQL chez Scaleway)** : **conservée** ("orphanée").

Vous auriez alors une chance de récupérer les données avant une destruction manuelle ultérieure. Pour l'implémenter, changez simplement `deletionPolicy: Delete` en `deletionPolicy: Orphan` dans le pipeline `delete`.

**Pédagogiquement, ce manifest utilise `Delete` pour montrer le cycle complet.**

---

### Étape 5 : Exercice 2 - La Promise de Processus Hérité avec Validation Manuelle (Gating)

Cet exercice illustre comment Kratix peut s'interfacer avec un processus non-Kubernetes (système de ticketing interne). Le pipeline de la Promise implémente un **workflow d'approbation asynchrone** :

1.  **Création du ticket** : POST vers l'API de ticketing, récupération du `ticket_id`.
2.  **Polling synchrone** : Boucle qui interroge toutes les 5 secondes l'état du ticket (timeout 3 minutes).
3.  **Récupération des données** : Une fois approuvé, l'opérateur a saisi un namespace et des quotas via l'UI.
4.  **Génération des manifests** : Création d'un `Namespace` et d'un `ResourceQuota` avec les données saisies.

La Promise complète est déjà présente dans [promises/ticketing/promise.yaml](promises/ticketing/promise.yaml). Voici comment elle fonctionne :

#### Comment fonctionne le pipeline `configure`

**Étape 1 - Création du ticket (Extraction de l'input)**
```python
# Lire la requête TicketRequest depuis /kratix/input/object.yaml
title = get_val('title')
description = get_val('description')
requester = get_val('requester')
ticket_id = get_val('ticketId')  # Vide si première exécution

if not ticket_id:
    # POST /tickets avec les données de la requête
    payload = {"title": f"[{res_name}] {title}", "description": description, ...}
    response = urlopen(Request(f"{api_url}/tickets", data=payload, ...))
    ticket_id = response['ticket_id']
```

Kratix écrit le statut initial `Pending` avec le `ticket_id` dans `/kratix/metadata/status.yaml`. Cela permet à la ressource `TicketRequest` de tracer le ticket.

**Étape 2 - Polling de l'approbation**
```python
# Boucle tant que timeout non dépassé
while time.time() - start_time < 180:  # 3 minutes
    response = urlopen(Request(f"{api_url}/tickets/{ticket_id}"))
    if response['status'] == 'Approved':
        output_data = response['output_data']  # Les données saisies par l'opérateur
        approved_by = response['approved_by']
        break
    time.sleep(5)  # Attendre 5 secondes avant le prochain poll
```

Si l'approbation ne vient pas à temps, le pipeline échoue (exit 1) et met à jour le statut à `Failed`.

**Étape 3 - Génération des manifests finaux**
```python
# Extraire les données saisies par l'opérateur
ns_name = output_data.get('namespace_name', 'default-namespace')
cpu_limit = output_data.get('cpu_limit', '1')
memory_limit = output_data.get('memory_limit', '2Gi')

# Générer le Namespace et le ResourceQuota
manifests = f"""apiVersion: v1
kind: Namespace
metadata:
  name: {ns_name}
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: platform-quota
  namespace: {ns_name}
spec:
  hard:
    limits.cpu: "{cpu_limit}"
    limits.memory: "{memory_limit}"
"""
```

Kratix écrit les manifests dans `/kratix/output/workspace.yaml`. FluxCD sur le Worker applique automatiquement le Namespace et le ResourceQuota.

#### Validation de l'Exercice 2

1.  **Appliquez la Promise** sur la Platform :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_PLATFORM apply -f promises/ticketing/promise.yaml
    ```

2.  **Déclarez une requête de ticket** :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_PLATFORM apply -f promises/ticketing/request-example.yaml
    ```

3.  **Observez le statut initial** :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_PLATFORM get ticketrequests -o yaml
    ```
    Vous verrez le statut `Pending` avec le `ticketId` (ex: `TICKET-1`). Le pod du pipeline est maintenant en boucle de polling.

4.  **Approuvez le ticket dans l'UI** :
    *   Ouvrez `http://localhost:30080` sur votre navigateur.
    *   Saisissez un namespace et des limites (ex: namespace = `dev-workspace-1`, CPU = `4`, Mémoire = `8Gi`).
    *   Cliquez sur **"Approuver & Renseigner les Données"**.

5.  **Observez le résultat** :
    *   Le pod du pipeline sort de sa boucle de polling.
    *   Le statut passe à `Approved` avec les métadonnées (namespaceName, cpuLimit, memoryLimit, approvedBy, resolvedAt).
    *   Le namespace et les quotas sont appliqués sur le cluster Worker via FluxCD. Vérifiez :
        ```bash
        kubectl --kubeconfig=$KUBECONFIG_WORKER get ns
        kubectl --kubeconfig=$KUBECONFIG_WORKER get resourcequota -n <nom-du-namespace>
        ```

#### 5.1 Supprimer une requête de ticket

Quand vous supprimez une `TicketRequest`, la Promise exécute le workflow `delete`. Ce pipeline génère un manifest de suppression qui supprime le Namespace (et son ResourceQuota) du cluster Worker.

```bash
kubectl --kubeconfig=$KUBECONFIG_PLATFORM delete ticketrequests.platform.octo.com <nom-de-la-ressource>
```

Kratix va alors :
1.  Exécuter le pipeline `delete` qui récupère le nom du namespace depuis le statut.
2.  Générer un manifest de suppression du Namespace.
3.  FluxCD sur le Worker synchronise et **supprime le Namespace et son ResourceQuota**.

**Important** : Cette action est irréversible. Elle supprime effectivement l'espace de travail provisionné sur le Worker.

---

### Étape 6 : Exercice 3 - Promise dépendante avec création de Secret (Pattern Async)

Cet exercice illustre un concept avancé : **une Promise qui en dépend d'une autre**. La Promise `namespace-secret` ne peut s'exécuter que si une `TicketRequest` (créée via la Promise 2) a été approuvée. Elle récupère dynamiquement le nom du namespace créé par la Promise 2 et y déploie un `Secret` Kubernetes.

Contrairement à la Promise 2 qui utilise un **polling synchrone** (le pod reste actif 3 minutes), cette Promise 3 montre un pattern **plus production-like** : la **réconciliation asynchrone non-bloquante**.

#### Le concept de dépendance entre Promises

Kratix ne gère pas nativement les dépendances entre Promises. C'est au pipeline de la Promise dépendante d'implémenter cette logique :

1. Le pipeline lit le statut de la `TicketRequest` référencée via l'API Kubernetes (client Python `kubernetes`), en utilisant le SDK Kratix (`kratix-sdk`) pour lire l'input et écrire les outputs.
2. Si la `TicketRequest` est `Approved` → le pipeline récupère `status.namespaceName` et génère le `Secret` via `sdk.write_output()`.
3. Si la `TicketRequest` est encore `Pending` → le pipeline appelle `sdk.write_retry_after(timedelta(seconds=30))` qui écrit `/kratix/metadata/workflow-control.yaml`, puis se termine proprement (exit 0).
4. Kratix lit ce fichier et **relance automatiquement le pipeline** après 30 secondes, sans garder de pod actif. Le cycle se répète jusqu'à ce que la `TicketRequest` soit approuvée.

#### Comment fonctionne le pipeline `configure` (Python)

**Étape 1 - Lecture de la requête via le SDK Kratix**
```python
from kratix_sdk import KratixSDK, Status
from kubernetes import client, config

# Initialiser le SDK Kratix
sdk = KratixSDK()

# Lire la requête via le SDK (lit /kratix/input/object.yaml)
resource = sdk.read_resource_input()
ticket_request_name = resource.get_value('spec.ticketRequestName')

# Interroger le statut de la TicketRequest référencée via l'API K8s
config.load_incluster_config()
api = client.CustomObjectsApi()
ticket = api.get_namespaced_custom_object(
    group='platform.octo.com', version='v1alpha1',
    namespace=ticket_request_namespace, plural='ticketrequests',
    name=ticket_request_name
)
```

**Étape 2 - Branchement selon le statut**
```python
ticket_state = ticket['status']['status']
namespace_name = ticket['status']['namespaceName']

if ticket_state == 'Approved' and namespace_name:
    # Générer le Secret via le SDK
    manifest_bytes = yaml.dump(secret_manifest).encode('utf-8')
    sdk.write_output('secret.yaml', manifest_bytes)

    status = Status()
    status.set('status', 'Ready')
    status.set('namespaceName', namespace_name)
    sdk.write_status(status)

elif ticket_state == 'Pending':
    # Pattern async natif : sdk.write_retry_after() écrit workflow-control.yaml
    sdk.write_retry_after(timedelta(seconds=30), message="En attente...")
    sdk.write_status(Status(...))
    sys.exit(0)  # Le pod se termine, Kratix le relancera dans 30s
```

**Le SDK `kratix-sdk`** ([documentation](https://syntasso.github.io/kratix-python/kratix_sdk.html)) encapsule les interactions avec les répertoires Kratix (`/kratix/input`, `/kratix/output`, `/kratix/metadata`). La méthode `write_retry_after()` écrit le fichier `workflow-control.yaml` avec le délai spécifié, déléguant la gestion du requeue à Kratix de façon native.

**Avantages du pattern async vs polling synchrone** :
- Le pod ne consomme des ressources que pendant quelques secondes (pas 3 minutes).
- Le pod ne peut pas être tué par Kubernetes pendant une longue attente.
- Le pattern est **idempotent** : le pipeline peut être relancé N fois sans effet de bord.
- C'est le même pattern utilisé par les contrôleurs Kubernetes (reconciliation loop).
- **Aucun RBAC `patch` nécessaire** : le pipeline n'a pas besoin de modifier sa propre ressource.

#### Gestion des erreurs et auto-réconciliation

Un aspect crucial de cette Promise est sa **gestion gracieuse des erreurs**. Contrairement à la Promise 2 qui termine en `sys.exit(1)` en cas d'échec (ce qui crée un Job Kubernetes en échec et déclenche un backoff exponentiel), la Promise 3 utilise le mécanisme `write_retry_after()` pour **tous** les cas d'erreur :

| Situation | Statut écrit | Retry | Comportement |
|---|---|---|---|
| `TicketRequest` introuvable (404) | `WaitingDependency` | 60s | Message indique que la Promise `ticketing-gating` doit être installée |
| `TicketRequest` encore `Pending` | `Pending` | 30s | Message indique d'attendre l'approbation |
| `TicketRequest` en `Failed` | `WaitingDependency` | 120s | Message indique que le ticket doit être résolu |
| Statut inconnu | `WaitingDependency` | 60s | Message indique une nouvelle tentative |
| Erreur API K8s (RBAC, connexion) | `WaitingDependency` | 60s | Message indique l'erreur technique |

```python
except ApiException as e:
    if e.status == 404:
        # La TicketRequest n'existe pas — retry gracieux sans échec
        msg = (f"TicketRequest '{ticket_request_name}' introuvable. "
               f"Vérifiez que la Promise 'ticketing-gating' est installée.")
        status = Status()
        status.set('status', 'WaitingDependency')
        status.set('message', msg)
        sdk.write_status(status)
        sdk.write_retry_after(timedelta(seconds=60), message=msg)
        sys.exit(0)  # Exit 0 : pas d'échec, Kratix requeue proprement
```

**Pourquoi `sys.exit(0)` et non `sys.exit(1)` ?**

- `sys.exit(1)` → le Job Kubernetes est marqué `Failed`, Kratix incrémente `workflowsFailed`, et Kubernetes applique un backoff exponentiel (10s, 20s, 40s, ... jusqu'à 6 min). L'erreur est "bruyante" et le retry n'est pas contrôlable.
- `sys.exit(0)` + `write_retry_after()` → le Job est marqué `Succeeded`, Kratix lit `workflow-control.yaml` et requeue après le délai exact spécifié. Le statut de la ressource reste propre et informatif.

La CRD définit également `subresources.status: {}` pour permettre des mises à jour de statut isolées (sans re-soumettre le `spec`), et le schéma de statut documente les valeurs possibles : `Pending`, `Ready`, `Failed`, `WaitingDependency`.

#### Validation de l'Exercice 3

1.  **Prérequis** : Avoir terminé l'Exercice 2 et avoir une `TicketRequest` approuvée (`request-new-env`).

2.  **Appliquez la Promise** sur la Platform :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_PLATFORM apply -f promises/namespace-secret/promise.yaml
    ```

3.  **Déclarez une requête de secret** :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_PLATFORM apply -f promises/namespace-secret/request-example.yaml
    ```

4.  **Observez le statut initial** :
    ```bash
    kubectl --kubeconfig=$KUBECONFIG_PLATFORM get namespacesecretrequests -o yaml
    ```
    - Si la `TicketRequest` est déjà `Approved` : le statut passe directement à `Ready` et le `Secret` est généré.
    - Si la `TicketRequest` est encore `Pending` : le statut reste `Pending` avec le message d'attente. Le pipeline s'est terminé proprement et sera re-déclenché par Kratix.

5.  **Observez le résultat sur le Worker** :
    ```bash
    # Récupérer le nom du namespace créé par la TicketRequest
    NAMESPACE=$(kubectl --kubeconfig=$KUBECONFIG_PLATFORM get ticketrequest request-new-env -o jsonpath='{.status.namespaceName}')

    # Vérifier que le Secret a été créé dans ce namespace
    kubectl --kubeconfig=$KUBECONFIG_WORKER get secret app-config -n $NAMESPACE -o yaml
    ```
    Vous devriez voir le Secret `app-config` avec les clés `DATABASE_URL`, `API_KEY` et `LOG_LEVEL` (en base64).

#### 6.1 Supprimer une requête de secret

Quand vous supprimez une `NamespaceSecretRequest`, la Promise exécute le workflow `delete`. Ce pipeline récupère le nom du namespace depuis le statut et génère un manifest de suppression du `Secret`.

```bash
kubectl --kubeconfig=$KUBECONFIG_PLATFORM delete namespacesecretrequests.platform.octo.com secret-for-qa-env
```

Kratix va alors :
1.  Exécuter le pipeline `delete` qui récupère le namespace depuis le statut (ou depuis la `TicketRequest`).
2.  Générer un manifest de suppression du `Secret`.
3.  FluxCD sur le Worker synchronise et **supprime le `Secret` du namespace**.

**Important** : Le namespace lui-même n'est pas supprimé (il est géré par la Promise 2). Seul le `Secret` est retiré.

---

## Questions de débriefing

1.  **Pourquoi Kratix est-il qualifié d'orchestrateur de plateforme ?** En quoi diffère-t-il d'un simple opérateur Kubernetes classique comme Crossplane ?
2.  **Quel est l'intérêt du couplage avec un StateStore (comme S3 ou Git) ?** Pourquoi Kratix n'applique-t-il pas directement les ressources sur le cluster worker via des clients Kubernetes ?
3.  **Quels sont les avantages et inconvénients d'un gating humain dans un pipeline de plateforme ?** Comment gérer la haute disponibilité des pods de pipeline si l'attente dure plusieurs heures/jours ? (Piste : utiliser des contrôleurs asynchrones ou des webhooks plutôt qu'un polling synchrone dans un Pod).
4.  **Si vous deviez remplacer FluxCD par ArgoCD, comment modifieriez-vous la Promise ?** Quelle configuration de StateStore utiliseriez-vous et pourquoi ?
5.  **Comparez les patterns de polling synchrone (Exercice 2) et de réconciliation asynchrone via `workflow-control.yaml` (Exercice 3).** Quels sont les trade-offs en termes de consommation de ressources, de résilience et de complexité d'implémentation ? Dans quel cas préféreriez-vous l'un ou l'autre ?
6.  **Comment pourriez-vous formaliser la dépendance entre Promises ?** Kratix ne gère pas nativement les dépendances. Quelles approches envisageriez-vous pour rendre ce pattern plus générique et réutilisable (webhooks, contrôleurs personnalisés, CRD de dépendance) ?

---

## Nettoyage

Pour éviter des coûts cloud inutiles sur votre compte Scaleway, détruisez les deux clusters ainsi que le compartiment S3 :

```bash
# Se rendre dans le dossier Terraform de l'atelier
cd demos/kratix/terraform

# Détruire les deux clusters Scaleway et le bucket S3
tofu destroy -auto-approve
```

---

## Pour aller plus loin

*   **Gestion asynchrone durable** : Dans une production réelle, faire un polling de 3 minutes dans un Pod est une mauvaise pratique (le pod consomme des ressources et peut être tué par Kubernetes). On préférera concevoir une Promise qui se termine immédiatement après la création du ticket, et configurer le système de ticketing pour qu'il fasse un appel d'API de retour (Webhook / callback) vers le Kubernetes API de la Platform pour mettre à jour la ressource Kratix, ce qui déclenchera à nouveau le pipeline (réconciliation asynchrone). La Promise 3 de cet atelier illustre d'ailleurs une alternative plus production-like avec `workflow-control.yaml`.
*   **Sécurisation des Secrets** : Intégrez HashiCorp Vault ou Scaleway Secret Manager pour distribuer dynamiquement les credentials de base de données générés par Crossplane.
*   **Composition de Promises** : Explorez comment créer un contrôleur personnalisé qui surveille les statuts de plusieurs Promises et déclenche automatiquement les Promises dépendantes, plutôt que de laisser chaque Promise s'auto-replanifier.
