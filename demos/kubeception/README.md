# Atelier Kubeception

> **Statut : brouillon.** Les notes ci-dessous décrivent le chemin nominal, le guide pédagogique complet reste à rédiger.

Déployer des clusters Kubernetes *dans* Kubernetes avec l'opérateur [kubeception-operator](https://elssuy.github.io/helm-charts) : un etcd et un control-plane tournent comme des pods du cluster hôte, les workers sont des machines provisionnées via [`terraform-nodes/`](terraform-nodes/).

```bash
# Install operator
helm repo add elssuy https://elssuy.github.io/helm-charts
helm repo update
helm install kcop elssuy/kubeception-operator --version 0.0.2-alpha

# Deploy etcd & control-plane
kubectl create ns demo
kubectl apply -f etcd.yml -n demo
kubectl apply -f control-plane.yml -n demo

# Enroll a worker node
CONTROL_PLANE_IP=
NODE1_IP=
ssh-keyscan $NODE1_IP >> ~/.ssh/known_hosts
scp ../kubeception-operator/hack/setup-worker.sh
```
