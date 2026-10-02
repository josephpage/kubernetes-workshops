#!/usr/bin/env bash
# Étape 6 de l'atelier : déploie la passerelle LLM (LiteLLM) configurée pour le
# fournisseur du cloud hôte (${LLM_PROVIDER}), voir platform/llm-gateway.
source "$(dirname "$0")/lib.sh"

require_cmd kubectl perl
load_workshop_env
export LITELLM_IMAGE

config="${AX_DEMO_DIR}/platform/llm-gateway/config/${LLM_PROVIDER}.yaml"
[[ -f "${config}" ]] || die "fournisseur LLM inconnu : ${LLM_PROVIDER} (attendu : scaleway, aws, gcp ou azure)"

log "Passerelle LLM : ${LLM_PROVIDER} / ${LLM_MODEL}"
render "${AX_DEMO_DIR}/platform/llm-gateway/litellm.yaml" | kubectl apply -f -

# Identité de workload éventuelle (ex. clé=valeur fournie par terraform/<cloud>).
if [[ -n "${LLM_SERVICE_ACCOUNT_ANNOTATION}" ]]; then
  kubectl -n llm-gateway annotate serviceaccount litellm --overwrite "${LLM_SERVICE_ACCOUNT_ANNOTATION}"
fi

# Seules les valeurs non vides vont dans le Secret (sur AWS et GCP, aucune clé :
# l'identité de workload suffit).
args=()
[[ -n "${LLM_API_BASE}" ]] && args+=(--from-literal=LLM_API_BASE="${LLM_API_BASE}")
[[ -n "${LLM_API_KEY}" ]] && args+=(--from-literal=LLM_API_KEY="${LLM_API_KEY}")
kubectl -n llm-gateway create secret generic llm-gateway-credentials "${args[@]}" --dry-run=client -o yaml | kubectl apply -f -

render "${config}" > "${WORK_DIR}/litellm-config.yaml"
kubectl -n llm-gateway create configmap litellm-config --from-file=config.yaml="${WORK_DIR}/litellm-config.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -

# Prise en compte d'une configuration modifiée lors d'un second passage.
kubectl -n llm-gateway rollout restart deployment/litellm
kubectl -n llm-gateway rollout status deployment/litellm --timeout=5m

ok "Passerelle LLM prête : http://litellm.llm-gateway.svc.cluster.local:4000/v1 (modèle « workshop-model »)"
