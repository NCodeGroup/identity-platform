variable "name" {
  description = "Repository name (without the owner)."
  type        = string
}

variable "description" {
  description = "Repository description."
  type        = string
}

variable "homepage_url" {
  description = "Website shown in the repository's About panel."
  type        = string
  default     = null
}

variable "topics" {
  description = "Repository topics."
  type        = list(string)
  default     = []
}

variable "visibility" {
  description = "Repository visibility."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be public or private."
  }
}

variable "allow_auto_merge" {
  description = "Let pull requests be set to merge on their own once everything the default branch ruleset requires has passed."
  type        = bool
  default     = false
}

variable "allowed_actions_patterns" {
  description = "Third-party actions allowed in addition to GitHub-owned and verified-creator actions, for example `opentofu/setup-opentofu@*`. Every action must still be pinned to a full commit SHA."
  type        = list(string)
  default     = []
}

variable "required_approvals" {
  description = "Approving reviews required before a pull request can merge into the default branch."
  type        = number
  default     = 0
}

variable "required_status_checks" {
  description = "Status check contexts that must pass before a pull request can merge into the default branch."
  type        = list(string)
  default     = []
}

variable "release_tag_pattern" {
  description = "Tags protected from deletion and from being moved."
  type        = string
  default     = "refs/tags/v*"
}

variable "environments" {
  description = <<-EOT
    Deployment environments keyed by name. Only the default branch can deploy to them. `reviewers` are GitHub logins
    who must approve each deployment; `variables` are non-secret environment variables (role ARNs, regions, bucket names).
  EOT
  type = map(object({
    reviewers           = optional(list(string), [])
    prevent_self_review = optional(bool, false)
    wait_timer          = optional(number, 0)
    variables           = optional(map(string), {})
  }))
  default = {}
}

variable "variables" {
  description = "Non-secret repository-level Actions variables (for example the read-only plan role ARN)."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Archive instead of delete on destroy, and block `tofu destroy` of this component."
  type        = bool
  default     = true
}
