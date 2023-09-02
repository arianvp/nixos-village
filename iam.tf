data "aws_iam_policy_document" "pull_cache" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cache.arn}/*"]
  }
  statement {
    actions   = ["s3:GetBucketLocation"]
    resources = [aws_s3_bucket.cache.arn]
  }
}

resource "aws_iam_policy" "pull_cache" {
  name   = "pull_cache"
  policy = data.aws_iam_policy_document.pull_cache.json
}