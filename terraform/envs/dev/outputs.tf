output "buckets" {
  value = {
    raw            = module.raw.bucket_name
    clean          = module.clean.bucket_name
    curated        = module.curated.bucket_name
    artifacts      = module.artifacts.bucket_name
    athena_results = module.athena_results.bucket_name
  }
}

output "kms_key_alias" {
  value = aws_kms_alias.datalake.name
}

output "glue_etl_role_arn" {
  value = aws_iam_role.glue_etl.arn
}

output "athena_workgroup" {
  value = aws_athena_workgroup.data_platform.name
}
