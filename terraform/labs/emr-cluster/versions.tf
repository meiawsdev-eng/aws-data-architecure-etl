# E2 lab: short-lived EMR cluster. Separate state from envs/dev, so `terraform destroy` here
# can only ever remove the lab — never the data lake.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "mei-aws-slug-tfstate-dev-237162087184"
    key          = "labs/emr-cluster/terraform.tfstate" # its own state file
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
      company    = "mei-aws-slug"
      env        = "dev"
      managed_by = "terraform"
      team       = "data-platform"
      stack      = "emr-lab"
    }
  }
}

locals {
  prefix = "mei-aws-slug-dev-emr-lab"
}

data "aws_caller_identity" "current" {}

# Read-only view of the foundation stack's outputs (VPC, subnets, buckets, KMS alias).
data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket  = "mei-aws-slug-tfstate-dev-237162087184"
    key     = "envs/dev/terraform.tfstate"
    region  = "us-east-1"
    profile = "data-dev"
  }
}

data "aws_kms_alias" "datalake" {
  name = data.terraform_remote_state.dev.outputs.kms_key_alias
}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  vpc_id      = data.terraform_remote_state.dev.outputs.vpc_id
  subnet_id   = data.terraform_remote_state.dev.outputs.public_subnet_ids[0]
  buckets     = data.terraform_remote_state.dev.outputs.buckets
  kms_key_arn = data.aws_kms_alias.datalake.target_key_arn
  emr_tag     = { "for-use-with-amazon-emr-managed-policies" = "true" }
}
