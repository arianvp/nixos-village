resource "aws_s3_bucket" "cache" {
  bucket_prefix = "nixos-village-cache"
}

resource "aws_secretmanager_secret" "signing_key" {
  name = "nixos-village-signing-key"
}

resource "aws_s3_bucket" "terraform" {
  bucket_prefix = "nixos-village-terraform"
}