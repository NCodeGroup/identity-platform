output "bucket_name" {
  description = "Name of the state bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.this.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key for OpenTofu client-side state and plan encryption."
  value       = aws_kms_key.state.arn
}

output "kms_alias_name" {
  description = "Full alias name of the encryption key (for example `alias/identity-platform-state`)."
  value       = aws_kms_alias.state.name
}
