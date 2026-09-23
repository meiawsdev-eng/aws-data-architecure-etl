output "bucket_name" {
  description = "Name of the Terraform state bucket (use it in backend blocks)."
  value       = aws_s3_bucket.state.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.state.arn
}
