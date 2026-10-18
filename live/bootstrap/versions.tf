terraform {
  required_version = "~> 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }

  # The very first apply runs with a local backend from an untracked backend_override.tf (see README).
  backend "s3" {
    bucket       = "${var.name_prefix}-tofu-state-${var.aws_account_id}"
    key          = "bootstrap/terraform.tfstate"
    region       = var.aws_region
    use_lockfile = true
  }

  # Encrypted with an owner-held passphrase: this root creates the KMS key everything else uses, so it can't use it.
  encryption {
    key_provider "pbkdf2" "bootstrap" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "bootstrap" {
      keys = key_provider.pbkdf2.bootstrap
    }

    state {
      method   = method.aes_gcm.bootstrap
      enforced = true
    }

    plan {
      method   = method.aes_gcm.bootstrap
      enforced = true
    }
  }
}
