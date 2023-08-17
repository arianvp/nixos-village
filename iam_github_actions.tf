locals {
  audience = "sts.amazonaws.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = [local.audience]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [local.audience]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:arianvp/nixos-village:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                = "github-actions"
  assume_role_policy  = data.aws_iam_policy_document.github_actions.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}
