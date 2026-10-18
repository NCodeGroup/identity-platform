locals {
  tags = merge(var.tags, {
    component           = "aws-state-backend"
    role                = "tofu-state"
    data_classification = "restricted"
    deletion_protection = tostring(var.deletion_protection)
  })
}

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = !var.deletion_protection
  tags          = local.tags
}

# prevent_destroy can't take a variable, so a conditional guard blocks `tofu destroy` of the component while protected.
resource "terraform_data" "deletion_guard" {
  count = var.deletion_protection ? 1 : 0

  input = aws_s3_bucket.this.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# Customer managed key used twice: server-side for the bucket, and as the key provider for OpenTofu client-side state and
# plan encryption, so reading state needs both S3 access and kms:Decrypt on this key.
resource "aws_kms_key" "state" {
  description             = "OpenTofu state and plan encryption for ${var.bucket_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = local.tags
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.kms_alias}"
  target_key_id = aws_kms_key.state.key_id
}
