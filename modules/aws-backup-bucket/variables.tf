variable "bucket_name" {
  description = "Globally unique name of the S3 bucket that stores backups."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid S3 bucket name (3-63 lowercase letters, digits, dots, hyphens)."
  }
}

variable "default_retention_days" {
  description = "Object Lock (compliance mode) retention applied to every new object. Nobody — including the account root — can delete or overwrite an object before it expires."
  type        = number
  default     = 14

  validation {
    condition     = var.default_retention_days >= 1
    error_message = "default_retention_days must be at least 1."
  }
}

variable "daily_prefix" {
  description = "Key prefix for daily backups."
  type        = string
  default     = "daily/"
}

variable "daily_expiration_days" {
  description = "Days after which daily backups expire. Must be greater than default_retention_days."
  type        = number
  default     = 15
}

variable "monthly_prefix" {
  description = "Key prefix for monthly backups. The writer sets a longer per-object retention on these."
  type        = string
  default     = "monthly/"
}

variable "monthly_archive_after_days" {
  description = "Days after which monthly backups move to the Glacier Deep Archive storage class."
  type        = number
  default     = 30
}

variable "monthly_expiration_days" {
  description = "Days after which monthly backups expire."
  type        = number
  default     = 400
}

variable "deletion_protection" {
  description = "Protect the bucket from deletion: blocks `tofu destroy` of this component and disables force-destroy. Object Lock still keeps locked objects until their retention expires either way."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
