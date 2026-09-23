variable "company_slug" {
  description = "Short lowercase company name used as a prefix for resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,20}[a-z0-9]$", var.company_slug))
    error_message = "company_slug must be 3-22 chars: lowercase letters, digits, hyphens."
  }
}

variable "env" {
  description = "Environment name: dev or prd."
  type        = string

  validation {
    condition     = contains(["dev", "prd"], var.env)
    error_message = "env must be \"dev\" or \"prd\"."
  }
}
