mock_provider "github" {
  mock_data "github_user" {
    defaults = {
      id = "1234567"
    }
  }
}

variables {
  name                     = "example-infra"
  description              = "Example infrastructure"
  homepage_url             = "https://example.com"
  topics                   = ["opentofu"]
  allowed_actions_patterns = ["opentofu/setup-opentofu@*"]
  environments = {
    lab = {
      variables = {
        AWS_ROLE_ARN = "arn:aws:iam::123456789012:role/example-apply-lab"
      }
    }
    production = {
      reviewers = ["example-owner"]
    }
  }
  variables = {
    AWS_REGION = "us-west-2"
  }
}

run "repository_is_hardened" {
  command = plan

  assert {
    condition = (
      !github_repository.this.allow_merge_commit &&
      github_repository.this.allow_squash_merge &&
      !github_repository.this.allow_rebase_merge &&
      !github_repository.this.has_wiki &&
      github_repository.this.delete_branch_on_merge
    )
    error_message = "Only squash merges, no wiki, and head branches deleted after merge."
  }

  assert {
    condition     = github_actions_repository_permissions.this.sha_pinning_required && github_actions_repository_permissions.this.allowed_actions == "selected"
    error_message = "Actions must be allow-listed and pinned to full commit SHAs."
  }

  assert {
    condition     = github_workflow_repository_permissions.this.default_workflow_permissions == "read" && !github_workflow_repository_permissions.this.can_approve_pull_request_reviews
    error_message = "Workflows get a read-only token and can't approve pull requests."
  }

  assert {
    condition     = github_repository.this.archive_on_destroy && length(terraform_data.deletion_guard) == 1
    error_message = "The repository must be protected from deletion by default."
  }
}

run "environments_deploy_only_from_main" {
  command = plan

  assert {
    condition     = toset(keys(github_repository_environment.this)) == toset(["lab", "production"])
    error_message = "One environment per entry."
  }

  assert {
    condition     = alltrue([for p in values(github_repository_environment_deployment_policy.default_branch) : p.branch_pattern == "main"])
    error_message = "Only the default branch may deploy."
  }

  assert {
    condition     = length(github_repository_environment.this["production"].reviewers) == 1 && length(github_repository_environment.this["lab"].reviewers) == 0
    error_message = "Reviewers apply only where configured."
  }

  assert {
    condition     = github_actions_environment_variable.this["lab:AWS_ROLE_ARN"].environment == "lab"
    error_message = "Environment variables must be scoped to their environment."
  }
}

run "release_tags_are_immutable" {
  command = plan

  assert {
    condition     = github_repository_ruleset.release_tags.rules[0].deletion && github_repository_ruleset.release_tags.rules[0].update
    error_message = "Release tags can't be deleted or moved."
  }
}

run "auto_merge_is_opt_in" {
  command = plan

  assert {
    condition     = !github_repository.this.allow_auto_merge
    error_message = "Auto-merge must be off unless allow_auto_merge is set."
  }
}

run "auto_merge_can_be_enabled" {
  command = plan

  variables {
    allow_auto_merge = true
  }

  assert {
    condition     = github_repository.this.allow_auto_merge
    error_message = "allow_auto_merge must turn on the repository's auto-merge."
  }
}
