locals {
  tags = merge(var.tags, {
    component           = "aws-backup-bucket"
    role                = "backups"
    data_classification = "restricted"
    deletion_protection = tostring(var.deletion_protection)
  })
}

resource "aws_s3_bucket" "this" {
  bucket              = var.bucket_name
  object_lock_enabled = true
  force_destroy       = !var.deletion_protection
  tags                = local.tags
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

resource "aws_s3_bucket_object_lock_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.default_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  # SSE-S3 on purpose: a KMS key can be scheduled for deletion, which would make locked backups unreadable.
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-daily"
    status = "Enabled"

    filter {
      prefix = var.daily_prefix
    }

    expiration {
      days = var.daily_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "archive-and-expire-monthly"
    status = "Enabled"

    filter {
      prefix = var.monthly_prefix
    }

    transition {
      days          = var.monthly_archive_after_days
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = var.monthly_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]

  lifecycle {
    precondition {
      condition     = var.daily_expiration_days > var.default_retention_days
      error_message = "daily_expiration_days must be greater than default_retention_days, or locked objects outlive their expiration."
    }

    precondition {
      condition     = var.monthly_expiration_days > var.monthly_archive_after_days
      error_message = "monthly_expiration_days must be greater than monthly_archive_after_days."
    }
  }
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

# Write-only access for a backup job: it can add objects and lengthen retention, never read, list, or delete.
data "aws_iam_policy_document" "writer" {
  statement {
    sid    = "WriteBackups"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectRetention",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      "${aws_s3_bucket.this.arn}/${var.daily_prefix}*",
      "${aws_s3_bucket.this.arn}/${var.monthly_prefix}*",
    ]
  }
}
