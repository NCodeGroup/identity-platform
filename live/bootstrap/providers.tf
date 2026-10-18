provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = module.tags.map
  }
}

# Credentials come from CLOUDFLARE_API_TOKEN (the short-lived bootstrap token).
provider "cloudflare" {}

# Credentials come from GITHUB_TOKEN (a short-lived fine-grained token for this repository only).
provider "github" {
  owner = var.github_owner
}
