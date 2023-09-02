resource "aws_s3_bucket" "terraform" {
  bucket_prefix = "nixos-village-terraform"
  force_destroy = true
}

output "bucket_arn" {
  value = aws_s3_bucket.terraform.arn
}

