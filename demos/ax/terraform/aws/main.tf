# Infrastructure de l'atelier AX sur AWS :
# - un VPC et un cluster EKS 1.37 (2 nœuds x86_64, taille fixe) ;
# - ECR privé, avec création des dépôts à la volée (ko pousse une image par composant) ;
# - ECR Public pour l'image des sandboxes : atelet (Substrate v0.3.0) ne sait pas
#   s'authentifier auprès d'ECR privé ;
# - un bucket S3 pour les snapshots, accessible par atelet et ate-api-server via
#   EKS Pod Identity (aucune clé statique) ;
# - l'accès à Bedrock pour la passerelle LLM, via EKS Pod Identity également.
#
# Toutes les sorties utiles aux scripts sont écrites dans demos/ax/workshop.env.

resource "random_id" "suffix" {
  byte_length = 3
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  suffix = random_id.suffix.hex
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name            = var.cluster_name
  cidr            = var.vpc_cidr
  azs             = local.azs
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, 48 + i)]

  enable_nat_gateway = true
  single_nat_gateway = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.26"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      # Active l'application des NetworkPolicy (passerelle LLM).
      configuration_values = jsonencode({ enableNetworkPolicy = "true" })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      # PostgreSQL de Substrate a besoin d'une StorageClass par défaut.
      configuration_values = jsonencode({ defaultStorageClass = { enabled = true } })
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    ax-workers = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.instance_type]
      capacity_type  = "ON_DEMAND" # pas de Spot : un worker préempté fait perdre l'état des sandboxes

      min_size     = var.node_count
      max_size     = var.node_count
      desired_size = var.node_count

      use_custom_launch_template = false
      disk_size                  = 50
    }
  }
}

resource "local_sensitive_file" "kubeconfig" {
  filename        = pathexpand("~/.kube/kubeconfig-${var.cluster_name}")
  file_permission = "0600"
  content = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = var.cluster_name
    clusters = [{
      name = var.cluster_name
      cluster = {
        server                     = module.eks.cluster_endpoint
        certificate-authority-data = module.eks.cluster_certificate_authority_data
      }
    }]
    contexts = [{
      name    = var.cluster_name
      context = { cluster = var.cluster_name, user = var.cluster_name }
    }]
    users = [{
      name = var.cluster_name
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args       = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
        }
      }
    }]
  })
}

# --- Rôles EKS Pod Identity ---------------------------------------------------

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-${local.suffix}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
