# function-ticket-gate

Composition Function de l'exercice 2 de l'[atelier Crossplane](../../README.md).

À chaque réconciliation d'une `TicketRequest` :

1. pas de `status.ticketId` → crée le ticket auprès du service de ticketing
   (`POST /tickets`) et persiste l'identifiant dans le status de la XR ;
2. ticket `Pending` → met simplement le status à jour (la prochaine
   réconciliation revérifiera : pas de polling bloquant) ;
3. ticket `Approved` → compose un `Namespace` et un `ResourceQuota` à partir des
   données saisies par l'opérateur dans l'outil de ticketing.

## Développement

```bash
# Tests unitaires
uv venv .venv && uv pip install -p .venv/bin/python -e . pytest
.venv/bin/python -m pytest tests/

# Rendu local (voir ../../scripts/build-and-push-functions.sh pour le build)
docker build -t function-ticket-gate:dev .
```
