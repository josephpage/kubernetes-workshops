"""Function ticket-gate : gating humain via le service de ticketing.

Équivalent Crossplane du pipeline `configure` de la Promise Kratix ticketing,
avec une différence structurante : le pipeline Kratix était un Job qui pouvait
se permettre de poller l'API de ticketing pendant 180 s ; une Composition
Function répond à un appel gRPC avec une deadline courte. Chaque réconciliation
de la XR (~60 s) fait donc UNE vérification rapide, et la boucle de
réconciliation de Crossplane joue le rôle du polling.
"""

import json
import urllib.error
import urllib.request

import grpc
from crossplane.function import logging, resource, response
from crossplane.function.proto.v1 import run_function_pb2 as fnv1
from crossplane.function.proto.v1 import run_function_pb2_grpc as grpcv1

DEFAULT_API_URL = "http://ticketing-service.ticketing-system.svc.cluster.local"
HTTP_TIMEOUT_SECONDS = 5


def http_json(method: str, url: str, payload: dict | None = None) -> dict:
    """Fait un appel HTTP court et décode la réponse JSON."""
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)  # noqa: S310
    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT_SECONDS) as res:  # noqa: S310
        return json.loads(res.read().decode("utf-8"))


class FunctionRunner(grpcv1.FunctionRunnerService):
    """A FunctionRunner handles gRPC RunFunctionRequests."""

    def __init__(self):
        """Create a new FunctionRunner."""
        self.log = logging.get_logger()

    async def RunFunction(
        self, req: fnv1.RunFunctionRequest, _: grpc.aio.ServicerContext
    ) -> fnv1.RunFunctionResponse:
        """Run the function."""
        log = self.log.bind(tag=req.meta.tag)
        rsp = response.to(req)

        observed = resource.struct_to_dict(req.observed.composite.resource)
        name = observed.get("metadata", {}).get("name", "inconnu")
        spec = observed.get("spec", {})
        status = observed.get("status", {})

        api_url = DEFAULT_API_URL
        if req.HasField("input") and "apiUrl" in req.input:
            api_url = req.input["apiUrl"]

        # L'état ne vit pas dans la function (elle est sans mémoire, appelée à
        # chaque réconciliation) : il vit dans le status observé de la XR.
        ticket_id = status.get("ticketId")

        if not ticket_id:
            # Première réconciliation : création du ticket. Le ticketId est
            # persisté dans le status de la XR, ce qui rend les réconciliations
            # suivantes idempotentes (pas de ticket dupliqué).
            payload = {
                "title": f"[{name}] {spec.get('title', 'Demande de namespace')}",
                "description": spec.get("description", ""),
                "requester": spec.get("requester", "inconnu"),
                "service": "crossplane-namespace-provisioning",
                "severity": spec.get("severity", "medium"),
            }
            try:
                created = http_json("POST", f"{api_url}/tickets", payload)
            except (urllib.error.URLError, OSError, ValueError) as e:
                # Rien à défaire : on laisse la prochaine réconciliation retenter.
                log.info("Création du ticket impossible", error=str(e))
                response.warning(rsp, f"Création du ticket impossible : {e}")
                return rsp

            ticket_id = created.get("ticket_id", "")
            resource.update_status(
                rsp.desired.composite,
                {
                    "ticketId": ticket_id,
                    "status": "Pending",
                    "message": "Ticket créé, en attente d'approbation dans l'outil de ticketing.",
                },
            )
            response.normal(rsp, f"Ticket {ticket_id} créé pour {name}")
            return rsp

        try:
            ticket = http_json("GET", f"{api_url}/tickets/{ticket_id}")
        except (urllib.error.URLError, OSError, ValueError) as e:
            # On ré-affirme le status observé pour ne pas perdre le ticketId,
            # et la prochaine réconciliation retentera.
            resource.update_status(rsp.desired.composite, status)
            response.warning(rsp, f"Interrogation du ticket {ticket_id} impossible : {e}")
            return rsp

        if ticket.get("status") != "Approved":
            resource.update_status(
                rsp.desired.composite,
                {
                    "ticketId": ticket_id,
                    "status": "Pending",
                    "message": f"Ticket {ticket_id} en attente d'approbation "
                    "(vérifié à chaque réconciliation).",
                },
            )
            return rsp

        # Ticket approuvé : l'opérateur a saisi les données de réalisation.
        output = ticket.get("output_data") or {}
        namespace_name = output.get("namespace_name") or f"ns-{name}"
        cpu_limit = output.get("cpu_limit") or "2"
        memory_limit = output.get("memory_limit") or "4Gi"

        # Crossplane v2 compose des ressources Kubernetes arbitraires : là où le
        # pipeline Kratix écrivait ces manifests dans /kratix/output/ (appliqués
        # ensuite par FluxCD sur le worker), on les déclare comme ressources
        # désirées et Crossplane les applique lui-même.
        resource.update(
            rsp.desired.resources["namespace"],
            {
                "apiVersion": "v1",
                "kind": "Namespace",
                "metadata": {
                    "name": namespace_name,
                    "labels": {
                        "octo.com/ticket-id": ticket_id,
                        "octo.com/request-name": name,
                    },
                },
            },
        )
        # Namespace et ResourceQuota n'exposent pas de condition Ready : on la
        # déclare explicitement pour que function-auto-ready puisse conclure.
        rsp.desired.resources["namespace"].ready = fnv1.READY_TRUE

        resource.update(
            rsp.desired.resources["quota"],
            {
                "apiVersion": "v1",
                "kind": "ResourceQuota",
                "metadata": {
                    "name": "platform-quota",
                    "namespace": namespace_name,
                },
                "spec": {
                    "hard": {
                        "limits.cpu": cpu_limit,
                        "limits.memory": memory_limit,
                    },
                },
            },
        )
        rsp.desired.resources["quota"].ready = fnv1.READY_TRUE

        resource.update_status(
            rsp.desired.composite,
            {
                "ticketId": ticket_id,
                "status": "Approved",
                "namespaceName": namespace_name,
                "cpuLimit": cpu_limit,
                "memoryLimit": memory_limit,
                "approvedBy": ticket.get("approved_by", ""),
                "resolvedAt": ticket.get("resolved_at", ""),
                "message": f"Namespace {namespace_name} provisionné suite à "
                f"l'approbation du ticket {ticket_id}.",
            },
        )
        return rsp
