"""Function namespace-secret : Secret dépendant d'une TicketRequest approuvée.

Équivalent Crossplane du pipeline Kratix namespace-secret (SDK Kratix +
client Kubernetes) avec deux simplifications structurantes :

- la lecture de la TicketRequest ne passe plus par un appel direct à l'API
  Kubernetes (qui exigeait un RBAC dédié pour le pod du pipeline) : la function
  DÉCLARE son besoin via les required resources du protocole RunFunction, et
  c'est Crossplane qui va chercher la ressource et rappelle la function avec ;
- le pattern `write_retry_after` (30/60/120 s) disparaît : la re-réconciliation
  périodique de la XR est le mécanisme de retry naturel.
"""

import grpc
from crossplane.function import logging, resource, response
from crossplane.function.proto.v1 import run_function_pb2 as fnv1
from crossplane.function.proto.v1 import run_function_pb2_grpc as grpcv1

TICKET_API_VERSION = "platform.octo.com/v1alpha1"
TICKET_KIND = "TicketRequest"


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

        ticket_request_name = spec.get("ticketRequestName", "")
        secret_name = spec.get("secretName", "app-secret")
        string_data = spec.get("stringData", {})

        if not ticket_request_name:
            response.fatal(rsp, "spec.ticketRequestName est requis")
            return rsp

        # Déclarer le besoin : Crossplane résout la TicketRequest et rappelle
        # la function DANS LA MÊME réconciliation avec la ressource en main.
        response.require_resources(
            rsp,
            "ticket",
            api_version=TICKET_API_VERSION,
            kind=TICKET_KIND,
            match_name=ticket_request_name,
        )

        tickets = req.required_resources["ticket"].items
        if len(tickets) == 0:
            # Soit premier appel (Crossplane va rappeler avec la ressource),
            # soit TicketRequest réellement absente : dans les deux cas le
            # status ci-dessous n'est conservé que si la dépendance manque.
            log.info("TicketRequest non disponible", ticket=ticket_request_name)
            resource.update_status(
                rsp.desired.composite,
                {
                    "status": "WaitingDependency",
                    "message": f"TicketRequest '{ticket_request_name}' introuvable — "
                    "créez-la, ou attendez la prochaine réconciliation.",
                },
            )
            return rsp

        ticket = resource.struct_to_dict(tickets[0].resource)
        ticket_status = (ticket.get("status") or {}).get("status", "")
        namespace_name = (ticket.get("status") or {}).get("namespaceName", "")

        if ticket_status == "Approved" and namespace_name:
            resource.update(
                rsp.desired.resources["secret"],
                {
                    "apiVersion": "v1",
                    "kind": "Secret",
                    "metadata": {
                        "name": secret_name,
                        "namespace": namespace_name,
                        "labels": {"octo.com/secret-request": name},
                    },
                    "type": "Opaque",
                    "stringData": string_data,
                },
            )
            # Un Secret n'expose pas de condition Ready : on la déclare pour
            # que function-auto-ready puisse conclure sur la XR.
            rsp.desired.resources["secret"].ready = fnv1.READY_TRUE
            resource.update_status(
                rsp.desired.composite,
                {
                    "status": "Ready",
                    "namespaceName": namespace_name,
                    "secretName": secret_name,
                    "message": f"Secret {secret_name} créé dans le namespace "
                    f"{namespace_name}.",
                },
            )
            return rsp

        if ticket_status == "Failed":
            resource.update_status(
                rsp.desired.composite,
                {
                    "status": "WaitingDependency",
                    "message": f"La TicketRequest '{ticket_request_name}' est en échec — "
                    "le Secret sera créé si elle redevient Approved.",
                },
            )
            return rsp

        resource.update_status(
            rsp.desired.composite,
            {
                "status": "Pending",
                "message": f"TicketRequest '{ticket_request_name}' en attente "
                "d'approbation — le Secret sera créé une fois le namespace provisionné.",
            },
        )
        return rsp
