# Lowercased because some vendors normalize tag case on read, which would show up as permanent drift.
locals {
  tags = {
    application = lower(var.application)
    environment = lower(var.environment)
    owner_email = lower(var.owner_email)
    account     = lower(var.account)
    managed_by  = lower(var.managed_by)
    source      = lower(var.source_path)
  }
}
