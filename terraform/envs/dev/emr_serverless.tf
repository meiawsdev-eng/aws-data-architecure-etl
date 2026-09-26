# EMR module E1: EMR Serverless application + the IAM role its Spark jobs run as.

locals {
  emr_release_label = "emr-7.14.0" # newest EMR 7 release (see: aws emr list-release-labels)
}

# A Spark "application" that starts on job submission and stops when idle.
resource "aws_emrserverless_application" "spark" {
  name          = "${local.prefix}-spark"
  release_label = local.emr_release_label
  type          = "spark"

  # Cost guard: all running jobs together can never exceed this.
  maximum_capacity {
    cpu    = "8 vCPU"
    memory = "32 GB"
  }

  auto_start_configuration {
    enabled = true
  }

  # Release all capacity after 15 idle minutes: $0 when nothing runs.
  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = 15
  }
}

resource "aws_iam_role" "emr_serverless_job" {
  name = "${local.prefix}-emr-serverless-job"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "emr-serverless.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

# Same data access as the Glue role, plus explicit Glue Catalog access and a place for logs.
resource "aws_iam_role_policy" "emr_serverless_job" {
  name = "datalake-access"
  role = aws_iam_role.emr_serverless_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBuckets"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [module.raw.bucket_arn, module.clean.bucket_arn, module.curated.bucket_arn, module.artifacts.bucket_arn]
      },
      {
        Sid      = "ReadRaw"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${module.raw.bucket_arn}/*"]
      },
      {
        Sid      = "ReadWriteCleanCurated"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${module.clean.bucket_arn}/*", "${module.curated.bucket_arn}/*"]
      },
      {
        Sid      = "ReadScripts"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${module.artifacts.bucket_arn}/scripts/*"]
      },
      {
        Sid      = "WriteJobLogs"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = ["${module.artifacts.bucket_arn}/logs/emr-serverless/*"]
      },
      {
        Sid      = "UseDatalakeKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = [aws_kms_key.datalake.arn]
      },
      {
        # Iceberg reads the table's schema from the catalog and commits new snapshots with UpdateTable.
        Sid    = "GlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetDatabases",
          "glue:GetTable", "glue:GetTables", "glue:GetPartition", "glue:GetPartitions",
          "glue:CreateTable", "glue:UpdateTable",
        ]
        Resource = [
          "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:database/default",
          "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:database/bronze",
          "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:database/silver",
          "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:table/bronze/*",
          "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:table/silver/*",
        ]
      },
    ]
  })
}

output "emr_serverless_application_id" {
  value = aws_emrserverless_application.spark.id
}

output "emr_serverless_job_role_arn" {
  value = aws_iam_role.emr_serverless_job.arn
}
