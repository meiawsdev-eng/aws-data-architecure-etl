# Role 1: the EMR SERVICE role — lets EMR launch and manage EC2 instances for the cluster.
resource "aws_iam_role" "emr_service" {
  name = "${local.prefix}-service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "elasticmapreduce.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = local.account_id } }
    }]
  })
}

# AWS-recommended policy; only works on network resources tagged for-use-with-amazon-emr-managed-policies=true.
resource "aws_iam_role_policy_attachment" "emr_service" {
  role       = aws_iam_role.emr_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEMRServicePolicy_v2"
}

# The v2 policy doesn't include PassRole: EMR may hand ONLY our node role to EC2, nothing else.
resource "aws_iam_role_policy" "emr_service_pass_role" {
  name = "pass-instance-role"
  role = aws_iam_role.emr_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "iam:PassRole"
      Resource  = aws_iam_role.emr_ec2.arn
      Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } }
    }]
  })
}

# Role 2: the NODE role — what Spark/YARN on the cluster machines run as.
resource "aws_iam_role" "emr_ec2" {
  name = "${local.prefix}-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Session Manager: open a shell on the primary node with no SSH keys and no open ports.
resource "aws_iam_role_policy_attachment" "emr_ec2_ssm" {
  role       = aws_iam_role.emr_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "emr_ec2_data" {
  name = "datalake-access"
  role = aws_iam_role.emr_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBuckets"
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [
          "arn:aws:s3:::${local.buckets.raw}",
          "arn:aws:s3:::${local.buckets.clean}",
          "arn:aws:s3:::${local.buckets.curated}",
          "arn:aws:s3:::${local.buckets.artifacts}",
        ]
      },
      {
        Sid      = "ReadRaw"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::${local.buckets.raw}/*"]
      },
      {
        Sid      = "ReadWriteCleanCurated"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["arn:aws:s3:::${local.buckets.clean}/*", "arn:aws:s3:::${local.buckets.curated}/*"]
      },
      {
        Sid      = "ReadScripts"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::${local.buckets.artifacts}/scripts/*"]
      },
      {
        Sid      = "WriteClusterLogs"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = ["arn:aws:s3:::${local.buckets.artifacts}/logs/emr/*"]
      },
      {
        Sid      = "UseDatalakeKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = [local.kms_key_arn]
      },
      {
        Sid    = "GlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetDatabases",
          "glue:GetTable", "glue:GetTables", "glue:GetPartition", "glue:GetPartitions",
          "glue:CreateTable", "glue:UpdateTable",
        ]
        Resource = [
          "arn:aws:glue:us-east-1:${local.account_id}:catalog",
          "arn:aws:glue:us-east-1:${local.account_id}:database/default",
          "arn:aws:glue:us-east-1:${local.account_id}:database/bronze",
          "arn:aws:glue:us-east-1:${local.account_id}:database/silver",
          "arn:aws:glue:us-east-1:${local.account_id}:table/bronze/*",
          "arn:aws:glue:us-east-1:${local.account_id}:table/silver/*",
        ]
      },
    ]
  })
}

# The "container" that attaches the node role to EC2 machines.
resource "aws_iam_instance_profile" "emr_ec2" {
  name = "${local.prefix}-ec2"
  role = aws_iam_role.emr_ec2.name
}
