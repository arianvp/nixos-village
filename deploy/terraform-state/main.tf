resource "aws_s3_bucket" "terraform" {
  bucket_prefix = "nixos-village-terraform"
  force_destroy = true
}

resource "aws_dynamodb_table" "terraform" {
  name         = "nixos-village-terraform"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}