output "s3_bucket_arn" {
  value = aws_s3_bucket.tf_state.arn
  description = "The ARN of the S3 bucket"
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}