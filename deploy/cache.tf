
resource "aws_s3_bucket" "cache" {
  bucket_prefix = "cache"
}

data "aws_iam_policy_document" "read_cache" {
  statement {
    actions   = ["s3:GetBucketLocation"]
    resources = [aws_s3_bucket.cache.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cache.arn}/*"]
  }
}

resource "aws_iam_policy" "read_cache" {
    name   = "read-cache"
    policy = data.aws_iam_policy_document.read_cache.json 
}

data "aws_iam_policy_document" "write_cache" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cache.arn}/*"]
  }
}

resource "aws_iam_policy" "write_cache" {
    name   = "write-cache"
    policy = data.aws_iam_policy_document.write_cache.json 
}
