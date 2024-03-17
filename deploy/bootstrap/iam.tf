locals {
  issuer   = "token.actions.githubusercontent.com"
  audience = "sts.amazonaws.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://${local.issuer}"
  client_id_list  = ["${local.audience}"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

import {
  to = aws_iam_openid_connect_provider.github_actions
  id = "arn:aws:iam::686862074153:oidc-provider/token.actions.githubusercontent.com"
}

# https://developer.hashicorp.com/terraform/language/settings/backends/s3#s3-bucket-permissions
resource "aws_iam_policy" "terraform_bucket_read_only_access" {
  name_prefix = "TerraformBucketReadOnlyAccess"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:GetObject"],
        Effect   = "Allow",
        Resource = ["${aws_s3_bucket.terraform.arn}/*"]
      },
      {
        Action   = ["s3:ListBucket"],
        Effect   = "Allow",
        Resource = [aws_s3_bucket.terraform.arn]
      }
    ]
  })
}

resource "aws_iam_policy" "terraform_bucket_write_access" {
  name_prefix = "TerraformBucketWriteAccess"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:PutObject"],
        Effect   = "Allow",
        Resource = ["${aws_s3_bucket.terraform.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role" "plan" {
  name_prefix = "plan"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        },
        Condition = {
          StringEquals = {
            "${local.issuer}:sub" = [
              "repo:arianvp/nixos-village:pull_request",
              "repo:arianvp/nixos-village:environment:production"
            ]
          }
        }
      }
    ]
  })
  managed_policy_arns = [
    aws_iam_policy.terraform_bucket_read_only_access.arn,
    "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess",
  ]
}

resource "aws_iam_role" "apply" {
  name_prefix = "apply"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        },
        Condition = {
          StringEquals = {
            "${local.issuer}:sub" = "repo:arianvp/nixos-village:environment:production"
          }
        }
      }
    ]
  })
  managed_policy_arns = [
    aws_iam_policy.terraform_bucket_read_only_access.arn,
    aws_iam_policy.terraform_bucket_write_access.arn,
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
  ]
}
