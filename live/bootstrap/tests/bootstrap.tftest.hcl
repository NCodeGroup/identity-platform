mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "github" {
  mock_data "github_user" {
    defaults = {
      id = "1234567"
    }
  }

  # Numeric IDs, as GitHub returns them; the OIDC component rejects anything else.
  mock_data "github_organization" {
    defaults = {
      id = "12114478"
    }
  }

  mock_resource "github_repository" {
    defaults = {
      repo_id = 1424838623
    }
  }
}

mock_provider "time" {
  mock_resource "time_rotating" {
    defaults = {
      rotation_rfc3339 = "2027-01-01T00:00:00Z"
    }
  }
}

mock_provider "cloudflare" {
  mock_resource "cloudflare_zone" {
    defaults = {
      id = "0123456789abcdef0123456789abcdef"
    }
  }

  mock_data "cloudflare_account_api_token_permission_groups_list" {
    defaults = {
      result = [
        { id = "z1", name = "Zone Read", scopes = ["com.cloudflare.api.account.zone"], category = "dns_and_zones", is_selectable = true },
        { id = "z2", name = "Zone Settings Read", scopes = ["com.cloudflare.api.account.zone"], category = "dns_and_zones", is_selectable = true },
        { id = "z3", name = "Zone Settings Write", scopes = ["com.cloudflare.api.account.zone"], category = "dns_and_zones", is_selectable = true },
        { id = "z4", name = "DNS Read", scopes = ["com.cloudflare.api.account.zone"], category = "dns_and_zones", is_selectable = true },
        { id = "z5", name = "DNS Write", scopes = ["com.cloudflare.api.account.zone"], category = "dns_and_zones", is_selectable = true },
        { id = "z6", name = "SSL and Certificates Read", scopes = ["com.cloudflare.api.account.zone"], category = "dns_and_zones", is_selectable = true },
        { id = "z7", name = "SSL and Certificates Write", scopes = ["com.cloudflare.api.account.zone"], category = "dns_and_zones", is_selectable = true },
        { id = "z8", name = "Email Routing Rules Read", scopes = ["com.cloudflare.api.account.zone"], category = "dns_and_zones", is_selectable = true },
        { id = "z9", name = "Email Routing Rules Write", scopes = ["com.cloudflare.api.account.zone"], category = "dns_and_zones", is_selectable = true },
        { id = "a1", name = "Email Routing Addresses Read", scopes = ["com.cloudflare.api.account"], category = "dns_and_zones", is_selectable = true },
        { id = "a2", name = "Email Routing Addresses Write", scopes = ["com.cloudflare.api.account"], category = "dns_and_zones", is_selectable = true },
      ]
    }
  }
}

variables {
  aws_account_id            = "123456789012"
  state_passphrase          = "a-test-passphrase-that-is-long-enough"
  adopt_existing_repository = false
}

run "ci_roles_are_least_privilege" {
  command = plan

  assert {
    condition     = alltrue([for a in values(local.ci_state_access) : !contains(concat(a.read, a.write), "bootstrap")])
    error_message = "No CI role may reach the bootstrap state."
  }

  assert {
    condition     = local.ci_state_access.plan.write == [] && local.ci_state_access.lab.read == ["lab"] && local.ci_state_access.lab.write == ["lab"]
    error_message = "Plans never write state, and lab can't read or write any other environment's state."
  }

  assert {
    condition     = local.ci_secret_scopes.lab == ["lab"] && local.ci_secret_scopes.plan == ["plan"]
    error_message = "Lab and plan roles only read their own secrets."
  }
}

run "cloudflare_plan_token_is_read_only" {
  command = plan

  assert {
    condition     = alltrue([for n in concat(local.cloudflare_tokens.plan.zone, local.cloudflare_tokens.plan.account) : endswith(n, " Read")])
    error_message = "The plan token must only hold read permissions."
  }

  assert {
    condition     = length(local.cloudflare_missing_groups) == 0
    error_message = "Every requested permission group must resolve."
  }

  assert {
    condition     = aws_ssm_parameter.cloudflare_token["plan"].name == "/identity-platform/plan/cloudflare-api-token" && aws_ssm_parameter.cloudflare_token["plan"].type == "SecureString"
    error_message = "Tokens are stored as SecureString under the scope CI reads them from."
  }
}

run "only_production_requires_review" {
  command = plan

  assert {
    condition     = module.repository.environments == ["lab", "production"]
    error_message = "The repository must have exactly the lab and production environments."
  }
}
