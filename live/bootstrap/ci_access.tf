locals {
  state_bucket_arn = module.state_backend.bucket_arn

  # State key prefixes per CI role. The bootstrap state is never reachable from CI.
  ci_state_access = {
    plan = {
      read  = ["global", "lab", "production"]
      write = []
    }
    lab = {
      read  = ["lab"]
      write = ["lab"]
    }
    production = {
      read  = ["global", "lab", "production"]
      write = ["global", "production"]
    }
  }

  # SSM scopes per CI role: /<repository>/<scope>/*.
  ci_secret_scopes = {
    plan       = ["plan"]
    lab        = ["lab"]
    production = ["global", "production"]
  }
}

data "aws_iam_policy_document" "ci" {
  for_each = local.ci_state_access

  statement {
    sid       = "ListState"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = [for p in each.value.read : "${local.state_bucket_arn}/${p}/*"]
  }

  # Native S3 locking writes a .tflock object next to the state; even a read-only plan takes the lock.
  statement {
    sid       = "LockState"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = [for p in each.value.read : "${local.state_bucket_arn}/${p}/*.tflock"]
  }

  dynamic "statement" {
    for_each = length(each.value.write) > 0 ? [1] : []

    content {
      sid       = "WriteState"
      actions   = ["s3:PutObject", "s3:DeleteObject"]
      resources = [for p in each.value.write : "${local.state_bucket_arn}/${p}/*"]
    }
  }

  statement {
    sid       = "UseStateKey"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = [module.state_backend.kms_key_arn]
  }

  statement {
    sid     = "ReadSecrets"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      for s in local.ci_secret_scopes[each.key] :
      "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter${local.ssm_prefix}/${s}/*"
    ]
  }

  statement {
    sid       = "DecryptSecrets"
    actions   = ["kms:Decrypt"]
    resources = [module.secrets_key.key_arn]
  }
}

module "github_oidc" {
  source = "git::https://github.com/NCodeGroup/identity-platform.git//modules/aws-github-oidc?ref=v0.2.0"

  repository = {
    owner    = var.github_owner
    owner_id = data.github_organization.owner.id
    name     = var.github_repository
    id       = module.repository.repository_id
  }

  roles = {
    "${var.name_prefix}-plan" = {
      description = "Read-only plans for pull requests and drift checks on the default branch."
      subjects    = ["pull_request", "ref:refs/heads/main"]
      policy_json = data.aws_iam_policy_document.ci["plan"].json
    }
    "${var.name_prefix}-apply-lab" = {
      description = "Applies the lab environment from the lab GitHub environment."
      subjects    = ["environment:lab"]
      policy_json = data.aws_iam_policy_document.ci["lab"].json
    }
    "${var.name_prefix}-apply-production" = {
      description = "Applies the global and production roots from the reviewer-gated production GitHub environment."
      subjects    = ["environment:production"]
      policy_json = data.aws_iam_policy_document.ci["production"].json
    }
  }
}
