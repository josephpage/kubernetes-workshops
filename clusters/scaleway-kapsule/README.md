# Install Basic Cluster with Scaleway

1. Configure your Scaleway credentials in the `.env` file, for example:

```bash
SCW_ACCESS_KEY=**
SCW_SECRET_KEY=**
SCW_DEFAULT_PROJECT_ID=**
SCW_DEFAULT_ORGANIZATION_ID=**
```

2. Create the cluster :

```bash
env $(cat .env | sed 's/#.*//g'| xargs) terraform init
env $(cat .env | sed 's/#.*//g'| xargs) terraform apply
```

3. Once the cluster is created, you can install the basic cluster with the following command:

```bash
KUBECONFIG=/home/$USER/.kube/kubeconfig-sandbox-cluster kubectl get po --all-namespaces -o wide
```
