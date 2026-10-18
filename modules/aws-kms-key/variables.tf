variable "alias" {
  description = "Alias (without the `alias/` prefix) for the key."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_-]{1,250}$", var.alias)) && !startswith(var.alias, "aws/")
    error_message = "alias must be a valid KMS alias name and must not start with `aws/` (reserved for AWS managed keys)."
  }
}

variable "description" {
  description = "What the key protects."
  type        = string
}

variable "role" {
  description = "Purpose of the key, used as the `role` tag (for example `secrets`)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.role))
    error_message = "role must be lowercase kebab-case, at most 40 characters."
  }
}

variable "data_classification" {
  description = "Classification of the data the key protects."
  type        = string
  default     = "restricted"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be public, internal, confidential, or restricted."
  }
}

variable "deletion_window_in_days" {
  description = "Waiting period before a scheduled deletion takes effect (7-30 days)."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "deletion_protection" {
  description = "Protect the key from deletion: blocks `tofu destroy` of this component. Set false only for disposable environments."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
