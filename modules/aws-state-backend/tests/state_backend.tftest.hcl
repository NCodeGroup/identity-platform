mock_provider "aws" {}

variables {
  bucket_name = "example-tofu-state"
  kms_alias   = "example-state"
}

run "bucket_is_versioned_private_and_tls_only" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "State bucket must be versioned so a damaged state can be rolled back."
  }

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "State bucket must block all public access."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "State bucket must disable ACLs."
  }

  assert {
    condition     = aws_kms_key.state.enable_key_rotation
    error_message = "State encryption key must rotate."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "State bucket must encrypt with the customer managed key, not an AWS owned key."
  }

  assert {
    condition     = aws_kms_alias.state.name == "alias/example-state"
    error_message = "KMS alias must be prefixed with alias/."
  }
}

run "protected_by_default" {
  command = plan

  assert {
    condition     = length(terraform_data.deletion_guard) == 1 && !aws_s3_bucket.this.force_destroy
    error_message = "State backend must be protected from deletion by default."
  }
}

run "unprotected_when_disposable" {
  command = plan

  variables {
    deletion_protection = false
  }

  assert {
    condition     = length(terraform_data.deletion_guard) == 0 && aws_s3_bucket.this.force_destroy
    error_message = "Disposable environments must be destroyable."
  }
}

run "rejects_invalid_bucket_name" {
  command = plan

  variables {
    bucket_name = "Not_A_Valid_Bucket"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_reserved_kms_alias" {
  command = plan

  variables {
    kms_alias = "aws/s3"
  }

  expect_failures = [var.kms_alias]
}
