#!/usr/bin/env bash
# Nettoyage de la variante locale : supprime ce que l'atelier a installé dans le
# cluster k3s du profil Colima, le registre local et les fichiers générés.
# La VM et le cluster sont conservés (ils servent à d'autres ateliers).
source "$(dirname "$0")/../scripts/lib.sh"

require_cmd colima docker kubectl
load_workshop_env
[[ "${AX_CLOUD}" == "local" ]] || die "${WORKSHOP_ENV} n'est pas celui de la variante locale (AX_CLOUD=${AX_CLOUD})"
COLIMA_PROFILE="${CLUSTER_NAME#colima-}"

log "Suppression des namespaces de l'atelier"
kubectl delete namespace llm-gateway ax-system ax-workers ate-system --ignore-not-found --wait=true

log "Suppression du registre local et des images de l'atelier"
docker rm -f ax-registry >/dev/null 2>&1 || true
docker images --format '{{.Repository}} {{.ID}}' | awk '$1 ~ /^localhost:5001\// {print $2}' | sort -u \
  | xargs docker rmi -f >/dev/null 2>&1 || true

# Le disque de la VM ne rend l'espace libéré à macOS qu'après un TRIM.
log "Restitution de l'espace disque à macOS (fstrim)"
colima ssh -p "${COLIMA_PROFILE}" -- sudo fstrim /var/lib/docker

rm -f "${KUBECONFIG}" "${WORKSHOP_ENV}"
ok "Variante locale nettoyée"
echo "Restent dans le cluster les ressources globales de Substrate (CRD, ClusterTrustBundles, webhooks)."
echo "Pour repartir d'un cluster vierge : colima kubernetes reset -p ${COLIMA_PROFILE}"
