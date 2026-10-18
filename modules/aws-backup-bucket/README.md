# aws-backup-bucket

An S3 bucket for database backups that nobody — including the account root and a compromised CI role — can delete or
alter before its retention ends.

- **Object Lock in compliance mode:** every object version is locked for `default_retention_days` from upload. Compliance
  mode can't be shortened or removed by any principal.
- **Retention tiers by prefix:** `daily/` objects expire after `daily_expiration_days`; `monthly/` objects move to
  Glacier Deep Archive after `monthly_archive_after_days` and expire after `monthly_expiration_days`. Preconditions keep
  every expiration longer than the lock.
- **Encryption:** SSE-S3, deliberately not KMS — a KMS key can be scheduled for deletion, which would make locked
  backups unreadable. Encrypt dumps with `age` before upload so the bucket only ever holds ciphertext.
- **Writers get the least they need:** `writer_policy_json` grants only `PutObject`, `PutObjectRetention`, and
  `AbortMultipartUpload` — no read, list, or delete.
- Versioned, public access blocked, object ownership enforced, TLS-only bucket policy, incomplete uploads aborted.

## Usage

```hcl
module "backups" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-backup-bucket?ref=<version>"

  bucket_name = "example-backups-123456789012"
}

resource "aws_iam_role_policy" "backup_writer" {
  role   = aws_iam_role.backup_writer.id
  policy = module.backups.writer_policy_json
}
```

> Object Lock can only be enabled when a bucket is created, and locked objects can't be removed early. Setting
> `deletion_protection = false` lets OpenTofu try to empty and delete the bucket, but it still can't delete objects that
> are under retention.

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
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_object_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [terraform_data.deletion_guard](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_iam_policy_document.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.writer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| bucket\_name | Globally unique name of the S3 bucket that stores backups. | `string` | n/a | yes |
| daily\_expiration\_days | Days after which daily backups expire. Must be greater than default\_retention\_days. | `number` | `15` | no |
| daily\_prefix | Key prefix for daily backups. | `string` | `"daily/"` | no |
| default\_retention\_days | Object Lock (compliance mode) retention applied to every new object. Nobody — including the account root — can delete or overwrite an object before it expires. | `number` | `14` | no |
| deletion\_protection | Protect the bucket from deletion: blocks `tofu destroy` of this component and disables force-destroy. Object Lock still keeps locked objects until their retention expires either way. | `bool` | `true` | no |
| monthly\_archive\_after\_days | Days after which monthly backups move to the Glacier Deep Archive storage class. | `number` | `30` | no |
| monthly\_expiration\_days | Days after which monthly backups expire. | `number` | `400` | no |
| monthly\_prefix | Key prefix for monthly backups. The writer sets a longer per-object retention on these. | `string` | `"monthly/"` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_arn | ARN of the backup bucket. |
| bucket\_name | Name of the backup bucket. |
| writer\_policy\_json | IAM policy granting write-only access for a backup job (no read, list, or delete). |
<!-- END_TF_DOCS -->
