# Step 7: Glue Data Catalog databases + Athena workgroup.

# One catalog database per medallion layer. Tables inside point at the matching bucket.
resource "aws_glue_catalog_database" "bronze" {
  name         = "bronze"
  description  = "Raw data as ingested (s3://${module.raw.bucket_name})"
  location_uri = "s3://${module.raw.bucket_name}/"
}

resource "aws_glue_catalog_database" "silver" {
  name         = "silver"
  description  = "Cleaned, typed, deduplicated Iceberg tables (s3://${module.clean.bucket_name})"
  location_uri = "s3://${module.clean.bucket_name}/"
}

resource "aws_glue_catalog_database" "gold" {
  name         = "gold"
  description  = "Business-ready marts (s3://${module.curated.bucket_name})"
  location_uri = "s3://${module.curated.bucket_name}/"
}

# Athena bills $5 per TB scanned. The workgroup enforces encrypted results in our bucket
# and cancels any single query that would scan more than 10 GB (~$0.05) — a guard against
# accidental full-table scans while learning.
resource "aws_athena_workgroup" "data_platform" {
  name          = "data-platform"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 10 * 1024 * 1024 * 1024

    engine_version {
      selected_engine_version = "AUTO"
    }

    result_configuration {
      output_location = "s3://${module.athena_results.bucket_name}/results/"
      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.datalake.arn
      }
    }
  }
}
