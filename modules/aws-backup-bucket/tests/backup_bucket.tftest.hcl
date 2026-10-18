mock_provider "aws" {}

variables {
  bucket_name = "example-backups"
}

run "bucket_is_locked_in_compliance_mode" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.object_lock_enabled
    error_message = "Backup bucket must enable Object Lock."
  }

  assert {
    condition     = aws_s3_bucket_object_lock_configuration.this.rule[0].default_retention[0].mode == "COMPLIANCE"
    error_message = "Backups must be locked in compliance mode so no credential can delete them early."
  }

  assert {
    condition     = aws_s3_bucket_object_lock_configuration.this.rule[0].default_retention[0].days == 14
    error_message = "Default retention must follow default_retention_days."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets
    error_message = "Backup bucket must block public access."
  }
}

run "protection_follows_variable" {
  command = plan

  variables {
    deletion_protection = false
  }

  assert {
    condition     = length(terraform_data.deletion_guard) == 0 && aws_s3_bucket.this.force_destroy
    error_message = "Disposable environments must be destroyable."
  }
}

run "daily_expiration_must_outlast_retention" {
  command = plan

  variables {
    default_retention_days = 30
    daily_expiration_days  = 15
  }

  expect_failures = [aws_s3_bucket_lifecycle_configuration.this]
}
