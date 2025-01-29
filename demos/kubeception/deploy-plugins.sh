#!/bin/bash

CONTROL_PLANE_IP=$1

if [[ -z $CONTROL_PLANE_IP ]]; then
  echo "Control plane ip not specified"
  echo "USAGE $0 [Control plane ip]"
  exit 1
fi

echo "==== Deploying Konnectivity Agent ===="
kubectl apply -f - <<EOF
apiVersion: apps/v1
# Alternatively, you can deploy the agents as Deployments. It is not necessary
# to have an agent on each node.
kind: DaemonSet
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    k8s-app: konnectivity-agent
  namespace: kube-system
  name: konnectivity-agent
spec:
  selector:
    matchLabels:
      k8s-app: konnectivity-agent
  template:
    metadata:
      labels:
        k8s-app: konnectivity-agent
    spec:
      hostNetwork: true
      priorityClassName: system-cluster-critical
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Exists"
      containers:
        - image: registry.k8s.io/kas-network-proxy/proxy-agent:v0.0.37
          name: konnectivity-agent
          command: ["/proxy-agent"]
          args: [
                  "--logtostderr=true",
                  "--ca-cert=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
                  "--proxy-server-host=$CONTROL_PLANE_IP",
                  "--proxy-server-port=8091",
                  "--agent-identifiers=host=\$(NODE_NAME)&ipv4=\$(HOST_IP)",
                  "--agent-id=\$(NODE_NAME)",
                  "--service-account-token-path=/var/run/secrets/tokens/konnectivity-agent-token"
                  ]
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: spec.nodeName
            - name: HOST_IP
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: status.hostIP
          volumeMounts:
            - mountPath: /var/run/secrets/tokens
              name: konnectivity-agent-token
          livenessProbe:
            httpGet:
              port: 8093
              path: /healthz
            initialDelaySeconds: 15
            timeoutSeconds: 15
      serviceAccountName: konnectivity-agent
      volumes:
        - name: konnectivity-agent-token
          projected:
            sources:
              - serviceAccountToken:
                  path: konnectivity-agent-token
                  audience: system:konnectivity-server
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:konnectivity-server
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: system:konnectivity-server
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: konnectivity-agent
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
EOF


echo "==== Deploy CNI ===="
helm install cilium \
  --repo https://helm.cilium.io/ \
  --chart cilium \
  --version 1.16.5 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="$CONTROL_PLANE_IP" \
  --set k8sServicePort=6443 \
  --set operator.replicas=1 \
  --set socketLB.hostNamespaceOnly=true \
  --set debug.verbose=""


echo "==== Deploy API-Server RBAC ===="
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kubelet-api-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: kube-apiserver
EOF

echo "==== Deploy CoreDNS ===="
helm install coredns \
  --repo https://coredns.github.io/helm \
  --chart coredns \
  --version 1.37.0 \
  --namespace kube-system \
  --set isClusterService=true

echo "==== Deploy metrics-server ===="
helm install metrics-server metrics-server \
  --repo https://kubernetes-sigs.github.io/metrics-server \
  --chart metrics-server \
  --version 3.12.2 \
  --namespace kube-system \
  --set "args[0]=--kubelet-insecure-tls" \
  --set "args[1]=--kubelet-preferred-address-types=InternalIP,InternalDNS,Hostname" \
  --set "args[2]=--kubelet-use-node-status-port" \
  --set "args[3]=--metric-resolution=15s"
