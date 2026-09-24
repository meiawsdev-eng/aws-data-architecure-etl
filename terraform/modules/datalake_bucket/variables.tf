variable "bucket_name" {
  description = "Globally unique S3 bucket name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key used for default bucket encryption."
  type        = string
}

variable "versioning" {
  description = "Keep previous object versions (recommended for raw data)."
  type        = bool
  default     = false
}

variable "noncurrent_version_days" {
  description = "Days to keep previous object versions when versioning is on."
  type        = number
  default     = 90
}

variable "transition_to_ia_days" {
  description = "Move objects to STANDARD_IA after this many days (null = never)."
  type        = number
  default     = null
}

variable "expire_days" {
  description = "Delete objects under expire_prefix after this many days (null = never)."
  type        = number
  default     = null
}

variable "expire_prefix" {
  description = "Prefix the expire_days rule applies to (\"\" = whole bucket)."
  type        = string
  default     = ""
}
