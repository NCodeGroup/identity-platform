# aws-github-oidc

Lets GitHub Actions workflows assume AWS IAM roles with short-lived OIDC tokens — no stored AWS keys anywhere
([ADR-0132](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0132-platform-infrastructure-as-code-is-public-on-github.md)).

- Creates the account's GitHub OIDC identity provider, or reuses an existing one through `provider_arn` (an account can
  have only one per URL).
- Each role trusts exactly the subjects you list for one repository, for example `pull_request`, `ref:refs/heads/main`,
  or `environment:production`. Both the audience (`sts.amazonaws.com`) and the subject must match exactly; wildcards are
  rejected.
- Trust matches GitHub's **immutable subject**, `repo:<owner>@<owner_id>/<name>@<id>:<context>`, so a deleted and
  re-created owner or repository with the same name can never assume the roles. It is the default for repositories
  created after July 15, 2026; an older repository must opt in (organization or repository Actions OIDC settings) before
  it can use this component.
- Every session must be named `gh-<run_id>-<run_attempt>` (`sts:RoleSessionName`), so CloudTrail ties each API call to
  the workflow run that made it
  ([ADR-0136](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0136-provenance-is-attested-on-workloads-and-audited-for-infrastructure.md)).
- Scope apply roles to **GitHub environments** (`environment:<name>`) so environment protection rules — required
  reviewers and the deploy-from-`main` branch policy — gate who can obtain them.
- Each role gets one inline policy from `policy_json`; keep it least-privilege.

## Usage

```hcl
module "github_oidc" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-github-oidc?ref=<version>"

  repository = {
    owner    = "ExampleOrg"
    owner_id = "123456" # GET https://api.github.com/orgs/ExampleOrg → id
    name     = "example-infra"
    id       = "456789" # GET https://api.github.com/repos/ExampleOrg/example-infra → id
  }

  roles = {
    example-plan = {
      description = "Read-only plans for pull requests."
      subjects    = ["pull_request"]
      policy_json = data.aws_iam_policy_document.plan.json
    }
    example-apply-production = {
      description = "Applies production from the reviewer-gated production environment."
      subjects    = ["environment:production"]
      policy_json = data.aws_iam_policy_document.apply.json
    }
  }
}
```

The workflow needs `permissions: id-token: write` and must name its session after the run — for example with
`aws-actions/configure-aws-credentials` and `role-session-name: gh-${{ github.run_id }}-${{ github.run_attempt }}`.

<!-- BEGIN_TF_DOCS -->
<!-- prettier-ignore-start -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.13.0 |
| aws | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_policy_document.trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| repository | GitHub repository allowed to assume the roles. `owner` and `name` are case-sensitive, as shown on GitHub. `owner_id` and `id` are GitHub's numeric owner and repository IDs; the trust policy matches GitHub's immutable subject, so a re-created owner or repository with the same name can't assume the roles. | ```object({ owner = string owner_id = string name = string id = string })``` | n/a | yes |
| roles | Roles to create, keyed by IAM role name. `subjects` are GitHub OIDC subject suffixes after the repository segment — for example `environment:production` or `pull_request`. `policy_json` is the inline permission policy. | ```map(object({ subjects = list(string) policy_json = string description = optional(string, "") max_session_duration = optional(number, 3600) }))``` | n/a | yes |
| create\_provider | Create the account's GitHub OIDC identity provider. Set to false and pass provider\_arn if it already exists. | `bool` | `true` | no |
| provider\_arn | ARN of an existing GitHub OIDC identity provider. Required when create\_provider is false. | `string` | `null` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| provider\_arn | ARN of the GitHub OIDC identity provider. |
| role\_arns | Role ARNs keyed by role name. |
<!-- prettier-ignore-end -->
<!-- END_TF_DOCS -->
