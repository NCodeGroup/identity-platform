output "bucket_name" {
  description = "Name of the backup bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the backup bucket."
  value       = aws_s3_bucket.this.arn
}

output "writer_policy_json" {
  description = "IAM policy granting write-only access for a backup job (no read, list, or delete)."
  value       = data.aws_iam_policy_document.writer.json
}
