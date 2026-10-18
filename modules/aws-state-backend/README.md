# aws-state-backend

The S3 bucket and KMS key that hold OpenTofu state for every root. State is encrypted twice: at rest by S3 with the
customer-managed key, and client-side by OpenTofu's state encryption before it leaves the runner
([ADR-0132](https://github.com/NCodeGroup/Identity/blob/main/docs/adr/0132-platform-infrastructure-as-code-is-public-on-github.md)).

- **Bucket:** versioned, so any earlier state can be restored; old versions expire after
  `noncurrent_version_retention_days`. Object ownership is enforced, public access is blocked, and the bucket policy
  denies any request that isn't TLS.
- **Locking:** OpenTofu's native S3 lock files (`use_lockfile = true`); no DynamoDB table.
- **Encryption:** SSE-KMS with an S3 bucket key, using a dedicated customer-managed key with yearly rotation and a
  30-day deletion window. CI roots also use this key with OpenTofu's `aws_kms` key provider for client-side state
  encryption.
- **Deletion protection:** while `deletion_protection` is `true` the bucket can't be force-destroyed and a guard
  resource makes `tofu destroy` fail.

## Usage

```hcl
module "state_backend" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-state-backend?ref=<version>"

  bucket_name = "example-tofu-state-123456789012"
  kms_alias   = "example-tofu-state"
}
```

A root then uses it as its backend:

```hcl
terraform {
  backend "s3" {
    bucket       = "example-tofu-state-123456789012"
    key          = "lab/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
```

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
| terraform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_kms_alias.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [terraform_data.deletion_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_iam_policy_document.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| bucket\_name | Globally unique name of the S3 bucket that stores OpenTofu state. | `string` | n/a | yes |
| kms\_alias | Alias (without the `alias/` prefix) of the KMS key used for OpenTofu client-side state and plan encryption. | `string` | n/a | yes |
| deletion\_protection | Protect the bucket and key from deletion: blocks `tofu destroy` of this component and disables force-destroy of a non-empty bucket. Set false only for disposable environments. | `bool` | `true` | no |
| noncurrent\_version\_retention\_days | Days to keep previous state versions before they expire. | `number` | `90` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_arn | ARN of the state bucket. |
| bucket\_name | Name of the state bucket. |
| kms\_alias\_name | Full alias name of the encryption key (for example `alias/identity-platform-state`). |
| kms\_key\_arn | ARN of the KMS key for OpenTofu client-side state and plan encryption. |
<!-- prettier-ignore-end -->
<!-- END_TF_DOCS -->
