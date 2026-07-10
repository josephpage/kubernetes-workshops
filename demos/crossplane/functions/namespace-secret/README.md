# function-namespace-secret

Composition Function de l'exercice 3 de l'[atelier Crossplane](../../README.md).

À chaque réconciliation d'une `NamespaceSecretRequest`, la function déclare son
besoin de lire la `TicketRequest` référencée (required resources du protocole
RunFunction — c'est Crossplane qui résout la ressource, pas de client Kubernetes
dans le code), puis :

- TicketRequest absente → status `WaitingDependency` ;
- TicketRequest `Pending` → status `Pending` ;
- TicketRequest `Approved` → compose le `Secret` dans le namespace provisionné,
  status `Ready`.

## Développement

```bash
# Tests unitaires
uv venv .venv && uv pip install -p .venv/bin/python -e . pytest
.venv/bin/python -m pytest tests/

# Rendu local (voir ../../scripts/build-and-push-functions.sh pour le build)
docker build -t function-namespace-secret:dev .
```
