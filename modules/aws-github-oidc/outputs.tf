output "provider_arn" {
  description = "ARN of the GitHub OIDC identity provider."
  value       = local.provider_arn
}

output "role_arns" {
  description = "Role ARNs keyed by role name."
  value       = { for name, role in aws_iam_role.this : name => role.arn }
}
