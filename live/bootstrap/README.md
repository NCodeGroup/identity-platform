# bootstrap

The root of trust for the platform. It creates everything the CI pipeline needs before the pipeline can run — so it is
the one root an owner runs by hand, from their own machine, with short-lived credentials. Every other root runs from
GitHub Actions.

| Creates                                       | Why it can't come from CI                            |
| --------------------------------------------- | ---------------------------------------------------- |
| S3 state bucket + KMS key                     | CI keeps its state there                             |
| S3 backup bucket (Object Lock)                | Shared foundation, protected from every CI role      |
| KMS key for secrets                           | Encrypts the vendor tokens CI reads                  |
| GitHub OIDC provider and the plan/apply roles | These _are_ CI's AWS identity                        |
| Cloudflare zone, DNSSEC, CAA, DMARC           | The zone must exist before scoped tokens can name it |
| Scoped Cloudflare tokens → SSM SecureString   | CI's Cloudflare credentials, rotated here            |
| Repository settings, rulesets, environments   | Gate who can obtain the apply roles                  |
| Monthly AWS budget alert                      | Cost guard for the whole account                     |

Decisions behind it:
[ADR-0132](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0132-platform-infrastructure-as-code-is-public-on-github.md)
(public repository, OIDC, state and secrets),
[ADR-0131](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0131-hosted-platform-environment-model-and-hostname-scheme.md)
(environments and DNS), and
[ADR-0135](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0135-one-resource-tagging-strategy-across-every-vendor.md)
(tags). The end-to-end manual procedure, including the vendor sign-ups this root depends on, is the
[platform bootstrap runbook](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md).

## When to run it

- **Once** to create the platform (the first run below).
- **At least every 90 days** to rotate the CI Cloudflare tokens (`cloudflare_token_rotation_days`). A rotation is due
  when `tofu plan` shows the tokens being replaced. Tokens expire 30 days after their scheduled rotation, so a late run
  is not an outage — a missed one is.
- **Whenever this directory changes.** Changes still go through a pull request; CI validates and tests them, but only
  an owner applies them.

## Before you start

1. Finish the [runbook](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md) sections
   [1. Domain registrar](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md#1-domain-registrar-porkbun)
   through
   [5. OCI](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md#5-oci-the-lab) — registrar,
   GitHub, Cloudflare bootstrap token, AWS account, OCI. This README is the runbook's section 6.
2. Install OpenTofu through [tenv](https://github.com/tofuutils/tenv); in the repository run `tenv tofu install`, which
   installs the version in `.opentofu-version`.
3. Put the platform AWS account ID into `terraform.tfvars` as `aws_account_id` and commit it. It is not a secret, and the
   AWS provider refuses to run against any other account.
4. Have the **state passphrase** ready: at least 32 random characters, kept in the owner's password manager. It
   encrypts this root's state and plans (this root creates the KMS key everything else uses, so it can't use it
   itself). Use the same passphrase on every run; without it the state can't be read.
5. Create the short-lived **GitHub bootstrap token** — fine-grained, only this repository, _Administration_,
   _Environments_, and _Variables_ read/write, expiring tomorrow, approved by an organization owner — as in runbook
   section
   [6. Run the bootstrap stack](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md#6-run-the-bootstrap-stack).

Set the credentials for **this shell only** — never in a file:

```powershell
$env:AWS_PROFILE = 'nidentity-platform-admin'; aws sso login
$env:CLOUDFLARE_API_TOKEN = Read-Host -MaskInput 'Cloudflare bootstrap token'
$env:GITHUB_TOKEN = Read-Host -MaskInput 'GitHub fine-grained token'
$env:TF_VAR_state_passphrase = Read-Host -MaskInput 'State passphrase'
```

## First run: local state, then move it into the bucket it created

The state bucket can't hold this root's state before this root has created it. So the first run keeps its state in a
local file — already encrypted with the passphrase — and then moves it into the new bucket. From then on this root
manages the bucket that holds its own state, which the bucket's versioning, `force_destroy = false`, and deletion
guard keep safe.

1. **Switch to a local backend.** Create `backend_override.tf` next to this README. OpenTofu's
   [override files](https://opentofu.org/docs/language/files/override/) replace the `backend "s3"` block, and
   `*_override.tf` is git-ignored, so it can't be committed by accident:

   ```powershell
   Set-Content backend_override.tf "terraform {`n  backend `"local`" {}`n}"
   ```

2. **Create everything** — from a saved plan, so what you apply is exactly what you reviewed. Expect only additions
   plus one import (the repository), and nothing changed or destroyed:

   ```powershell
   tofu init
   tofu plan -out bootstrap.tfplan
   tofu apply bootstrap.tfplan
   ```

   The first apply imports the repository you created by hand (runbook section
   [2. GitHub](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md#2-github-organization-and-repository))
   instead of creating it. If DNSSEC fails because the zone is still `pending`, carry on: delegate the domain to the
   name servers shown in the Cloudflare dashboard (runbook section
   [7. Delegate the domain](https://github.com/NCodeGroup/Identity/blob/main/docs/platform-bootstrap.md#7-delegate-the-domain))
   and re-run `tofu apply` once the zone is active.

3. **Move the state into S3.** Delete the override and let OpenTofu copy the state into
   `s3://<name_prefix>-tofu-state-<aws_account_id>/bootstrap/terraform.tfstate`; answer `yes` when it asks to copy:

   ```powershell
   Remove-Item backend_override.tf
   tofu init -migrate-state
   Remove-Item terraform.tfstate*, bootstrap.tfplan
   ```

4. **Verify.** `tofu plan` reports no changes, and the state object exists in the bucket. Until the domain is
   delegated and its DS record published (runbook section 7), the plan shows one in-place update of
   `cloudflare_zone_dnssec` from `pending` to `active` — don't apply it; it disappears once Cloudflare sees the DS
   record.

5. **Revoke** the Cloudflare bootstrap token and the GitHub token, and close the shell.

The repository rulesets now require a pull request with a passing `validate` check for every change to `main`.

## Later runs

Same credentials and passphrase, no override file, and again from a saved plan:

```powershell
tofu init
tofu plan -out bootstrap.tfplan
tofu apply bootstrap.tfplan
Remove-Item bootstrap.tfplan
```

Every command that evaluates the configuration — `plan`, `apply`, `output`, `console`, even `providers schema` — needs
`TF_VAR_state_passphrase`, because the encryption settings are evaluated first.

## Deletion protection and break-glass

Every stateful component here keeps its default `deletion_protection = true`: buckets can't be force-destroyed, the
repository is archived instead of deleted, and each component's `terraform_data.deletion_guard` makes any plan that
would destroy it fail. To remove one on purpose, set its `deletion_protection = false` **and** first remove its guard
from state (`tofu state rm '<module>.terraform_data.deletion_guard[0]'`) — the guard can't be switched off by an
apply, by design.

## Recovery

- **A bad apply corrupted the state:** restore the previous version of the state object (the bucket is versioned).
- **The passphrase is lost:** the state can't be decrypted. Start a fresh state with a new passphrase (first run, step
  1. and adopt the existing resources with `import` blocks before applying.
- **The bucket or account is lost:** repeat the first run in a new account and import whatever survived (the
  Cloudflare zone, the GitHub repository).

## Module sources

Like every root, this one consumes components only by released version — pinned to a protected, immutable release tag
(`?ref=vX.Y.Z`), never by local path; CI rejects anything else
([ADR-0133](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0133-we-ship-and-run-the-same-deployment-artifacts.md),
the member rule). A component change therefore reaches this root in two steps: release it, then bump the `ref` here
(Dependabot proposes the bump).

<!-- BEGIN_TF_DOCS -->
<!-- prettier-ignore-start -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | ~> 1.13.0 |
| aws | ~> 6.69 |
| cloudflare | ~> 5.28 |
| github | ~> 6.13 |
| time | ~> 0.14 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | ~> 6.69 |
| cloudflare | ~> 5.28 |
| github | ~> 6.13 |
| time | ~> 0.14 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| backup\_bucket | git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-backup-bucket | v0.2.0 |
| github\_oidc | git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-github-oidc | v0.2.0 |
| repository | git::https://github.com/NCodeGroup/identity-platform.git//modules/github-repository | v0.2.0 |
| secrets\_key | git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-kms-key | v0.2.0 |
| state\_backend | git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-state-backend | v0.2.0 |
| tags | git::https://github.com/NCodeGroup/identity-platform.git//modules/tags | v0.2.0 |
| zone | git::https://github.com/NCodeGroup/identity-platform.git//modules/cloudflare-zone | v0.2.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_budgets_budget.monthly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_ssm_parameter.cloudflare_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [cloudflare_account_token.ci](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/account_token) | resource |
| [time_rotating.cloudflare_tokens](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |
| [aws_iam_policy_document.ci](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [cloudflare_account_api_token_permission_groups_list.account](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/account_api_token_permission_groups_list) | data source |
| [cloudflare_account_api_token_permission_groups_list.zone](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/account_api_token_permission_groups_list) | data source |
| [github_organization.owner](https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/organization) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| aws\_account\_id | ID of the platform's dedicated AWS member account. Guards against applying to any other account. | `string` | n/a | yes |
| aws\_region | Home region of the platform's AWS account (state, backups, secrets). | `string` | n/a | yes |
| cloudflare\_account\_id | Cloudflare account that hosts the zone. | `string` | n/a | yes |
| domain | Apex domain of the platform. | `string` | n/a | yes |
| github\_owner | GitHub organization that owns the infrastructure repository. | `string` | n/a | yes |
| github\_repository | Name of the public infrastructure repository. | `string` | n/a | yes |
| github\_reviewers | GitHub logins that approve production deployments. | `list(string)` | n/a | yes |
| monthly\_budget\_usd | Monthly AWS cost budget; alerts at 80% forecast and 100% actual. | `number` | n/a | yes |
| name\_prefix | Prefix for AWS resource names; also the AWS account name used in tags. | `string` | n/a | yes |
| owner\_email | Role mailbox that owns every resource and receives budget alerts. | `string` | n/a | yes |
| state\_passphrase | Passphrase that encrypts this root's state and plans. Held by the owner (password manager); never stored in the repository or CI. | `string` | n/a | yes |
| adopt\_existing\_repository | Import the hand-created repository on the first apply. `tofu test` sets it to false because mocked providers can't import. | `bool` | `true` | no |
| cloudflare\_token\_rotation\_days | Days between rotations of the CI Cloudflare tokens. Rotation happens on the next bootstrap apply after this period; tokens expire 30 days later. | `number` | `90` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| backup\_bucket | Object Lock bucket for database backups. |
| ci\_role\_arns | IAM roles GitHub Actions assumes, by name. |
| dnssec\_ds | DS record to publish at the registrar once the zone is active. |
| name\_servers | Cloudflare name servers to set at the registrar. |
| state\_bucket | Bucket that holds every root's state. |
| state\_kms\_key\_arn | KMS key that encrypts state at rest and client-side in CI roots. |
<!-- prettier-ignore-end -->
<!-- END_TF_DOCS -->
