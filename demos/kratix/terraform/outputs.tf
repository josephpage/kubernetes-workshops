output "platform_kubeconfig" {
  value       = module.platform_cluster.kubeconfig_file
  description = "Chemin vers le fichier kubeconfig du cluster Platform"
}

output "worker_kubeconfig" {
  value       = module.worker_cluster.kubeconfig_file
  description = "Chemin vers le fichier kubeconfig du cluster Worker"
}

output "platform_loadbalancer_ip" {
  value       = module.platform_cluster.load_balancer_ip
  description = "Adresse IP publique du Load Balancer pour le cluster Platform (utilisée pour joindre l'UI de Ticketing)"
}

output "worker_loadbalancer_ip" {
  value       = module.worker_cluster.load_balancer_ip
  description = "Adresse IP publique du Load Balancer pour le cluster Worker"
}

output "kratix_state_store_bucket_name" {
  value       = scaleway_object_bucket.kratix_state_store.name
  description = "Nom unique du bucket S3 Scaleway créé pour le StateStore Kratix"
}

output "kratix_state_store_bucket_region" {
  value       = scaleway_object_bucket.kratix_state_store.region
  description = "Région du bucket S3 Scaleway"
}

output "kubectl_contexts_commands" {
  value       = <<EOF
export KUBECONFIG_PLATFORM=~/.kube/kubeconfig-kratix-platform
export KUBECONFIG_WORKER=~/.kube/kubeconfig-kratix-worker

Testez la connexion :
kubectl --kubeconfig=$KUBECONFIG_PLATFORM get nodes
kubectl --kubeconfig=$KUBECONFIG_WORKER get nodes
EOF
  description = "Commandes d'export de variables d'environnement pour vos terminaux"
}
