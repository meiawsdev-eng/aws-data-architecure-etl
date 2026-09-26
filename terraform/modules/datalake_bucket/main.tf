# One secure data lake bucket: KMS-encrypted, private, HTTPS-only, with optional versioning and lifecycle rules.

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    # "Disabled" is only valid for buckets that were never versioned; switching a versioned
    # bucket off later must use "Suspended".
    status = var.versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    # Bucket keys cut KMS request costs by ~99% for data-heavy buckets.
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # Failed multipart uploads leave invisible, billable parts behind.
  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.transition_to_ia_days == null ? [] : [1]
    content {
      id     = "transition-to-infrequent-access"
      status = "Enabled"
      filter {}
      transition {
        days          = var.transition_to_ia_days
        storage_class = "STANDARD_IA"
      }
    }
  }

  dynamic "rule" {
    for_each = var.expire_days == null ? [] : [1]
    content {
      id     = "expire-objects"
      status = "Enabled"
      filter {
        prefix = var.expire_prefix
      }
      expiration {
        days = var.expire_days
      }
    }
  }

  dynamic "rule" {
    for_each = var.versioning ? [1] : []
    content {
      id     = "expire-old-versions"
      status = "Enabled"
      filter {}
      noncurrent_version_expiration {
        noncurrent_days = var.noncurrent_version_days
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
