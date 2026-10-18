output "map" {
  description = "Shared tags as a key/value map (AWS `default_tags`, OCI freeform tags)."
  value       = local.tags
}

output "list" {
  description = "Shared tags as sorted `key:value` strings (Akamai tags)."
  value       = sort([for k, v in local.tags : "${k}:${v}"])
}

output "comment" {
  description = "Stable one-line provenance for resources that only support a comment (Cloudflare DNS records, at most 100 characters)."
  value       = substr("managed_by=${local.tags.managed_by} source=${local.tags.source}", 0, 100)
}
