```
# Install operator
helm repo add elssuy https://elssuy.github.io/helm-charts
helm repo update
helm install kcop elssuy/kubeception-operator --version 0.0.2-alpha

# Deploy etcd & control-plane
kubectl create ns demo
kubectl apply -f etcd.yml -n demo
kubectl apply -f control-plane.yml -n demo

# 

CONTROL_PLANE_IP=
NODE1_IP=
ssh-keyscan $NODE1_IP >> ~/.ssh/known_hosts
scp ../kubeception-operator/hack/setup-worker.sh
