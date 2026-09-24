terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State lives in the bucket created by terraform/bootstrap/dev.
  backend "s3" {
    bucket       = "mei-aws-slug-tfstate-dev-237162087184"
    key          = "envs/dev/terraform.tfstate"
    region       = "us-east-1"
    profile      = "data-dev"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  profile             = "data-dev"
  region              = "us-east-1"
  allowed_account_ids = ["237162087184"]

  default_tags {
    tags = {
      company    = local.company_slug
      env        = local.env
      managed_by = "terraform"
      team       = "data-platform"
    }
  }
}

locals {
  company_slug = "mei-aws-slug"
  env          = "dev"
  prefix       = "${local.company_slug}-${local.env}"
}

data "aws_caller_identity" "current" {}
