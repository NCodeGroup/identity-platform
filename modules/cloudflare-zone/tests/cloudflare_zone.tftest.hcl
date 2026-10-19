mock_provider "cloudflare" {}

variables {
  account_id         = "0123456789abcdef0123456789abcdef"
  name               = "example.com"
  caa_iodef          = "mailto:security@example.com"
  dmarc_report_email = "dmarc@example.com"
  record_comment     = "managed_by=opentofu source=exampleorg/example-infra/live/bootstrap"
}

run "zone_is_signed_and_hardened" {
  command = plan

  assert {
    condition     = cloudflare_zone.this.type == "full"
    error_message = "The zone must be a full (authoritative) setup."
  }

  assert {
    condition     = cloudflare_zone_dnssec.this[0].status == "active"
    error_message = "DNSSEC must be enabled by default."
  }

  assert {
    condition = toset(keys(cloudflare_dns_record.caa)) == toset([
      "issue:letsencrypt.org",
      "issuewild:letsencrypt.org",
      "iodef:mailto:security@example.com",
    ])
    error_message = "CAA must allow only the configured CAs, including for wildcards."
  }

  assert {
    condition     = cloudflare_universal_ssl_setting.this.enabled == false
    error_message = "Universal SSL must be off, or Cloudflare publishes CAA records for its own CAs beside the configured ones."
  }

  assert {
    condition     = cloudflare_dns_record.dmarc[0].content == "\"v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; rua=mailto:dmarc@example.com\""
    error_message = "DMARC must reject unauthenticated mail for the apex and subdomains."
  }

  assert {
    condition     = length(terraform_data.deletion_guard) == 1
    error_message = "The zone must be protected from deletion by default."
  }
}

run "dmarc_and_dnssec_can_be_turned_off" {
  command = plan

  variables {
    dnssec_enabled      = false
    dmarc_policy        = null
    deletion_protection = false
  }

  assert {
    condition     = length(cloudflare_zone_dnssec.this) == 0 && length(cloudflare_dns_record.dmarc) == 0
    error_message = "DNSSEC and DMARC must be optional."
  }

  assert {
    condition     = length(terraform_data.deletion_guard) == 0
    error_message = "Disposable zones must be destroyable."
  }
}

run "rejects_empty_caa_issuers" {
  command = plan

  variables {
    caa_issuers = []
  }

  expect_failures = [var.caa_issuers]
}

run "rejects_bad_dmarc_policy" {
  command = plan

  variables {
    dmarc_policy = "block"
  }

  expect_failures = [var.dmarc_policy]
}
