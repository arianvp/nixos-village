data "aws_iam_policy_document" "pull_cache" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.terraform_remote_state.bootstrap.outputs.cache_bucket_arn}/*"]
  }
  statement {
    actions   = ["s3:GetBucketLocation"]
    resources = [data.terraform_remote_state.bootstrap.outputs.cache_bucket_arn]
  }
}

resource "aws_iam_policy" "pull_cache" {
  name   = "pull_cache"
  policy = data.aws_iam_policy_document.pull_cache.json
}