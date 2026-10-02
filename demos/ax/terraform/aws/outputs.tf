output "kubeconfig_file" {
  value       = local_sensitive_file.kubeconfig.filename
  description = "Kubeconfig du cluster (authentification par aws eks get-token)."
}

output "workshop_env_file" {
  value       = abspath(local_sensitive_file.workshop_env.filename)
  description = "Fichier à sourcer avant de lancer les scripts de l'atelier."
}

output "registry_login" {
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com && aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws"
  description = "Commande d'authentification Docker/ko aux registres ECR et ECR Public."
}

output "snapshots_bucket" {
  value       = aws_s3_bucket.snapshots.bucket
  description = "Bucket S3 des snapshots des sandboxes."
}
