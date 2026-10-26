# The repository already exists (created by hand in runbook step 2); adopt it instead of creating it.
import {
  for_each = var.adopt_existing_repository ? toset([var.github_repository]) : toset([])

  to = module.repository.github_repository.this
  id = each.value
}

# The owner's numeric ID, for GitHub's immutable OIDC subject.
data "github_organization" "owner" {
  name         = var.github_owner
  summary_only = true
}

module "repository" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/github-repository?ref=v0.3.0"

  name         = var.github_repository
  description  = "Infrastructure as code for the hosted NCode.Identity platform: OpenTofu components, Flux GitOps, and live environments."
  homepage_url = "https://${var.domain}"
  topics       = ["infrastructure-as-code", "opentofu", "kubernetes", "flux", "gitops", "oidc"]

  allowed_actions_patterns = ["opentofu/setup-opentofu@*"]
  required_status_checks   = ["validate"]

  variables = {
    AWS_REGION           = var.aws_region
    AWS_PLAN_ROLE_ARN    = module.github_oidc.role_arns["${var.name_prefix}-plan"]
    TF_STATE_BUCKET      = module.state_backend.bucket_name
    TF_STATE_KMS_KEY_ARN = module.state_backend.kms_key_arn
  }

  environments = {
    lab = {
      variables = {
        AWS_ROLE_ARN = module.github_oidc.role_arns["${var.name_prefix}-apply-lab"]
      }
    }
    production = {
      reviewers = var.github_reviewers
      variables = {
        AWS_ROLE_ARN = module.github_oidc.role_arns["${var.name_prefix}-apply-production"]
      }
    }
  }
}
