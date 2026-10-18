variable "repository" {
  description = "GitHub repository allowed to assume the roles, as `owner/name` (case-sensitive, as shown on GitHub)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.repository))
    error_message = "repository must be in the form owner/name."
  }
}

variable "roles" {
  description = <<-EOT
    Roles to create, keyed by IAM role name. `subjects` are GitHub OIDC subject suffixes after `repo:<owner>/<name>:` —
    for example `environment:production` or `pull_request`. `policy_json` is the inline permission policy.
  EOT
  type = map(object({
    subjects             = list(string)
    policy_json          = string
    description          = optional(string, "")
    max_session_duration = optional(number, 3600)
  }))

  validation {
    condition     = alltrue([for r in values(var.roles) : length(r.subjects) > 0])
    error_message = "Every role needs at least one subject."
  }

  validation {
    condition     = alltrue(flatten([for r in values(var.roles) : [for s in r.subjects : !strcontains(s, "*")]]))
    error_message = "Subjects must be exact; wildcards would let any branch or environment assume the role."
  }
}

variable "create_provider" {
  description = "Create the account's GitHub OIDC identity provider. Set to false and pass provider_arn if it already exists."
  type        = bool
  default     = true
}

variable "provider_arn" {
  description = "ARN of an existing GitHub OIDC identity provider. Required when create_provider is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_provider || var.provider_arn != null
    error_message = "provider_arn is required when create_provider is false."
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
