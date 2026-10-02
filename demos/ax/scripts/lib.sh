# Fonctions communes aux scripts de l'atelier AX. À sourcer, pas à exécuter.
# shellcheck shell=bash

set -euo pipefail

AX_DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${AX_DEMO_DIR}/.work}"
WORKSHOP_ENV="${WORKSHOP_ENV:-${AX_DEMO_DIR}/workshop.env}"

# shellcheck source=../versions.env
source "${AX_DEMO_DIR}/versions.env"
mkdir -p "${WORK_DIR}"

log()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "${cmd}" >/dev/null 2>&1 || die "commande introuvable : ${cmd} (voir les prérequis du README)"
  done
}

# Charge le contrat généré par OpenTofu (terraform/<cloud>).
load_workshop_env() {
  [[ -f "${WORKSHOP_ENV}" ]] || die "${WORKSHOP_ENV} introuvable : lancez d'abord tofu apply dans terraform/<cloud>"
  # shellcheck source=/dev/null
  source "${WORKSHOP_ENV}"
  [[ -f "${KUBECONFIG}" ]] || die "kubeconfig introuvable : ${KUBECONFIG}"
}

# ko est lancé via `go run` : pas d'installation supplémentaire, version épinglée.
ko() { go run "github.com/google/ko@${KO_VERSION}" "$@"; }

# Clone (ou réutilise) un dépôt GitHub à un tag donné, en lecture seule.
clone_at() {
  local repo="$1" tag="$2" dir="$3"
  if [[ -d "${dir}/.git" ]]; then
    local current
    current="$(git -C "${dir}" describe --tags --exact-match 2>/dev/null || true)"
    [[ "${current}" == "${tag}" ]] || die "${dir} n'est pas au tag ${tag} (trouvé : ${current:-aucun}) ; supprimez-le pour recloner"
    return 0
  fi
  log "Clone de ${repo}@${tag}"
  git clone --quiet --depth 1 --branch "${tag}" "https://github.com/${repo}.git" "${dir}"
}

# Remplace ${VAR} par la valeur de la variable d'environnement VAR (comme envsubst,
# sans dépendre de gettext). Échoue si une variable référencée n'est pas définie.
render() {
  perl -pe 's/\$\{(\w+)\}/defined $ENV{$1} ? $ENV{$1} : die "variable non définie : $1\n"/ge' "$@"
}

# Référence de l'image des sandboxes, épinglée par digest : Substrate refuse les
# ActorTemplates dont l'image n'est désignée que par un tag (« must be pinned by
# digest ») ; un tag peut changer, un golden snapshot doit rester reproductible.
resolve_agent_image() {
  local ref="${AGENT_IMAGE_REPO}:${AGENT_IMAGE_TAG}" digest
  digest="$(docker buildx imagetools inspect "${ref}" --format '{{.Manifest.Digest}}' 2>/dev/null)" \
    || die "image ${ref} introuvable : lancez d'abord scripts/30-build-agent-image.sh"
  echo "${ref}@${digest}"
}

# Vérifie que le cluster sert les APIs de certificats dont Substrate a besoin.
check_cluster_prereqs() {
  local server_version
  server_version="$(kubectl version -o json | perl -0ne 'print "$1.$2" if /"serverVersion".*?"major":\s*"(\d+)".*?"minor":\s*"(\d+)/s')"
  log "Cluster Kubernetes ${server_version} (minimum ${KUBERNETES_MIN_VERSION})"
  kubectl api-resources --api-group=certificates.k8s.io -o name | grep -q '^clustertrustbundles' \
    || die "l'API ClusterTrustBundle n'est pas servie : Kubernetes 1.37+ requis (ou 1.36 avec les APIs bêta activées)"
  kubectl api-resources --api-group=certificates.k8s.io -o name | grep -q '^podcertificaterequests' \
    || die "l'API PodCertificateRequest n'est pas servie : Kubernetes 1.37+ requis"
  # Substrate v0.3.0 écrit les ClusterTrustBundles en v1beta1, version que tous
  # les clusters 1.37 ne servent pas (k3s : --kube-apiserver-arg=runtime-config=...).
  kubectl get --raw /apis/certificates.k8s.io/v1beta1 2>/dev/null | grep -q '"clustertrustbundles"' \
    || die "ClusterTrustBundle n'est pas servi en certificates.k8s.io/v1beta1, que Substrate v0.3.0 utilise (option d'API server runtime-config=certificates.k8s.io/v1beta1=true)"
  ok "APIs ClusterTrustBundle et PodCertificateRequest disponibles"
}
