output "zone_id" {
  description = "Cloudflare zone ID."
  value       = cloudflare_zone.this.id
}

output "name_servers" {
  description = "Nameservers to set at the registrar."
  value       = cloudflare_zone.this.name_servers
}

output "status" {
  description = "Zone status; `pending` until the registrar delegates to the name_servers."
  value       = cloudflare_zone.this.status
}

output "dnssec" {
  description = "DS record fields to add at the registrar, or null when DNSSEC is disabled."
  value = var.dnssec_enabled ? {
    ds          = cloudflare_zone_dnssec.this[0].ds
    key_tag     = cloudflare_zone_dnssec.this[0].key_tag
    algorithm   = cloudflare_zone_dnssec.this[0].algorithm
    digest_type = cloudflare_zone_dnssec.this[0].digest_type
    digest      = cloudflare_zone_dnssec.this[0].digest
  } : null
}
