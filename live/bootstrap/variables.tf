variable "aws_account_id" {
  description = "ID of the platform's dedicated AWS member account. Guards against applying to any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "Home region of the platform's AWS account (state, backups, secrets)."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for AWS resource names; also the AWS account name used in tags."
  type        = string
}

variable "domain" {
  description = "Apex domain of the platform."
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account that hosts the zone."
  type        = string
}

variable "github_owner" {
  description = "GitHub organization that owns the infrastructure repository."
  type        = string
}

variable "github_repository" {
  description = "Name of the public infrastructure repository."
  type        = string
}

variable "adopt_existing_repository" {
  description = "Import the hand-created repository on the first apply. `tofu test` sets it to false because mocked providers can't import."
  type        = bool
  default     = true
}

variable "github_reviewers" {
  description = "GitHub logins that approve production deployments."
  type        = list(string)
}

variable "owner_email" {
  description = "Role mailbox that owns every resource and receives budget alerts."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly AWS cost budget; alerts at 80% forecast and 100% actual."
  type        = number
}

variable "cloudflare_token_rotation_days" {
  description = "Days between rotations of the CI Cloudflare tokens. Rotation happens on the next bootstrap apply after this period; tokens expire 30 days later."
  type        = number
  default     = 90
}

variable "state_passphrase" {
  description = "Passphrase that encrypts this root's state and plans. Held by the owner (password manager); never stored in the repository or CI."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.state_passphrase) >= 32
    error_message = "state_passphrase must be at least 32 characters."
  }
}
