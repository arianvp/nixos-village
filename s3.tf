provider "aws" {
  region  = "eu-central-1"
  profile = "AdministratorAccess"
}

resource "aws_s3_bucket" "cache" {
  bucket_prefix = "nixos-village-cache"
}

resource "aws_s3_bucket_policy" "allow_instances_to_read" {
  bucket = aws_s3_bucket.cache.id
  policy = data.aws_iam_policy_document.allow_instances_to_read.json
}