output "full_name" {
  description = "Repository as `owner/name`."
  value       = github_repository.this.full_name
}

output "repository_id" {
  description = "GitHub's numeric repository ID; unlike the name, it never changes or gets reused."
  value       = github_repository.this.repo_id
}

output "environments" {
  description = "Names of the deployment environments."
  value       = keys(github_repository_environment.this)
}
