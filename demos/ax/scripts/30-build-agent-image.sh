#!/usr/bin/env bash
# Étape 5 de l'atelier : construit et pousse l'image des sandboxes
# (runner AX + OpenCode), voir images/agent-runner/Dockerfile.
#
# PUSH=false construit sans pousser (validation locale, sans cluster).
source "$(dirname "$0")/lib.sh"

require_cmd docker git
PUSH="${PUSH:-true}"

if [[ "${PUSH}" == "true" ]]; then
  load_workshop_env
else
  # shellcheck source=/dev/null
  [[ -f "${WORKSHOP_ENV}" ]] && source "${WORKSHOP_ENV}"
  AGENT_IMAGE_REPO="${AGENT_IMAGE_REPO:-localhost/ax-agent-runner}"
fi
# Nœuds amd64 sur les clouds ; linux/arm64 dans la variante locale (Mac).
PLATFORM="${PLATFORM:-${AGENT_IMAGE_PLATFORM:-linux/amd64}}"

clone_at google/ax "${AX_VERSION}" "${WORK_DIR}/ax"

AGENT_IMAGE="${AGENT_IMAGE_REPO}:${AGENT_IMAGE_TAG}"
log "Build de ${AGENT_IMAGE} (${PLATFORM})"
output=(--load)
[[ "${PUSH}" == "true" ]] && output=(--push)
docker buildx build \
  --platform "${PLATFORM}" \
  --build-context ax="${WORK_DIR}/ax" \
  --build-arg OPENCODE_VERSION="${OPENCODE_VERSION}" \
  --build-arg RIPGREP_VERSION="${RIPGREP_VERSION}" \
  --tag "${AGENT_IMAGE}" \
  "${output[@]}" \
  "${AX_DEMO_DIR}/images/agent-runner"

if [[ "${PUSH}" == "true" ]]; then
  ok "Image poussée : $(resolve_agent_image)"
else
  ok "Image construite : ${AGENT_IMAGE}"
fi
