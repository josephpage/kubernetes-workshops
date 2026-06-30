#!/usr/bin/env bash

set -euo pipefail

# Couleurs pour le logging
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Vérification des prérequis
log_info "Vérification des prérequis locaux..."
PREREQS=("kind" "kubectl" "helm" "docker")
for cmd in "${PREREQS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "La commande '$cmd' est requise mais n'est pas installée. Veuillez l'installer."
        exit 1
    fi
done
log_success "Prérequis OK !"

# 2. Nettoyage des clusters existants (si nécessaire)
log_info "Suppression des anciens clusters KinD si présents..."
kind delete cluster --name kratix-platform || true
kind delete cluster --name kratix-worker || true

# 3. Création du cluster Platform
log_info "Création du cluster KinD 'kratix-platform'..."
kind create cluster --name kratix-platform --config - <<EOF
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30090
    hostPort: 30090
    listenAddress: "0.0.0.0"
  - containerPort: 30091
    hostPort: 30091
    listenAddress: "0.0.0.0"
  - containerPort: 30080
    hostPort: 30080
    listenAddress: "0.0.0.0"
EOF

# 4. Création du cluster Worker
log_info "Création du cluster KinD 'kratix-worker'..."
kind create cluster --name kratix-worker

# Connexion réseau KinD inter-cluster (normalement ils sont tous les deux sur le bridge "kind")
log_info "Vérification de la connectivité réseau KinD..."
docker network connect kind kratix-platform-control-plane || true
docker network connect kind kratix-worker-control-plane || true

# 5. Installation de cert-manager
log_info "Installation de cert-manager sur les deux clusters..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml --context kind-kratix-platform
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml --context kind-kratix-worker

log_info "Attente du démarrage de cert-manager sur les deux clusters..."
kubectl wait --for=condition=Ready pods --all -n cert-manager --context kind-kratix-platform --timeout=120s
kubectl wait --for=condition=Ready pods --all -n cert-manager --context kind-kratix-worker --timeout=120s
log_success "cert-manager est prêt !"

# 6. Installation de Kratix sur le cluster Platform
log_info "Installation de Kratix sur 'kratix-platform'..."
kubectl apply -f https://raw.githubusercontent.com/syntasso/kratix/main/distribution/single-cluster/install-all-in-one.yaml --context kind-kratix-platform

log_info "Attente du démarrage de Kratix..."
kubectl wait --for=condition=Available deployment/kratix-platform-controller-manager -n kratix-platform-system --context kind-kratix-platform --timeout=120s
log_success "Kratix est prêt !"

# 7. Installation de MinIO (StateStore) sur le cluster Platform
log_info "Déploiement de MinIO sur le cluster Platform..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubectl apply -f "${SCRIPT_DIR}/minio.yaml" --context kind-kratix-platform

log_info "Attente du démarrage de MinIO..."
kubectl wait --for=condition=Available deployment/minio -n kratix-platform-system --context kind-kratix-platform --timeout=120s
log_success "MinIO est prêt !"

# Création du bucket 'kratix' dans MinIO
log_info "Création du bucket 'kratix' dans MinIO..."
kubectl run mc-setup --context kind-kratix-platform --namespace kratix-platform-system --image=minio/mc --restart=Never --rm -i -- \
  config host add local http://minio.kratix-platform-system.svc.cluster.local:9000 minioadmin minioadmin && \
  kubectl run mc-bucket --context kind-kratix-platform --namespace kratix-platform-system --image=minio/mc --restart=Never --rm -i -- \
  mb local/kratix || true

# 8. Installation du service de ticketing (Fake ticketing API)
log_info "Déploiement du service de ticketing sur le cluster Platform..."
kubectl apply -f "${SCRIPT_DIR}/../ticketing-service/service.yaml" --context kind-kratix-platform

log_info "Attente du démarrage du service de ticketing..."
kubectl wait --for=condition=Available deployment/ticketing-service -n ticketing-system --context kind-kratix-platform --timeout=120s
log_success "Service de ticketing prêt !"

# 9. Configuration du StateStore et de la Destination sur le cluster Platform
log_info "Configuration du StateStore et de la Destination sur le cluster Platform..."
kubectl apply --context kind-kratix-platform -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: default
type: Opaque
stringData:
  accessKeyID: minioadmin
  secretAccessKey: minioadmin
---
apiVersion: platform.kratix.io/v1alpha1
kind: BucketStateStore
metadata:
  name: default
  namespace: default
spec:
  endpoint: minio.kratix-platform-system.svc.cluster.local:9000
  insecure: true
  bucketName: kratix
  secretRef:
    name: minio-credentials
    namespace: default
---
apiVersion: platform.kratix.io/v1alpha1
kind: Destination
metadata:
  name: worker-1
spec:
  path: worker-1
  stateStoreRef:
    name: default
    kind: BucketStateStore
EOF
log_success "Destination 'worker-1' enregistrée !"

# 10. Installation et configuration de FluxCD sur le cluster Worker
log_info "Installation de FluxCD sur le cluster Worker..."
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml --context kind-kratix-worker

log_info "Attente du démarrage de FluxCD..."
kubectl wait --for=condition=Ready pods --all -n flux-system --context kind-kratix-worker --timeout=120s
log_success "FluxCD installé !"

log_info "Configuration de la synchronisation FluxCD sur le cluster Worker..."
kubectl apply --context kind-kratix-worker -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: flux-system
type: Opaque
stringData:
  accesskey: minioadmin
  secretkey: minioadmin
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: Bucket
metadata:
  name: kratix-worker-bucket
  namespace: flux-system
spec:
  interval: 10s
  provider: generic
  bucketName: kratix
  endpoint: kratix-platform-control-plane:30090
  insecure: true
  secretRef:
    name: minio-credentials
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
log_success "Synchronisation FluxCD configurée avec succès !"

log_success "================================================================="
log_success " L'environnement Kratix Multi-Cluster est entièrement prêt !"
log_success "================================================================="
log_success " - Cluster Platform : context 'kind-kratix-platform'"
log_success "   └─ Console MinIO : http://localhost:30091 (minioadmin / minioadmin)"
log_success "   └─ Ticketing UI  : http://localhost:30080"
log_success " - Cluster Worker   : context 'kind-kratix-worker'"
log_success "================================================================="
