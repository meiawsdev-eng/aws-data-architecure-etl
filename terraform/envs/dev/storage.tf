# Step 6: encryption key + data lake buckets.

# Customer-managed key: we control who can decrypt the data lake, and every use is logged in CloudTrail.
# Cost: ~$1/month per key (+ tiny per-request fees, mostly avoided by S3 bucket keys).
resource "aws_kms_key" "datalake" {
  description             = "Encrypts the ${local.env} data lake buckets"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "datalake" {
  name          = "alias/${local.company_slug}-datalake-${local.env}"
  target_key_id = aws_kms_key.datalake.key_id
}

# Bronze: exact copy of source data. Versioned so an accidental overwrite/delete can be recovered.
module "raw" {
  source                = "../../modules/datalake_bucket"
  bucket_name           = "${local.company_slug}-datalake-raw-${local.env}"
  kms_key_arn           = aws_kms_key.datalake.arn
  versioning            = true
  transition_to_ia_days = 90
}

# Silver: cleaned, typed, deduplicated tables (Iceberg).
module "clean" {
  source      = "../../modules/datalake_bucket"
  bucket_name = "${local.company_slug}-datalake-clean-${local.env}"
  kms_key_arn = aws_kms_key.datalake.arn
}

# Gold: business-ready marts.
module "curated" {
  source      = "../../modules/datalake_bucket"
  bucket_name = "${local.company_slug}-datalake-curated-${local.env}"
  kms_key_arn = aws_kms_key.datalake.arn
}

# Glue job scripts (scripts/) and Spark temp files (tmp/, auto-deleted after 7 days).
module "artifacts" {
  source        = "../../modules/datalake_bucket"
  bucket_name   = "${local.company_slug}-datalake-artifacts-${local.env}"
  kms_key_arn   = aws_kms_key.datalake.arn
  expire_days   = 7
  expire_prefix = "tmp/"
}

# Athena query results are throwaway copies; keep them 30 days.
module "athena_results" {
  source      = "../../modules/datalake_bucket"
  bucket_name = "${local.company_slug}-athena-results-${local.env}"
  kms_key_arn = aws_kms_key.datalake.arn
  expire_days = 30
}
