# aws-kms-key

A customer-managed KMS key with an alias, for data whose encryption the platform must control (for example the SSM
parameters that hold vendor tokens). An AWS-managed key (`aws/s3`, `aws/ssm`) can't be given a key policy, scheduled for
deletion, or restricted to specific roles, so the platform uses its own key wherever that control matters.

- Automatic yearly rotation; deletion waits `deletion_window_in_days` (7–30, default 30) after it is scheduled.
- The alias can't start with `aws/`, which AWS reserves for its managed keys.
- `role` and `data_classification` become the key's tags
  ([ADR-0135](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0135-one-resource-tagging-strategy-across-every-vendor.md)).
- While `deletion_protection` is `true`, a guard resource makes `tofu destroy` fail.

## Usage

```hcl
module "secrets_key" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-kms-key?ref=<version>"

  alias       = "example-secrets"
  description = "Encrypts the SSM parameters that hold vendor tokens for CI."
  role        = "secrets"
}

resource "aws_ssm_parameter" "token" {
  name   = "/example/lab/api-token"
  type   = "SecureString"
  key_id = module.secrets_key.key_arn
  value  = var.token
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.13.0 |
| aws | >= 6.0, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0, < 7.0 |
| terraform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [terraform_data.deletion_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| alias | Alias (without the `alias/` prefix) for the key. | `string` | n/a | yes |
| description | What the key protects. | `string` | n/a | yes |
| role | Purpose of the key, used as the `role` tag (for example `secrets`). | `string` | n/a | yes |
| data\_classification | Classification of the data the key protects. | `string` | `"restricted"` | no |
| deletion\_protection | Protect the key from deletion: blocks `tofu destroy` of this component. Set false only for disposable environments. | `bool` | `true` | no |
| deletion\_window\_in\_days | Waiting period before a scheduled deletion takes effect (7-30 days). | `number` | `30` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| alias\_name | Full alias name (for example `alias/identity-platform-secrets`). |
| key\_arn | ARN of the key. |
| key\_id | ID of the key. |
<!-- END_TF_DOCS -->
