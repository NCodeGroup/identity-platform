mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  repository = "ExampleOrg/example-infra"
  roles = {
    example-plan = {
      subjects    = ["pull_request"]
      policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
    example-apply = {
      subjects    = ["environment:production"]
      policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "creates_provider_and_one_role_per_entry" {
  command = plan

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1
    error_message = "The GitHub OIDC provider must be created by default."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github[0].url == "https://token.actions.githubusercontent.com"
    error_message = "The provider must trust GitHub's token issuer."
  }

  assert {
    condition     = toset(keys(aws_iam_role.this)) == toset(["example-plan", "example-apply"])
    error_message = "One role must be created per roles entry."
  }

  assert {
    condition     = aws_iam_role.this["example-apply"].max_session_duration == 3600
    error_message = "Sessions must default to one hour."
  }
}

run "trust_is_pinned_to_exact_subjects" {
  command = plan

  assert {
    condition = contains(
      flatten([for c in data.aws_iam_policy_document.trust["example-apply"].statement[0].condition : c.values if c.variable == "token.actions.githubusercontent.com:sub"]),
      "repo:ExampleOrg/example-infra:environment:production",
    )
    error_message = "Apply role must trust only its environment's subject."
  }
}

run "rejects_wildcard_subjects" {
  command = plan

  variables {
    roles = {
      too-broad = {
        subjects    = ["ref:refs/heads/*"]
        policy_json = "{}"
      }
    }
  }

  expect_failures = [var.roles]
}

run "requires_provider_arn_when_not_created" {
  command = plan

  variables {
    create_provider = false
  }

  expect_failures = [var.provider_arn]
}
