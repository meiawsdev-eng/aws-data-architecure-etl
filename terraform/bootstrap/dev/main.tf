# Bootstrap: creates the Terraform state bucket for the DEV account.
# Run once. It starts with local state; afterwards we migrate this state into the bucket it created.

terraform {
  required_version = ">= 1.10" # S3-native state locking needs 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Added after the first apply: the bootstrap's own state now lives in the bucket it created.
  backend "s3" {
    bucket       = "mei-aws-slug-tfstate-dev-237162087184"
    key          = "bootstrap/dev/terraform.tfstate"
    region       = "us-east-1"
    profile      = "data-dev"
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  company_slug = "mei-aws-slug"
  env          = "dev"
}

provider "aws" {
  profile = "data-dev"
  region  = "us-east-1"

  # Safety net: Terraform refuses to run if the profile points at any other account.
  allowed_account_ids = ["237162087184"]

  default_tags {
    tags = {
      company    = local.company_slug
      env        = local.env
      managed_by = "terraform"
      stack      = "bootstrap"
    }
  }
}

module "tfstate" {
  source       = "../../modules/tfstate_bucket"
  company_slug = local.company_slug
  env          = local.env
}

output "state_bucket" {
  value = module.tfstate.bucket_name
}
