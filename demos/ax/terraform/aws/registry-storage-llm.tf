# --- Registres ----------------------------------------------------------------

# ko pousse chaque composant dans son propre dépôt (<préfixe>/atelet, .../ateapi...) :
# ECR les crée au premier push grâce à ce modèle (CREATE_ON_PUSH).
resource "aws_ecr_repository_creation_template" "workshop" {
  prefix               = var.cluster_name
  description          = "Dépôts créés à la volée par ko pour l'atelier AX"
  applied_for          = ["CREATE_ON_PUSH"]
  image_tag_mutability = "MUTABLE"

  lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Garde les 10 dernières images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# Image des sandboxes : tirée par atelet sans identifiants.
resource "aws_ecrpublic_repository" "agent_runner" {
  provider        = aws.us_east_1
  repository_name = "${var.cluster_name}-${local.suffix}/ax-agent-runner"
  force_destroy   = true

  catalog_data {
    description = "Image des sandboxes de l'atelier AX (runner AX + OpenCode)"
  }
}

# --- Snapshots des sandboxes ---------------------------------------------------

resource "aws_s3_bucket" "snapshots" {
  bucket        = "${var.cluster_name}-snapshots-${local.suffix}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "snapshots" {
  bucket                  = aws_s3_bucket.snapshots.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "snapshots" {
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.snapshots.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
    resources = ["${aws_s3_bucket.snapshots.arn}/*"]
  }
}

resource "aws_iam_role" "substrate_snapshots" {
  name               = "${var.cluster_name}-${local.suffix}-snapshots"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy" "substrate_snapshots" {
  name   = "snapshots"
  role   = aws_iam_role.substrate_snapshots.id
  policy = data.aws_iam_policy_document.snapshots.json
}

# Les ServiceAccounts sont créés plus tard par l'installeur de Substrate : une
# association Pod Identity peut exister avant eux.
resource "aws_eks_pod_identity_association" "substrate" {
  for_each = toset(["atelet", "ate-api-server"])

  cluster_name    = module.eks.cluster_name
  namespace       = "ate-system"
  service_account = each.key
  role_arn        = aws_iam_role.substrate_snapshots.arn
}

# --- Passerelle LLM : Amazon Bedrock ----------------------------------------------

data "aws_iam_policy_document" "bedrock" {
  statement {
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "llm_gateway" {
  name               = "${var.cluster_name}-${local.suffix}-llm-gateway"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy" "llm_gateway" {
  name   = "bedrock"
  role   = aws_iam_role.llm_gateway.id
  policy = data.aws_iam_policy_document.bedrock.json
}

resource "aws_eks_pod_identity_association" "llm_gateway" {
  cluster_name    = module.eks.cluster_name
  namespace       = "llm-gateway"
  service_account = "litellm"
  role_arn        = aws_iam_role.llm_gateway.arn
}

# --- Contrat commun avec les scripts ------------------------------------------------

resource "local_sensitive_file" "workshop_env" {
  filename        = "${path.module}/../../workshop.env"
  file_permission = "0600"
  content = templatefile("${path.module}/../workshop.env.tftpl", {
    cloud        = "aws"
    cluster_name = var.cluster_name
    kubeconfig   = local_sensitive_file.kubeconfig.filename

    image_repo       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.cluster_name}"
    agent_image_repo = aws_ecrpublic_repository.agent_runner.repository_uri

    snapshot_backend     = "s3"
    snapshot_location    = "gs://${aws_s3_bucket.snapshots.bucket}/ax"
    s3_endpoint          = ""
    s3_region            = var.region
    s3_force_path_style  = "false"
    s3_access_key_id     = "" # EKS Pod Identity
    s3_secret_access_key = ""
    s3_in_cluster        = "false"

    llm_provider                   = "aws"
    llm_model                      = var.llm_model
    llm_api_base                   = ""
    llm_api_key                    = "" # EKS Pod Identity
    llm_api_version                = ""
    llm_aws_region                 = var.bedrock_region
    llm_vertex_project             = ""
    llm_vertex_location            = ""
    llm_service_account_annotation = ""
  })
}
