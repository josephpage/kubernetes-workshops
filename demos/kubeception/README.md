This workshop requires :
 - One Kubernetes cluster with cert-manager installed
 - 1+ VM(s) with a public IP and SSH access
 - kubectl locally installed

```
export KUBECONFIG=$(terraform output -raw kubeconfig_file)

# Install operator
helm repo add elssuy https://elssuy.github.io/helm-charts
helm repo update

helm install kcop elssuy/kubeception-operator \
    --version 0.0.2-alpha \
    --namespace kubeception-operator \
    --create-namespace

# or, if cert-manager is already installed :
helm install kcop elssuy/kubeception-operator \
    --version 0.0.2-alpha \
    --set cert-manager.enabled=false \
    --namespace kubeception-operator \
    --create-namespace

# Deploy etcd & control-plane
kubectl create ns demo
kubectl apply -f etcd.yml -n demo
kubectl apply -f control-plane.yml -n demo

# Get the CA certificate of the "child" control-plane
export KUBECEPTION_CA=$(kubectl get secret/ca -n demo -o jsonpath='{.data.ca\.crt}')

# Get the IP of the "child" control-plane
export CONTROL_PLANE_IP=$(kubectl get svc/kube-apiserver -n demo  --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Get kubeconfig of the "child" control-plane
kubectl get secret/admin-kubeconfig -n demo -o jsonpath='{.data.kubeconfig\.yml}' | base64 -d > ~/.kube/kubeconfig-kubeception-demo
export KUBECONFIG=~/.kube/kubeconfig-kubeception-demo

# Get the bootstrap token
./deploy-token.sh
export BOOTSTRAP_TOKEN= ...

export NODE_IP=51.15.130.176
export NODE_IP=51.158.73.168
export NODE_IP=51.158.98.157

ssh-keyscan $NODE_IP >> ~/.ssh/known_hosts
scp ./setup-worker.sh ubuntu@$NODE_IP:/tmp/setup-worker.sh
ssh ubuntu@$NODE_IP "sudo bash /tmp/setup-worker.sh $CONTROL_PLANE_IP $BOOTSTRAP_TOKEN $KUBECEPTION_CA"

./deploy-plugins.sh $CONTROL_PLANE_IP
