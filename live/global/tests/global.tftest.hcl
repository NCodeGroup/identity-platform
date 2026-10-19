mock_provider "cloudflare" {
  mock_data "cloudflare_zone" {
    defaults = {
      zone_id = "0123456789abcdef0123456789abcdef"
    }
  }
}

variables {
  email_destination = "owner@example.com"
}

run "every_alias_forwards_to_the_owner" {
  command = plan

  assert {
    condition     = toset(keys(cloudflare_email_routing_rule.alias)) == toset(var.email_aliases)
    error_message = "Each alias needs exactly one routing rule."
  }

  assert {
    condition = alltrue([
      for k, r in cloudflare_email_routing_rule.alias :
      r.matchers[0].value == "${k}@${var.domain}" && r.actions[0].type == "forward"
    ])
    error_message = "A rule must match its own address and forward it."
  }

  assert {
    condition     = contains(var.email_aliases, "security") && contains(var.email_aliases, "postmaster")
    error_message = "security@ (security.txt) and postmaster@ (RFC 5321) must always receive mail."
  }
}

run "unknown_recipients_are_dropped" {
  command = plan

  assert {
    condition     = cloudflare_email_routing_catch_all.this.matchers[0].type == "all" && cloudflare_email_routing_catch_all.this.actions[0].type == "drop"
    error_message = "Mail to any other address must be dropped, never forwarded."
  }

  assert {
    condition     = cloudflare_email_routing_settings.this.support_subaddress == false
    error_message = "Plus-addressed variants of an alias must not be delivered."
  }
}

run "rejects_full_addresses_as_aliases" {
  command = plan

  variables {
    email_aliases = ["security@nidentity.io"]
  }

  expect_failures = [var.email_aliases]
}
