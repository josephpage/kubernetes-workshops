#!/usr/bin/env bash
# Étape 0 de la variante locale : remplace `tofu apply` par le cluster k3s du
# profil Colima « kubernetes ». Produit le même demos/ax/workshop.env que les
# Terraform : les scripts et les exercices de l'atelier restent identiques.
#
# Le LLM de l'agent est celui du poste (LM Studio, Ollama, llama.cpp...), via
# son API compatible OpenAI :
#   LOCAL_LLM_URL=http://127.0.0.1:1234 LOCAL_LLM_MODEL=<modèle> \
#   LOCAL_LLM_API_KEY=<jeton, si le serveur en exige un> ./local/up.sh
# Les valeurs sont conservées dans workshop.env : un nouveau lancement (par
# exemple après un redémarrage de la VM) n'a pas besoin de les repréciser.
#
# Ce script ne crée pas la VM (voir « Variante locale » dans le README) :
#   colima start -p kubernetes
source "$(dirname "$0")/../scripts/lib.sh"

require_cmd colima docker kubectl curl openssl

COLIMA_PROFILE="${COLIMA_PROFILE:-kubernetes}"
KUBE_CONTEXT="colima-${COLIMA_PROFILE}"
REGISTRY_NAME=ax-registry
REGISTRY_PORT=5001
LOCAL_KUBECONFIG="${HOME}/.kube/kubeconfig-ax-local"

colima status -p "${COLIMA_PROFILE}" >/dev/null 2>&1 \
  || die "profil Colima « ${COLIMA_PROFILE} » arrêté ou absent : colima start -p ${COLIMA_PROFILE} (voir le README)"

# Le workshop.env d'une session cloud contient ses propres secrets : on ne
# l'écrase pas.
if [[ -f "${WORKSHOP_ENV}" ]] && ! grep -q '^export AX_CLOUD="local"$' "${WORKSHOP_ENV}"; then
  die "${WORKSHOP_ENV} appartient à une session cloud : détruisez-la (tofu destroy) ou déplacez ce fichier"
fi

# Valeur d'un lancement précédent (vide sinon), lue en sourçant workshop.env
# dans un sous-shell, comme le font les scripts de l'atelier.
previous() {
  [[ -f "${WORKSHOP_ENV}" ]] || return 0
  # shellcheck source=/dev/null
  (source "${WORKSHOP_ENV}" >/dev/null 2>&1 && printf '%s' "${!1:-}")
}

# --- LLM du poste -----------------------------------------------------------
LOCAL_LLM_URL="${LOCAL_LLM_URL:-$(previous LOCAL_LLM_URL || true)}"
LOCAL_LLM_MODEL="${LOCAL_LLM_MODEL:-$(previous LLM_MODEL || true)}"
LOCAL_LLM_API_KEY="${LOCAL_LLM_API_KEY:-$(previous LOCAL_LLM_API_KEY || true)}"
[[ -n "${LOCAL_LLM_URL}" && -n "${LOCAL_LLM_MODEL}" ]] \
  || die "LOCAL_LLM_URL et LOCAL_LLM_MODEL sont requis, par exemple LOCAL_LLM_URL=http://127.0.0.1:11434 LOCAL_LLM_MODEL=qwen3:8b pour Ollama (voir le README)"
LOCAL_LLM_URL="${LOCAL_LLM_URL%/}"
LOCAL_LLM_URL="${LOCAL_LLM_URL%/v1}"

log "LLM du poste : ${LOCAL_LLM_MODEL} (${LOCAL_LLM_URL})"
auth=()
[[ -n "${LOCAL_LLM_API_KEY}" ]] && auth=(-H "Authorization: Bearer ${LOCAL_LLM_API_KEY}")
models="$(curl -sf --max-time 10 ${auth[@]+"${auth[@]}"} "${LOCAL_LLM_URL}/v1/models")" \
  || die "serveur LLM injoignable ou jeton refusé : ${LOCAL_LLM_URL}/v1/models (serveur démarré ? LOCAL_LLM_API_KEY ?)"
grep -qF "\"${LOCAL_LLM_MODEL}\"" <<<"${models}" \
  || warn "modèle ${LOCAL_LLM_MODEL} absent de ${LOCAL_LLM_URL}/v1/models : vérifiez son identifiant"
ok "Serveur LLM joignable"

# Depuis la VM Colima (et donc depuis les pods), le Mac s'appelle
# host.lima.internal : ses ports locaux (127.0.0.1) y sont joignables.
LLM_API_BASE="$(sed -E 's#^(https?://)(localhost|127\.0\.0\.1|\[::1\])#\1host.lima.internal#' <<<"${LOCAL_LLM_URL}")/v1"

# --- Cluster ----------------------------------------------------------------
log "Kubeconfig dédié : ${LOCAL_KUBECONFIG}"
mkdir -p "$(dirname "${LOCAL_KUBECONFIG}")"
(umask 077 && kubectl config view --raw --minify --flatten --context "${KUBE_CONTEXT}" > "${LOCAL_KUBECONFIG}")
export KUBECONFIG="${LOCAL_KUBECONFIG}"
check_cluster_prereqs
node_version="$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')"
[[ "${node_version}" == "${K3S_VERSION}" ]] || warn "k3s ${node_version} : l'atelier a été validé avec ${K3S_VERSION}"

# --- Registre local -----------------------------------------------------------
# Registre sans TLS dans le Docker de la VM. Le port 5001 évite le 5000 de macOS
# (récepteur AirPlay). Colima le redirige vers localhost:5001 sur le Mac : ko et
# docker y poussent les images, et le kubelet (Docker de la VM) les tire depuis
# localhost:5001. Docker et ko acceptent le HTTP pour localhost.
export DOCKER_CONTEXT="${KUBE_CONTEXT}"
if [[ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" != "true" ]]; then
  log "Registre local ${REGISTRY_NAME} (localhost:${REGISTRY_PORT})"
  docker rm -f "${REGISTRY_NAME}" >/dev/null 2>&1 || true
  docker run -d --restart=always --name "${REGISTRY_NAME}" -p "${REGISTRY_PORT}:5000" "${REGISTRY_IMAGE}" >/dev/null
fi
for _ in $(seq 30); do
  curl -sf "http://localhost:${REGISTRY_PORT}/v2/" >/dev/null && break
  sleep 1
done
curl -sf "http://localhost:${REGISTRY_PORT}/v2/" >/dev/null || die "registre injoignable sur localhost:${REGISTRY_PORT}"
ok "Registre prêt"

# atelet tire lui-même l'image des sandboxes depuis son pod, où localhost
# désigne le pod : il réécrit donc localhost:5001 vers l'adresse du nœud (option
# --localhost-registry-replacement, voir platform/substrate/local-registry).
# Le nœud k3s de Colima a une adresse IPv4 et une IPv6 : on garde l'IPv4.
NODE_IP="$(kubectl get nodes -o jsonpath='{range .items[0].status.addresses[?(@.type=="InternalIP")]}{.address}{"\n"}{end}' \
  | grep -m1 -E '^[0-9.]+$' || true)"
[[ -n "${NODE_IP}" ]] || die "adresse du nœud introuvable"

# --- workshop.env -------------------------------------------------------------
# Les identifiants rustfs sont conservés d'un lancement à l'autre.
S3_ACCESS_KEY_ID="$(previous S3_ACCESS_KEY_ID || true)"
S3_SECRET_ACCESS_KEY="$(previous S3_SECRET_ACCESS_KEY || true)"
S3_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID:-$(openssl rand -hex 12)}"
S3_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY:-$(openssl rand -hex 24)}"

log "Écriture de ${WORKSHOP_ENV}"
# Les valeurs variables sont échappées (printf %q) : le fichier est sourcé par
# les scripts et par le shell du participant, et un jeton peut contenir ", $ ou `.
q() { printf '%q' "$1"; }
(umask 077 && cat > "${WORKSHOP_ENV}") <<EOF
# Généré par local/up.sh — NE PAS COMMITER : contient des secrets (rustfs, jeton LLM).
# Même contrat que terraform/workshop.env.tftpl, plus les variables propres à la
# variante locale. Usage : source demos/ax/workshop.env

# --- Cluster ---------------------------------------------------------------
export AX_CLOUD="local"
export CLUSTER_NAME=$(q "${KUBE_CONTEXT}")
export KUBECONFIG=$(q "${LOCAL_KUBECONFIG}")
# Les builds docker doivent viser le Docker de ce profil (registre local).
export DOCKER_CONTEXT=$(q "${KUBE_CONTEXT}")

# --- Images ----------------------------------------------------------------
export IMAGE_REPO="localhost:${REGISTRY_PORT}"
export AGENT_IMAGE_REPO="localhost:${REGISTRY_PORT}/ax-agent-runner"
# Nœud arm64 (Mac Apple Silicon) : une seule architecture à construire.
export AGENT_IMAGE_PLATFORM="linux/arm64"
export KO_DEFAULTPLATFORMS="linux/arm64"
export ATELET_LOCALHOST_REGISTRY=$(q "${NODE_IP}:${REGISTRY_PORT}")

# --- Snapshots des sandboxes : rustfs dans le cluster -------------------------
export SNAPSHOT_BACKEND="s3"
export SNAPSHOT_LOCATION="gs://ax-snapshots/ax"
export S3_ENDPOINT="http://rustfs.ate-system.svc:9000"
export S3_REGION="us-east-1"
export S3_FORCE_PATH_STYLE="true"
export S3_ACCESS_KEY_ID=$(q "${S3_ACCESS_KEY_ID}")
export S3_SECRET_ACCESS_KEY=$(q "${S3_SECRET_ACCESS_KEY}")
export S3_IN_CLUSTER="true"

# --- LLM : serveur du poste, derrière la passerelle LiteLLM --------------------
export LOCAL_LLM_URL=$(q "${LOCAL_LLM_URL}")
export LOCAL_LLM_API_KEY=$(q "${LOCAL_LLM_API_KEY}")
export LLM_PROVIDER="local"
export LLM_MODEL=$(q "${LOCAL_LLM_MODEL}")
export LLM_API_BASE=$(q "${LLM_API_BASE}")
# LiteLLM exige une clé : valeur factice si le serveur n'en demande pas.
export LLM_API_KEY=$(q "${LOCAL_LLM_API_KEY:-sans-cle}")
export LLM_API_VERSION=""
export LLM_AWS_REGION=""
export LLM_VERTEX_PROJECT=""
export LLM_VERTEX_LOCATION=""
export LLM_SERVICE_ACCOUNT_ANNOTATION=""
EOF

ok "Cluster local prêt (nœud ${NODE_IP}, registre localhost:${REGISTRY_PORT}, LLM ${LLM_API_BASE})"
echo "Chargez l'environnement : source workshop.env"
