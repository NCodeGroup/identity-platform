# github-repository

A hardened GitHub repository whose settings live in code: merge policy, security features, Actions restrictions,
rulesets, and deployment environments
([ADR-0132](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0132-platform-infrastructure-as-code-is-public-on-github.md)).

- **Merging:** squash only (pull request title and body become the commit), head branches deleted after merge.
- **Security:** secret scanning with push protection, Dependabot alerts and security updates.
- **Actions:** only GitHub-owned, verified-creator, and explicitly allowed actions, each pinned to a full commit SHA;
  workflows get a read-only `GITHUB_TOKEN` and can't approve pull requests.
- **Default branch ruleset:** no deletion or force push, linear history, pull requests required (with
  `required_approvals`, stale reviews dismissed, conversations resolved), and `required_status_checks` passing.
- **Release tags ruleset:** tags matching `release_tag_pattern` can't be deleted, moved, or force-pushed.
- **Environments:** deploy only from `main`; admins can't bypass protection; `reviewers` must approve each deployment.
  Non-secret values (role ARNs, regions) go in environment or repository **variables** — there are no stored secrets.
- With `deletion_protection = true` the repository is archived rather than deleted on destroy, and a guard resource
  makes `tofu destroy` fail.

Settings with no provider support — private vulnerability reporting and immutable releases — are set by hand
(see the [bootstrap runbook](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md)).

## Usage

```hcl
module "repository" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/github-repository?ref=<version>"

  name                     = "example-infra"
  description              = "Example infrastructure"
  allowed_actions_patterns = ["opentofu/setup-opentofu@*"]
  required_status_checks   = ["validate"]

  environments = {
    lab = {
      variables = { AWS_ROLE_ARN = "arn:aws:iam::123456789012:role/example-apply-lab" }
    }
    production = {
      reviewers = ["example-owner"]
      variables = { AWS_ROLE_ARN = "arn:aws:iam::123456789012:role/example-apply-production" }
    }
  }
}
```

To manage a repository that already exists, import it in the calling root:

```hcl
import {
  to = module.repository.github_repository.this
  id = "example-infra"
}
```

<!-- BEGIN_TF_DOCS -->
<!-- prettier-ignore-start -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.13.0 |
| github | >= 6.13, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| github | >= 6.13, < 7.0 |
| terraform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [github_actions_environment_variable.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_variable) | resource |
| [github_actions_repository_permissions.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_repository_permissions) | resource |
| [github_actions_variable.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable) | resource |
| [github_repository.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository) | resource |
| [github_repository_dependabot_security_updates.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_dependabot_security_updates) | resource |
| [github_repository_environment.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_environment) | resource |
| [github_repository_environment_deployment_policy.default_branch](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_environment_deployment_policy) | resource |
| [github_repository_ruleset.default_branch](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset) | resource |
| [github_repository_ruleset.release_tags](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_ruleset) | resource |
| [github_repository_vulnerability_alerts.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_vulnerability_alerts) | resource |
| [github_workflow_repository_permissions.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/workflow_repository_permissions) | resource |
| [terraform_data.deletion_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [github_user.reviewer](https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/user) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| description | Repository description. | `string` | n/a | yes |
| name | Repository name (without the owner). | `string` | n/a | yes |
| allowed\_actions\_patterns | Third-party actions allowed in addition to GitHub-owned and verified-creator actions, for example `opentofu/setup-opentofu@*`. Every action must still be pinned to a full commit SHA. | `list(string)` | `[]` | no |
| deletion\_protection | Archive instead of delete on destroy, and block `tofu destroy` of this component. | `bool` | `true` | no |
| environments | Deployment environments keyed by name. Only the default branch can deploy to them. `reviewers` are GitHub logins who must approve each deployment; `variables` are non-secret environment variables (role ARNs, regions, bucket names). | ```map(object({ reviewers = optional(list(string), []) prevent_self_review = optional(bool, false) wait_timer = optional(number, 0) variables = optional(map(string), {}) }))``` | `{}` | no |
| homepage\_url | Website shown in the repository's About panel. | `string` | `null` | no |
| release\_tag\_pattern | Tags protected from deletion and from being moved. | `string` | `"refs/tags/v*"` | no |
| required\_approvals | Approving reviews required before a pull request can merge into the default branch. | `number` | `0` | no |
| required\_status\_checks | Status check contexts that must pass before a pull request can merge into the default branch. | `list(string)` | `[]` | no |
| topics | Repository topics. | `list(string)` | `[]` | no |
| variables | Non-secret repository-level Actions variables (for example the read-only plan role ARN). | `map(string)` | `{}` | no |
| visibility | Repository visibility. | `string` | `"public"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| environments | Names of the deployment environments. |
| full\_name | Repository as `owner/name`. |
<!-- prettier-ignore-end -->
<!-- END_TF_DOCS -->
