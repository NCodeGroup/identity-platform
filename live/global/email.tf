data "cloudflare_zone" "this" {
  filter = {
    name    = var.domain
    account = { id = var.cloudflare_account_id }
  }
}

locals {
  zone_id = data.cloudflare_zone.this.zone_id
}

# Receive-only mail: Cloudflare forwards each alias to the owner's mailbox. Nothing sends as the domain, so the
# bootstrap's DMARC record stays at p=reject.
resource "cloudflare_email_routing_settings" "this" {
  zone_id = local.zone_id
}

resource "cloudflare_email_routing_dns" "this" {
  zone_id = local.zone_id

  depends_on = [cloudflare_email_routing_settings.this]
}

resource "cloudflare_email_routing_address" "owner" {
  account_id = var.cloudflare_account_id
  email      = var.email_destination
}

resource "cloudflare_email_routing_rule" "alias" {
  for_each = var.email_aliases

  zone_id = local.zone_id
  name    = "${each.key}@${var.domain}"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = "${each.key}@${var.domain}"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.owner.email]
  }]
}

resource "cloudflare_email_routing_catch_all" "this" {
  zone_id = local.zone_id
  name    = "drop unknown recipients"
  enabled = true

  matchers = [{ type = "all" }]
  actions  = [{ type = "drop" }]
}
