resource "aws_s3_bucket" "vmimport" {
  bucket_prefix = "vmimport"
}

data "aws_iam_policy_document" "assume_vmimport" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vmie.amazonaws.com"]
    }
  }
}
data "aws_iam_policy_document" "vmimport" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.vmimport.arn}",
      "${aws_s3_bucket.vmimport.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:ModifySnapshotAttribute",
      "ec2:CopySnapshot",
      "ec2:RegisterImage",
      "ec2:Describe*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "vmimport" {
  name                = "vmimport"
  assume_role_policy  = data.aws_iam_policy_document.assume_vmimport.json
  managed_policy_arns = []
}