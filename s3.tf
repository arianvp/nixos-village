resource "aws_s3_bucket" "cache" {
  bucket_prefix = "nixos-village-cache"
  force_destroy = true
}

resource "aws_s3_bucket" "terraform" {
  bucket_prefix = "nixos-village-terraform"
  force_destroy = true
}