#!/usr/bin/env bash
# Étape 2 de l'atelier : installe Agent Substrate (le runtime de sandboxes d'AX)
# puis crée le WorkerPool sur lequel AX placera ses tâches.
#
# Substrate ne publie pas d'images : son installeur officiel (cmd/ate-setup) les
# construit avec ko depuis le tag ${SUBSTRATE_VERSION} et les pousse dans
# ${IMAGE_REPO}/substrate. Compter 5 à 10 minutes au premier lancement.
source "$(dirname "$0")/lib.sh"

require_cmd go git kubectl kustomize perl
load_workshop_env
check_cluster_prereqs

SUBSTRATE_DIR="${WORK_DIR}/substrate"
clone_at agent-substrate/substrate "${SUBSTRATE_VERSION}" "${SUBSTRATE_DIR}"

kubectl create namespace ate-system --dry-run=client -o yaml | kubectl apply -f -

if [[ "${SNAPSHOT_BACKEND}" == "s3" ]]; then
  # Hors GKE : on greffe le composant non-gke sur l'overlay agentgateway
  # que l'installeur applique (voir platform/substrate/non-gke).
  log "Ajout du composant « non-gke » à l'overlay agentgateway de Substrate"
  rm -rf "${SUBSTRATE_DIR}/manifests/ate-install/components/ax-workshop-non-gke"
  cp -R "${AX_DEMO_DIR}/platform/substrate/non-gke" "${SUBSTRATE_DIR}/manifests/ate-install/components/ax-workshop-non-gke"
  if ! grep -q 'ax-workshop-non-gke' "${SUBSTRATE_DIR}/manifests/ate-install/agentgateway/kustomization.yaml"; then
    (cd "${SUBSTRATE_DIR}/manifests/ate-install/agentgateway" && kustomize edit add component ../components/ax-workshop-non-gke)
  fi

  log "Secret ate-system/ate-snapshot-storage (accès S3 des snapshots)"
  args=(--from-literal=AWS_REGION="${S3_REGION}")
  [[ -n "${S3_ENDPOINT}" ]] && args+=(--from-literal=AWS_ENDPOINT_URL="${S3_ENDPOINT}")
  [[ "${S3_FORCE_PATH_STYLE}" == "true" ]] && args+=(--from-literal=AWS_S3_USE_PATH_STYLE=true)
  [[ -n "${S3_ACCESS_KEY_ID}" ]] && args+=(--from-literal=AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID}" --from-literal=AWS_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY}")
  kubectl -n ate-system create secret generic ate-snapshot-storage "${args[@]}" --dry-run=client -o yaml | kubectl apply -f -

  if [[ "${S3_IN_CLUSTER}" == "true" ]]; then
    log "Déploiement de rustfs (stockage S3 dans le cluster)"
    SNAPSHOT_BUCKET="${SNAPSHOT_LOCATION#gs://}"
    export SNAPSHOT_BUCKET="${SNAPSHOT_BUCKET%%/*}"
    render "${AX_DEMO_DIR}/platform/substrate/rustfs.yaml" | kubectl apply -f -
    kubectl -n ate-system rollout status deployment/rustfs --timeout=5m
    kubectl -n ate-system wait --for=condition=complete job/rustfs-bucket-init --timeout=5m
  fi
fi

# VERSION fige le label ate.dev/substrate-version posé sur les nœuds (sans lui,
# l'installeur utiliserait `git describe --dirty` : le clone vient d'être modifié).
export VERSION="${SUBSTRATE_VERSION}"
export KO_DOCKER_REPO="${IMAGE_REPO}/substrate"
ate_setup() { (cd "${SUBSTRATE_DIR}" && go run ./cmd/ate-setup --no-dev-env --atenet-dataplane agentgateway --rollout-timeout 10m "$@"); }

log "Installation du plan de contrôle Substrate (build ko + déploiement)"
ate_setup deploy ate-system

log "Build de l'image des workers gVisor (ateom-gvisor)"
WORKER_IMAGE="$(ate_setup publish worker-images | awk '$1 == "ateom-gvisor:" {print $2}')"
[[ -n "${WORKER_IMAGE}" ]] || die "référence de l'image ateom-gvisor introuvable"
export WORKER_IMAGE

log "WorkerPool ax-workers"
render "${AX_DEMO_DIR}/platform/substrate/workerpool.yaml" | kubectl apply -f -
kubectl -n ax-workers wait --for=jsonpath='{.status.readyReplicas}'=3 workerpool/ax-workers --timeout=10m

log "Installation du plugin kubectl-ate"
(cd "${SUBSTRATE_DIR}" && go install ./cmd/kubectl-ate)

ok "Agent Substrate ${SUBSTRATE_VERSION} est installé"
kubectl -n ate-system get pods
kubectl get workerpools -A
