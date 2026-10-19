module "zone" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/cloudflare-zone?ref=v0.2.0"

  account_id     = var.cloudflare_account_id
  name           = var.domain
  caa_iodef      = "mailto:security@${var.domain}"
  record_comment = module.tags.comment
}

locals {
  cloudflare_scope_zone    = "com.cloudflare.api.account.zone"
  cloudflare_scope_account = "com.cloudflare.api.account"

  # CI tokens by SSM scope: the plan token only reads; the global token writes DNS, zone settings, and email routing.
  cloudflare_tokens = {
    plan = {
      zone    = ["Zone Read", "Zone Settings Read", "DNS Read", "SSL and Certificates Read", "Email Routing Rules Read"]
      account = ["Email Routing Addresses Read"]
    }
    global = {
      zone    = ["Zone Read", "Zone Settings Write", "DNS Write", "SSL and Certificates Write", "Email Routing Rules Write"]
      account = ["Email Routing Addresses Write"]
    }
  }

  cloudflare_groups = {
    (local.cloudflare_scope_zone) = {
      for g in data.cloudflare_account_api_token_permission_groups_list.zone.result : g.name => g.id...
    }
    (local.cloudflare_scope_account) = {
      for g in data.cloudflare_account_api_token_permission_groups_list.account.result : g.name => g.id...
    }
  }

  cloudflare_missing_groups = flatten([
    for t in values(local.cloudflare_tokens) : concat(
      [for n in t.zone : n if !contains(keys(local.cloudflare_groups[local.cloudflare_scope_zone]), n)],
      [for n in t.account : n if !contains(keys(local.cloudflare_groups[local.cloudflare_scope_account]), n)],
    )
  ])
}

data "cloudflare_account_api_token_permission_groups_list" "zone" {
  account_id = var.cloudflare_account_id
  scope      = local.cloudflare_scope_zone
}

data "cloudflare_account_api_token_permission_groups_list" "account" {
  account_id = var.cloudflare_account_id
  scope      = local.cloudflare_scope_account
}

resource "time_rotating" "cloudflare_tokens" {
  rotation_days = var.cloudflare_token_rotation_days
}

resource "cloudflare_account_token" "ci" {
  for_each = local.cloudflare_tokens

  account_id = var.cloudflare_account_id
  name       = "${var.github_repository}-${each.key}"
  expires_on = timeadd(time_rotating.cloudflare_tokens.rotation_rfc3339, "720h")

  policies = [
    {
      effect            = "allow"
      permission_groups = [for n in each.value.zone : { id = local.cloudflare_groups[local.cloudflare_scope_zone][n][0] }]
      resources         = jsonencode({ "${local.cloudflare_scope_zone}.${module.zone.zone_id}" = "*" })
    },
    {
      effect            = "allow"
      permission_groups = [for n in each.value.account : { id = local.cloudflare_groups[local.cloudflare_scope_account][n][0] }]
      resources         = jsonencode({ "${local.cloudflare_scope_account}.${var.cloudflare_account_id}" = "*" })
    },
  ]

  lifecycle {
    replace_triggered_by = [time_rotating.cloudflare_tokens]

    precondition {
      condition     = length(local.cloudflare_missing_groups) == 0
      error_message = "Cloudflare permission groups not found: ${join(", ", local.cloudflare_missing_groups)}."
    }
  }
}

resource "aws_ssm_parameter" "cloudflare_token" {
  for_each = cloudflare_account_token.ci

  name        = "${local.ssm_prefix}/${each.key}/cloudflare-api-token"
  description = "Cloudflare API token for the ${each.key} CI scope; rotated by the bootstrap root."
  type        = "SecureString"
  key_id      = module.secrets_key.key_arn
  value       = each.value.value

  tags = {
    component           = "bootstrap"
    role                = "ci-secrets"
    data_classification = "restricted"
  }
}
