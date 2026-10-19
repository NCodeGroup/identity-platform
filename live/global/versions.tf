terraform {
  required_version = "~> 1.13.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
  }

  backend "s3" {
    bucket       = "${var.name_prefix}-tofu-state-${var.aws_account_id}"
    key          = "global/terraform.tfstate"
    region       = var.aws_region
    use_lockfile = true
  }

  encryption {
    key_provider "aws_kms" "state" {
      kms_key_id = "alias/${var.name_prefix}-tofu-state"
      region     = var.aws_region
      key_spec   = "AES_256"
    }

    method "aes_gcm" "state" {
      keys = key_provider.aws_kms.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}
