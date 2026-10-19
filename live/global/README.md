# global

Platform-wide settings that aren't tied to one environment, applied by CI. It starts with inbound email for the apex
domain and will gain the DNS records that point at each environment's entry points.

- **Inbound email** — Cloudflare Email Routing forwards each address in `email_aliases` (`security@`, `platform@`,
  `postmaster@`, `abuse@`, and one per vendor account) to the owner's mailbox and drops everything else. Nothing sends
  as the domain, so the bootstrap's DMARC record stays at `p=reject`.
- **Inputs from the bootstrap** — the zone (looked up by name), the state bucket, and the KMS key that encrypts this
  root's state and plans (`alias/<name_prefix>-tofu-state`).

## How it is deployed

The [`deploy`](../../.github/workflows/deploy.yml) workflow plans this root on every pull request that touches `live/`
and shows the plan in the run's summary. After a merge to `main` it plans again and, if there are changes, applies
exactly that plan from the **`production`** environment, which waits for a reviewer's approval. A daily scheduled plan
fails if the real world has drifted from `main`.

| Step  | IAM role                         | Cloudflare token (from SSM)                 |
| ----- | -------------------------------- | ------------------------------------------- |
| plan  | `<name_prefix>-plan` (read-only) | `/<repository>/plan/cloudflare-api-token`   |
| apply | `<name_prefix>-apply-production` | `/<repository>/global/cloudflare-api-token` |

AWS sessions are named `gh-<run_id>-<run_attempt>`, so CloudTrail ties every call to its workflow run
([ADR-0136](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0136-provenance-is-attested-on-workloads-and-audited-for-infrastructure.md)).

## Before the first apply

The forwarding mailbox is personal data, so it is never committed. Store it once for each scope that reads it, as the
owner, with the bootstrap's secrets key:

```powershell
$email = Read-Host -MaskInput 'Forwarding mailbox'
foreach ($scope in 'plan', 'global') {
  aws ssm put-parameter --profile nidentity-platform-admin --region us-west-2 `
    --name "/identity-platform/$scope/email-destination" --type SecureString `
    --key-id alias/nidentity-platform-secrets --value $email
}
```

After the first apply, Cloudflare emails the mailbox a verification link; forwarding starts once it is clicked.

## Running it locally

Plans need the owner's AWS session (for the state and its KMS key) and a Cloudflare token:

```powershell
$env:AWS_PROFILE = 'nidentity-platform-admin'; aws sso login
$env:CLOUDFLARE_API_TOKEN = aws ssm get-parameter --name /identity-platform/plan/cloudflare-api-token --with-decryption --query Parameter.Value --output text
$env:TF_VAR_email_destination = aws ssm get-parameter --name /identity-platform/plan/email-destination --with-decryption --query Parameter.Value --output text
tofu init
tofu plan
```

Apply only through CI.

<!-- BEGIN_TF_DOCS -->
<!-- prettier-ignore-start -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | ~> 1.13.0 |
| cloudflare | ~> 5.28 |

## Providers

| Name | Version |
| ---- | ------- |
| cloudflare | ~> 5.28 |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_email_routing_address.owner](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/email_routing_address) | resource |
| [cloudflare_email_routing_catch_all.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/email_routing_catch_all) | resource |
| [cloudflare_email_routing_dns.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/email_routing_dns) | resource |
| [cloudflare_email_routing_rule.alias](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/email_routing_rule) | resource |
| [cloudflare_email_routing_settings.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/email_routing_settings) | resource |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| aws\_account\_id | ID of the platform's AWS account, which holds this root's state. | `string` | n/a | yes |
| aws\_region | Region of the state bucket and its KMS key. | `string` | n/a | yes |
| cloudflare\_account\_id | Cloudflare account that hosts the zone. | `string` | n/a | yes |
| domain | Apex domain of the platform; its Cloudflare zone is created by the bootstrap root. | `string` | n/a | yes |
| email\_aliases | Local parts that receive mail (for example `security` for `security@<domain>`). Everything else is dropped. | `set(string)` | n/a | yes |
| email\_destination | Mailbox the aliases forward to. Personal data, so it is never committed: CI reads it from SSM. | `string` | n/a | yes |
| name\_prefix | Prefix of the bootstrap-created state bucket and KMS key alias. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| email\_addresses | Addresses that receive mail; all others are dropped. |
| zone\_id | Cloudflare zone of the apex domain. |
<!-- prettier-ignore-end -->
<!-- END_TF_DOCS -->
