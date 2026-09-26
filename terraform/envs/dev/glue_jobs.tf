# Step 8: Glue ETL jobs.

resource "aws_glue_job" "orders_bronze_to_silver" {
  name         = "${local.prefix}-orders-bronze-to-silver"
  role_arn     = aws_iam_role.glue_etl.arn
  glue_version = "5.0"

  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30
  max_retries       = 0

  command {
    name            = "glueetl"
    script_location = "s3://${module.artifacts.bucket_name}/scripts/orders_bronze_to_silver.py"
    python_version  = "3"
  }

  default_arguments = {
    "--datalake-formats"                 = "iceberg"
    "--raw_bucket"                       = module.raw.bucket_name
    "--clean_bucket"                     = module.clean.bucket_name
    "--ingest_date"                      = "2026-09-26"
    "--TempDir"                          = "s3://${module.artifacts.bucket_name}/tmp/"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
  }
}
