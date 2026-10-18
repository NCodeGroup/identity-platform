output "name_servers" {
  description = "Cloudflare name servers to set at the registrar."
  value       = module.zone.name_servers
}

output "dnssec_ds" {
  description = "DS record to publish at the registrar once the zone is active."
  value       = module.zone.dnssec
}

output "state_bucket" {
  description = "Bucket that holds every root's state."
  value       = module.state_backend.bucket_name
}

output "state_kms_key_arn" {
  description = "KMS key that encrypts state at rest and client-side in CI roots."
  value       = module.state_backend.kms_key_arn
}

output "backup_bucket" {
  description = "Object Lock bucket for database backups."
  value       = module.backup_bucket.bucket_name
}

output "ci_role_arns" {
  description = "IAM roles GitHub Actions assumes, by name."
  value       = module.github_oidc.role_arns
}
