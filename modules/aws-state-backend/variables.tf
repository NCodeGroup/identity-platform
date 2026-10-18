variable "bucket_name" {
  description = "Globally unique name of the S3 bucket that stores OpenTofu state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid S3 bucket name (3-63 lowercase letters, digits, dots, hyphens)."
  }
}

variable "kms_alias" {
  description = "Alias (without the `alias/` prefix) of the KMS key used for OpenTofu client-side state and plan encryption."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_-]{1,250}$", var.kms_alias)) && !startswith(var.kms_alias, "aws/")
    error_message = "kms_alias must be a valid KMS alias name and must not start with `aws/`."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep previous state versions before they expire."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_retention_days >= 1
    error_message = "noncurrent_version_retention_days must be at least 1."
  }
}

variable "deletion_protection" {
  description = "Protect the bucket and key from deletion: blocks `tofu destroy` of this component and disables force-destroy of a non-empty bucket. Set false only for disposable environments."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
