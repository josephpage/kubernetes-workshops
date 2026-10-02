#!/usr/bin/env bash
# Étape 3 de l'atelier : installe le plan de contrôle AX (Redis, ax-server,
# ax-controller) dans ax-system, puis le CLI `ax` sur le poste.
#
# AX ne publie pas d'images de plan de contrôle : on les construit avec ko depuis
# le tag ${AX_VERSION}, comme le fait `make deploy` en amont.
source "$(dirname "$0")/lib.sh"

require_cmd go git kubectl
load_workshop_env

AX_DIR="${WORK_DIR}/ax"
clone_at google/ax "${AX_VERSION}" "${AX_DIR}"

kubectl get svc api -n ate-system >/dev/null 2>&1 \
  || die "API de Substrate introuvable (svc/api dans ate-system) : lancez d'abord scripts/10-install-substrate.sh"

log "Build des images ax-server et ax-controller (ko) et rendu des manifests"
# Variante locale : KO_DEFAULTPLATFORMS=linux/arm64 (une seule architecture).
(cd "${AX_DIR}" && KO_DOCKER_REPO="${IMAGE_REPO}/ax" ko resolve \
  --base-import-paths --platform="${KO_DEFAULTPLATFORMS:-linux/amd64,linux/arm64}" \
  -f deploy/redis.yaml -f deploy/ax-controller.yaml -f deploy/ax-server.yaml) > "${WORK_DIR}/ax-system.yaml"

log "Déploiement dans ax-system"
kubectl apply -f "${WORK_DIR}/ax-system.yaml"

# En amont, deploy/ax-controller.yaml pointe les snapshots vers un bucket GCS de
# développement (gs://dberkov-gke-dev3/...). On le remplace par le nôtre : c'est
# la seule adaptation nécessaire côté AX.
kubectl -n ax-system set env deployment/ax-controller AX_SNAPSHOTS_BUCKET="${SNAPSHOT_LOCATION}/"

for d in ax-redis ax-server ax-controller; do
  kubectl -n ax-system rollout status "deployment/${d}" --timeout=5m
done

log "Installation du CLI ax ${AX_VERSION}"
(cd "${AX_DIR}" && go install ./cmd/ax)

ok "AX ${AX_VERSION} est installé"
kubectl -n ax-system get pods
echo
echo "Vérifiez que \$(go env GOBIN) (ou \$(go env GOPATH)/bin s'il est vide) est dans votre PATH, puis : ax version && ax ctx"
