mock_provider "aws" {}

variables {
  alias       = "example-secrets"
  description = "Example secrets"
  role        = "secrets"
  tags = {
    environment = "shared"
  }
}

run "key_rotates_and_is_aliased" {
  command = plan

  assert {
    condition     = aws_kms_key.this.enable_key_rotation
    error_message = "Customer managed keys must rotate."
  }

  assert {
    condition     = aws_kms_key.this.deletion_window_in_days == 30
    error_message = "Deletion must wait the maximum window by default."
  }

  assert {
    condition     = aws_kms_alias.this.name == "alias/example-secrets"
    error_message = "Alias must be prefixed with alias/."
  }

  assert {
    condition = (
      aws_kms_key.this.tags["environment"] == "shared" &&
      aws_kms_key.this.tags["component"] == "aws-kms-key" &&
      aws_kms_key.this.tags["role"] == "secrets" &&
      aws_kms_key.this.tags["data_classification"] == "restricted" &&
      aws_kms_key.this.tags["deletion_protection"] == "true"
    )
    error_message = "Component tags must merge over the caller's shared tags."
  }
}

run "protection_follows_variable" {
  command = plan

  variables {
    deletion_protection = false
  }

  assert {
    condition     = length(terraform_data.deletion_guard) == 0
    error_message = "Disposable environments must be destroyable."
  }
}

run "rejects_aws_reserved_alias" {
  command = plan

  variables {
    alias = "aws/ssm"
  }

  expect_failures = [var.alias]
}
