locals {
  tags = merge(var.tags, {
    component           = "aws-kms-key"
    role                = var.role
    data_classification = var.data_classification
    deletion_protection = tostring(var.deletion_protection)
  })
}

resource "aws_kms_key" "this" {
  description             = var.description
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
  tags                    = local.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias}"
  target_key_id = aws_kms_key.this.key_id
}

# prevent_destroy can't take a variable, so a conditional guard blocks `tofu destroy` of the component while protected.
resource "terraform_data" "deletion_guard" {
  count = var.deletion_protection ? 1 : 0

  input = aws_kms_key.this.key_id

  lifecycle {
    prevent_destroy = true
  }
}
