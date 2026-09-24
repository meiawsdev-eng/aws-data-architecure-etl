# Step 7: the role Glue ETL jobs run as. Least privilege: read raw, write clean/curated,
# read scripts, use the data lake key. Nothing else.

resource "aws_iam_role" "glue_etl" {
  name = "${local.prefix}-glue-etl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

# AWS-managed baseline for Glue: catalog access, CloudWatch logs and metrics.
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_etl.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_etl_data" {
  name = "datalake-access"
  role = aws_iam_role.glue_etl.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBuckets"
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [
          module.raw.bucket_arn,
          module.clean.bucket_arn,
          module.curated.bucket_arn,
          module.artifacts.bucket_arn,
        ]
      },
      {
        # Bronze is read-only for ETL jobs: raw data must never be modified.
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
        Sid      = "SparkTempFiles"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${module.artifacts.bucket_arn}/tmp/*"]
      },
      {
        Sid      = "UseDatalakeKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = [aws_kms_key.datalake.arn]
      },
    ]
  })
}
