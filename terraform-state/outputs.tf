output "bucket_arn" {
  value = aws_s3_bucket.terraform.arn
}

output "region" {
  value = aws_s3_bucket.terraform.region
}

output "bucket" {
  value = aws_s3_bucket.terraform.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.terraform.name
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}