locals {
  tags = merge(var.tags, {
    component           = "aws-github-oidc"
    role                = "ci-access"
    data_classification = "internal"
  })

  # GitHub's immutable subject format: repo:<owner>@<owner_id>/<name>@<id>:<context>.
  subject_prefix = "repo:${var.repository.owner}@${var.repository.owner_id}/${var.repository.name}@${var.repository.id}"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = local.tags
}

locals {
  provider_arn = var.create_provider ? aws_iam_openid_connect_provider.github[0].arn : var.provider_arn
}

data "aws_iam_policy_document" "trust" {
  for_each = var.roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for s in each.value.subjects : "${local.subject_prefix}:${s}"]
    }

    # Sessions must be named gh-<run_id>-<run_attempt> so CloudTrail ties every call to its workflow run.
    condition {
      test     = "StringLike"
      variable = "sts:RoleSessionName"
      values   = ["gh-*-*"]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = var.roles

  name                 = each.key
  description          = each.value.description
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = each.value.max_session_duration
  tags                 = local.tags
}

resource "aws_iam_role_policy" "this" {
  for_each = var.roles

  name   = each.key
  role   = aws_iam_role.this[each.key].id
  policy = each.value.policy_json
}
