import unittest

from crossplane.function import logging, resource
from crossplane.function.proto.v1 import run_function_pb2 as fnv1

from function import fn


def make_request(
    spec: dict, ticket: dict | None = None, declare_requirement: bool = True
) -> fnv1.RunFunctionRequest:
    composite = {
        "apiVersion": "platform.octo.com/v1alpha1",
        "kind": "NamespaceSecretRequest",
        "metadata": {"name": "secret-for-qa-env"},
        "spec": spec,
    }
    req = fnv1.RunFunctionRequest(
        observed=fnv1.State(
            composite=fnv1.Resource(resource=resource.dict_to_struct(composite))
        ),
    )
    if declare_requirement:
        items = []
        if ticket is not None:
            items.append(fnv1.Resource(resource=resource.dict_to_struct(ticket)))
        req.required_resources["ticket"].CopyFrom(fnv1.Resources(items=items))
    return req


SPEC = {
    "ticketRequestName": "request-new-env",
    "secretName": "app-config",
    "stringData": {"API_KEY": "REPLACE_ME", "LOG_LEVEL": "debug"},
}


def ticket_with_status(status: dict) -> dict:
    return {
        "apiVersion": "platform.octo.com/v1alpha1",
        "kind": "TicketRequest",
        "metadata": {"name": "request-new-env"},
        "status": status,
    }


class TestFunctionRunner(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.maxDiff = None
        logging.configure(level=logging.Level.DISABLED)
        self.runner = fn.FunctionRunner()

    async def test_always_declares_ticket_requirement(self) -> None:
        rsp = await self.runner.RunFunction(
            make_request(SPEC, declare_requirement=False), None
        )

        selector = rsp.requirements.resources["ticket"]
        self.assertEqual(selector.api_version, "platform.octo.com/v1alpha1")
        self.assertEqual(selector.kind, "TicketRequest")
        self.assertEqual(selector.match_name, "request-new-env")

    async def test_waits_when_ticket_request_missing(self) -> None:
        rsp = await self.runner.RunFunction(
            make_request(SPEC, declare_requirement=False), None
        )

        status = resource.struct_to_dict(rsp.desired.composite.resource)["status"]
        self.assertEqual(status["status"], "WaitingDependency")
        self.assertEqual(len(rsp.desired.resources), 0)

    async def test_waits_while_ticket_pending(self) -> None:
        rsp = await self.runner.RunFunction(
            make_request(SPEC, ticket=ticket_with_status({"status": "Pending"})),
            None,
        )

        status = resource.struct_to_dict(rsp.desired.composite.resource)["status"]
        self.assertEqual(status["status"], "Pending")
        self.assertEqual(len(rsp.desired.resources), 0)

    async def test_composes_secret_once_ticket_approved(self) -> None:
        rsp = await self.runner.RunFunction(
            make_request(
                SPEC,
                ticket=ticket_with_status(
                    {"status": "Approved", "namespaceName": "dev-workspace-1"}
                ),
            ),
            None,
        )

        secret = resource.struct_to_dict(rsp.desired.resources["secret"].resource)
        self.assertEqual(secret["kind"], "Secret")
        self.assertEqual(secret["metadata"]["name"], "app-config")
        self.assertEqual(secret["metadata"]["namespace"], "dev-workspace-1")
        self.assertEqual(secret["stringData"]["LOG_LEVEL"], "debug")
        self.assertEqual(rsp.desired.resources["secret"].ready, fnv1.READY_TRUE)

        status = resource.struct_to_dict(rsp.desired.composite.resource)["status"]
        self.assertEqual(status["status"], "Ready")
        self.assertEqual(status["namespaceName"], "dev-workspace-1")

    async def test_waits_dependency_when_ticket_failed(self) -> None:
        rsp = await self.runner.RunFunction(
            make_request(SPEC, ticket=ticket_with_status({"status": "Failed"})),
            None,
        )

        status = resource.struct_to_dict(rsp.desired.composite.resource)["status"]
        self.assertEqual(status["status"], "WaitingDependency")
        self.assertEqual(len(rsp.desired.resources), 0)

    async def test_fatal_without_ticket_request_name(self) -> None:
        rsp = await self.runner.RunFunction(
            make_request({"secretName": "app-config"}, declare_requirement=False),
            None,
        )

        fatals = [r for r in rsp.results if r.severity == fnv1.SEVERITY_FATAL]
        self.assertEqual(len(fatals), 1)


if __name__ == "__main__":
    unittest.main()
