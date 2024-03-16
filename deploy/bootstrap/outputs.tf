output "bucket_arn" {
  value = aws_s3_bucket.terraform.arn
}

output "region" {
  value = aws_s3_bucket.terraform.region
}

output "bucket" {
  value = aws_s3_bucket.terraform.bucket
}

output "cache_bucket" {
  value = aws_s3_bucket.cache.bucket
}

output "cache_region" {
  value = aws_s3_bucket.cache.region
}

output "cache_bucket_arn" {
  value = aws_s3_bucket.cache.arn
}

output "dynamodb_table" {
  value = aws_dynamodb_table.terraform.name
}

