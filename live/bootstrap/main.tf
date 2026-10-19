locals {
  repository = "${var.github_owner}/${var.github_repository}"

  # SSM parameter prefix for the secrets CI reads: /<repository>/<scope>/<name>.
  ssm_prefix = "/${var.github_repository}"
}

module "tags" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/tags?ref=v0.2.0"

  application = "ncode-identity"
  environment = "shared"
  owner_email = var.owner_email
  account     = var.name_prefix
  source_path = "${local.repository}/live/bootstrap"
}

module "state_backend" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-state-backend?ref=v0.2.0"

  bucket_name = "${var.name_prefix}-tofu-state-${var.aws_account_id}"
  kms_alias   = "${var.name_prefix}-tofu-state"
}

module "backup_bucket" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-backup-bucket?ref=v0.2.0"

  bucket_name = "${var.name_prefix}-backups-${var.aws_account_id}"
}

module "secrets_key" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-kms-key?ref=v0.2.0"

  alias       = "${var.name_prefix}-secrets"
  description = "Encrypts the SSM parameters that hold vendor tokens for CI."
  role        = "secrets"
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.owner_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.owner_email]
  }

  tags = {
    component           = "bootstrap"
    role                = "cost-guard"
    data_classification = "internal"
  }
}
