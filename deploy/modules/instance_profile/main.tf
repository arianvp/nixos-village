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
  assume_role_policy  = data.aws_iam_policy_document.assume.json
  managed_policy_arns = setunion(var.managed_policy_arns, ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"])

}

resource "aws_iam_instance_profile" "this" {
  name        = var.name
  name_prefix = var.name_prefix
  role        = aws_iam_role.this.name
}
