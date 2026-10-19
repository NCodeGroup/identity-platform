output "zone_id" {
  description = "Cloudflare zone of the apex domain."
  value       = local.zone_id
}

output "email_addresses" {
  description = "Addresses that receive mail; all others are dropped."
  value       = sort([for a in var.email_aliases : "${a}@${var.domain}"])
}
