import unittest
from unittest import mock

from crossplane.function import logging, resource
from crossplane.function.proto.v1 import run_function_pb2 as fnv1

from function import fn


def make_request(spec: dict, status: dict | None = None) -> fnv1.RunFunctionRequest:
    composite = {
        "apiVersion": "platform.octo.com/v1alpha1",
        "kind": "TicketRequest",
        "metadata": {"name": "request-new-env"},
        "spec": spec,
    }
    if status is not None:
        composite["status"] = status
    return fnv1.RunFunctionRequest(
        observed=fnv1.State(
            composite=fnv1.Resource(resource=resource.dict_to_struct(composite))
        ),
    )


SPEC = {
    "title": "Demande de Namespace de Recette",
    "description": "Namespace pour l'équipe QA",
    "requester": "equipe-qa",
    "severity": "high",
}


class TestFunctionRunner(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.maxDiff = None
        logging.configure(level=logging.Level.DISABLED)
        self.runner = fn.FunctionRunner()

    async def test_creates_ticket_on_first_reconcile(self) -> None:
        with mock.patch.object(
            fn, "http_json", return_value={"ticket_id": "TICKET-1"}
        ) as http:
            rsp = await self.runner.RunFunction(make_request(SPEC), None)

        http.assert_called_once()
        method, url = http.call_args.args[:2]
        self.assertEqual(method, "POST")
        self.assertTrue(url.endswith("/tickets"))
        payload = http.call_args.args[2]
        self.assertEqual(payload["title"], "[request-new-env] Demande de Namespace de Recette")
        self.assertEqual(payload["severity"], "high")

        status = resource.struct_to_dict(rsp.desired.composite.resource)["status"]
        self.assertEqual(status["ticketId"], "TICKET-1")
        self.assertEqual(status["status"], "Pending")
        # Pas de ressources composées tant que le ticket n'est pas approuvé.
        self.assertEqual(len(rsp.desired.resources), 0)

    async def test_does_not_recreate_ticket_while_pending(self) -> None:
        with mock.patch.object(
            fn, "http_json", return_value={"id": "TICKET-1", "status": "Pending"}
        ) as http:
            rsp = await self.runner.RunFunction(
                make_request(SPEC, status={"ticketId": "TICKET-1", "status": "Pending"}),
                None,
            )

        method, url = http.call_args.args[:2]
        self.assertEqual(method, "GET")
        self.assertTrue(url.endswith("/tickets/TICKET-1"))

        status = resource.struct_to_dict(rsp.desired.composite.resource)["status"]
        self.assertEqual(status["ticketId"], "TICKET-1")
        self.assertEqual(status["status"], "Pending")
        self.assertEqual(len(rsp.desired.resources), 0)

    async def test_composes_namespace_and_quota_once_approved(self) -> None:
        ticket = {
            "id": "TICKET-1",
            "status": "Approved",
            "approved_by": "admin@octo.com",
            "resolved_at": "2026-01-01 10:00:00",
            "output_data": {
                "namespace_name": "dev-workspace-1",
                "cpu_limit": "4",
                "memory_limit": "8Gi",
            },
        }
        with mock.patch.object(fn, "http_json", return_value=ticket):
            rsp = await self.runner.RunFunction(
                make_request(SPEC, status={"ticketId": "TICKET-1", "status": "Pending"}),
                None,
            )

        namespace = resource.struct_to_dict(rsp.desired.resources["namespace"].resource)
        self.assertEqual(namespace["kind"], "Namespace")
        self.assertEqual(namespace["metadata"]["name"], "dev-workspace-1")
        self.assertEqual(namespace["metadata"]["labels"]["octo.com/ticket-id"], "TICKET-1")
        self.assertEqual(rsp.desired.resources["namespace"].ready, fnv1.READY_TRUE)

        quota = resource.struct_to_dict(rsp.desired.resources["quota"].resource)
        self.assertEqual(quota["kind"], "ResourceQuota")
        self.assertEqual(quota["metadata"]["namespace"], "dev-workspace-1")
        self.assertEqual(quota["spec"]["hard"]["limits.cpu"], "4")
        self.assertEqual(quota["spec"]["hard"]["limits.memory"], "8Gi")

        status = resource.struct_to_dict(rsp.desired.composite.resource)["status"]
        self.assertEqual(status["status"], "Approved")
        self.assertEqual(status["namespaceName"], "dev-workspace-1")
        self.assertEqual(status["approvedBy"], "admin@octo.com")

    async def test_keeps_status_on_http_error(self) -> None:
        with mock.patch.object(fn, "http_json", side_effect=OSError("connexion refusée")):
            rsp = await self.runner.RunFunction(
                make_request(SPEC, status={"ticketId": "TICKET-1", "status": "Pending"}),
                None,
            )

        # Le ticketId observé est ré-affirmé : pas de ticket dupliqué au retry.
        status = resource.struct_to_dict(rsp.desired.composite.resource)["status"]
        self.assertEqual(status["ticketId"], "TICKET-1")
        warnings = [r for r in rsp.results if r.severity == fnv1.SEVERITY_WARNING]
        self.assertEqual(len(warnings), 1)

    async def test_warns_without_state_when_creation_fails(self) -> None:
        with mock.patch.object(fn, "http_json", side_effect=OSError("connexion refusée")):
            rsp = await self.runner.RunFunction(make_request(SPEC), None)

        warnings = [r for r in rsp.results if r.severity == fnv1.SEVERITY_WARNING]
        self.assertEqual(len(warnings), 1)
        self.assertEqual(len(rsp.desired.resources), 0)


if __name__ == "__main__":
    unittest.main()
