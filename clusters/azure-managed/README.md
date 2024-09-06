## Pre-requisites

- Install [OpenTofu]() on your machine
- Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

# Install Basic Cluster with Azure

1. Login to Azure CLI:

```bash
az login
```

2. Create the cluster :

```bash
env $(cat .env | sed 's/#.*//g'| xargs) tofu init
env $(cat .env | sed 's/#.*//g'| xargs) tofu apply
```

3. Export the kubeconfig file:

```bash
env $(cat .env | sed 's/#.*//g'| xargs) tofu kubeconfig
```

3. Once the cluster is created, you can install the basic cluster with the following command:

```bash
KUBECONFIG=/home/$USER/.kube/kubeconfig-sandbox-cluster kubectl get po --all-namespaces -o wide
```
