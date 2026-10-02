#!/usr/bin/env bash
# Affiche un manifest de l'atelier avec ses variables ${...} remplacées, prêt à
# être passé à `ax apply -f -`. Exemple :
#   ./scripts/render.sh tasks/01-hello.yaml | ax apply -f -
source "$(dirname "$0")/lib.sh"

[[ $# -ge 1 ]] || die "usage : $0 <manifest.yaml>..."
load_workshop_env >/dev/null
AGENT_IMAGE="${AGENT_IMAGE:-$(resolve_agent_image)}"
export AGENT_IMAGE
export ATESPACE="${ATESPACE:-default}"
# Branche du dépôt cloné par le Workspace de l'exercice 6 (main une fois l'atelier fusionné).
export KATA_BRANCH="${KATA_BRANCH:-main}"
render "$@"
