variable "aws_account_id" {
  description = "ID of the platform's AWS account, which holds this root's state."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "Region of the state bucket and its KMS key."
  type        = string
}

variable "name_prefix" {
  description = "Prefix of the bootstrap-created state bucket and KMS key alias."
  type        = string
}

variable "domain" {
  description = "Apex domain of the platform; its Cloudflare zone is created by the bootstrap root."
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account that hosts the zone."
  type        = string
}

variable "email_aliases" {
  description = "Local parts that receive mail (for example `security` for `security@<domain>`). Everything else is dropped."
  type        = set(string)

  validation {
    condition     = alltrue([for a in var.email_aliases : can(regex("^[a-z0-9][a-z0-9.-]*$", a))])
    error_message = "email_aliases must be lowercase local parts without the domain."
  }
}

variable "email_destination" {
  description = "Mailbox the aliases forward to. Personal data, so it is never committed: CI reads it from SSM."
  type        = string
  sensitive   = true
}
