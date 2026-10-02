terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 6.28 : CREATE_ON_PUSH dans aws_ecr_repository_creation_template.
      version = "~> 6.67"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
  }
}

# Credentials : chaîne standard du SDK AWS (AWS_PROFILE, aws sso login, variables
# AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY...).
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "kubernetes-workshops"
      usage   = "ax-workshop"
    }
  }
}

# ECR Public n'existe qu'en us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      project = "kubernetes-workshops"
      usage   = "ax-workshop"
    }
  }
}
