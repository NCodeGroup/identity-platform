variable "repository" {
  description = <<-EOT
    GitHub repository allowed to assume the roles. `owner` and `name` are case-sensitive, as shown on GitHub. `owner_id`
    and `id` are GitHub's numeric owner and repository IDs; the trust policy matches GitHub's immutable subject, so a
    re-created owner or repository with the same name can't assume the roles.
  EOT
  type = object({
    owner    = string
    owner_id = string
    name     = string
    id       = string
  })

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.repository.owner)) && can(regex("^[A-Za-z0-9._-]+$", var.repository.name))
    error_message = "repository.owner and repository.name must be a GitHub owner login and repository name."
  }

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.repository.owner_id)) && can(regex("^[1-9][0-9]*$", var.repository.id))
    error_message = "repository.owner_id and repository.id must be GitHub's numeric IDs."
  }
}

variable "roles" {
  description = <<-EOT
    Roles to create, keyed by IAM role name. `subjects` are GitHub OIDC subject suffixes after the repository segment —
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
