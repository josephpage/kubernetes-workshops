output "kubeconfig" {
  value       = module.cluster.kubeconfig_file
  description = "Chemin vers le fichier kubeconfig du cluster"
}

output "load_balancer_ip" {
  value       = module.cluster.load_balancer_ip
  description = "Adresse IP publique du Load Balancer du cluster"
}

output "functions_registry" {
  value       = scaleway_registry_namespace.functions.endpoint
  description = "Registre Scaleway individuel de cette session, à passer en variable REGISTRY au script de build/push des functions"
}

output "kubectl_context_commands" {
  value       = <<EOF
export KUBECONFIG=~/.kube/kubeconfig-crossplane-workshop

Testez la connexion :
kubectl get nodes
EOF
  description = "Commandes d'export de variables d'environnement pour votre terminal"
}
