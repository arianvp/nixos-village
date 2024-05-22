resource "aws_s3_bucket" "cache" {
  bucket_prefix = "cache"
  force_destroy = true
}

data "aws_iam_policy_document" "cache_read" {
  statement {
    effect    = ["Allow"]
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cache.arn}/*"]
  }
  statement {
    effect    = ["Allow"]
    actions   = ["s3:GetBucketLocation"]
    resources = ["${aws_s3_bucket.cache.bucket}"]
  }
}

resource "aws_iam_policy" "cache_read" {
  name   = "cache-read"
  policy = data.aws_iam_policy_document.cache_read.json
}

data "aws_iam_policy_document" "cache_write" {
  statement {
    effect    = ["Allow"]
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cache.arn}/*"]
  }
}

resource "aws_iam_policy" "cache_write" {
  name   = "cache-write"
  policy = data.aws_iam_policy_document.cache_write.json
}
