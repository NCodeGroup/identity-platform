output "full_name" {
  description = "Repository as `owner/name`."
  value       = github_repository.this.full_name
}

output "environments" {
  description = "Names of the deployment environments."
  value       = keys(github_repository_environment.this)
}
