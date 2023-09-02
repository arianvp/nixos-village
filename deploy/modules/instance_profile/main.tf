data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name                = var.name
  name_prefix         = var.name_prefix
  path                = var.path
  assume_role_policy  = data.aws_iam_policy_document.assume.json
  managed_policy_arns = var.managed_policy_arns

}

resource "aws_iam_instance_profile" "this" {
  name = aws_iam_role.this.name
  path = var.path
  role = aws_iam_role.this.name
}