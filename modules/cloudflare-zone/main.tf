resource "cloudflare_zone" "this" {
  account = {
    id = var.account_id
  }
  name = var.name
  type = "full"
}

# prevent_destroy can't take a variable, so a conditional guard blocks `tofu destroy` of the component while protected.
resource "terraform_data" "deletion_guard" {
  count = var.deletion_protection ? 1 : 0

  input = cloudflare_zone.this.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_zone_dnssec" "this" {
  count = var.dnssec_enabled ? 1 : 0

  zone_id = cloudflare_zone.this.id
  status  = "active"
}

locals {
  caa_records = concat(
    [for ca in var.caa_issuers : { tag = "issue", value = ca }],
    [for ca in var.caa_issuers : { tag = "issuewild", value = ca }],
    var.caa_iodef == null ? [] : [{ tag = "iodef", value = var.caa_iodef }],
  )

  dmarc_value = var.dmarc_policy == null ? null : join("; ", compact([
    "v=DMARC1",
    "p=${var.dmarc_policy}",
    "sp=${var.dmarc_policy}",
    "adkim=s",
    "aspf=s",
    var.dmarc_report_email == null ? "" : "rua=mailto:${var.dmarc_report_email}",
  ]))
}

resource "cloudflare_dns_record" "caa" {
  for_each = { for r in local.caa_records : "${r.tag}:${r.value}" => r }

  zone_id = cloudflare_zone.this.id
  name    = var.name
  type    = "CAA"
  ttl     = 3600
  comment = var.record_comment

  data = {
    flags = 0
    tag   = each.value.tag
    value = each.value.value
  }
}

resource "cloudflare_dns_record" "dmarc" {
  count = local.dmarc_value == null ? 0 : 1

  zone_id = cloudflare_zone.this.id
  name    = "_dmarc.${var.name}"
  type    = "TXT"
  ttl     = 3600
  content = "\"${local.dmarc_value}\""
  comment = var.record_comment
}
