variable "application" {
  description = "Application or product the resources belong to."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.application))
    error_message = "application must be lowercase kebab-case, at most 40 characters."
  }
}

variable "environment" {
  description = "Platform environment the resources serve. Never a customer's tenant environment such as `dev` or `test`."
  type        = string

  validation {
    condition     = contains(["shared", "lab", "production", "ci"], var.environment)
    error_message = "environment must be shared, lab, production, or ci."
  }
}

variable "owner_email" {
  description = "Role mailbox that owns the resources. Never a personal address: tag values are public."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$", var.owner_email))
    error_message = "owner_email must be a lowercase email address."
  }
}

variable "account" {
  description = "Vendor account or tenancy the resources live in."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,39}$", var.account))
    error_message = "account must be lowercase kebab-case, at most 40 characters."
  }
}

variable "source_path" {
  description = "Repository and path of the root that manages the resources, for example `NCodeGroup/identity-platform/live/lab`."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]{1,120}$", var.source_path))
    error_message = "source_path must be a repository path without spaces, at most 120 characters."
  }
}

variable "managed_by" {
  description = "Tool that owns the resources' desired state."
  type        = string
  default     = "opentofu"

  validation {
    condition     = contains(["opentofu", "flux"], var.managed_by)
    error_message = "managed_by must be opentofu or flux."
  }
}
