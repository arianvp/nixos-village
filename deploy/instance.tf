data "aws_ami" "nixos" {
  most_recent = true
  owners      = ["427812963091"]
  filter {
    name   = "name"
    values = ["nixos/24.05*"]
  }
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

data "aws_ami" "nixos_x86_64" {
  most_recent = true
  owners      = ["427812963091"]
  filter {
    name   = "name"
    values = ["nixos/24.05*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "instance_profile_web" {
  source = "./modules/instance_profile"
  name   = "web"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    aws_iam_policy.read_cache.arn,
    aws_iam_policy.write_cache.arn,
    aws_iam_policy.write_ssm_logs.arn,
  ]
}

module "ssm_documents" {
  source = "./modules/ssm_documents"
}

resource "aws_instance" "web" {
  count                = 2
  ami                  = data.aws_ami.nixos.id
  instance_type        = "t4g.xlarge"
  iam_instance_profile = module.instance_profile_web.name
  tags = {
    Name = "web"
  }
  root_block_device {
    volume_size = 20
  }
}

variable "installable" {
  type    = string
  default = "github:arianvp/nixos-village#nixosConfigurations.web.config.system.build.toplevel"
}

resource "aws_s3_bucket" "ssm_logs" {
  bucket_prefix = "ssm-logs"
}

data "aws_iam_policy_document" "write_ssm_logs" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${aws_s3_bucket.ssm_logs.arn}/*"]
  }
}

resource "aws_iam_policy" "write_ssm_logs" {
  name   = "write-ssm-logs"
  policy = data.aws_iam_policy_document.write_ssm_logs.json
}

resource "aws_ssm_association" "web" {
  association_name = "web"
  name             = module.ssm_documents.nixos_deploy.name
  parameters = {
    installable = var.installable
    action      = "switch"
  }
  targets {
    key    = "tag:Name"
    values = ["web"]
  }
  schedule_expression = "rate(30 minutes)"

  output_location {
    s3_bucket_name = aws_s3_bucket.ssm_logs.bucket
    s3_key_prefix  = "web"
  }
}

resource "aws_instance" "web_push" {
  count                = 1
  ami                  = data.aws_ami.nixos_x86_64.id
  instance_type        = "t3.micro"
  iam_instance_profile = module.instance_profile_web.name
  tags = {
    Name = "web-push"
  }
  root_block_device {
    volume_size = 20
  }
}

data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "deploy" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = [module.ssm_documents.nixos_deploy.arn]
  }
  statement {
    effect = "Allow"
    actions = ["ssm:ListCommands", "ssm:ListCommandInvocations"]
    resources = ["*"] 
  }
  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringLike"
      variable = "ssm:resourceTag/Name"
      values   = ["web-push"]
    }
  }
}
resource "aws_iam_policy" "deploy" {
  name   = "deploy"
  policy = data.aws_iam_policy_document.deploy.json
}

data "aws_iam_roles" "admin" {
  name_regex = "AWSReservedSSO_AdministratorAccess_*"
}

data "aws_iam_policy_document" "assume_deploy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = data.aws_iam_roles.admin.arns
    }
  }
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:arianvp/nixos-village:*"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "deploy"
  assume_role_policy = data.aws_iam_policy_document.assume_deploy.json
  managed_policy_arns = [
    aws_iam_policy.read_cache.arn,
    aws_iam_policy.write_cache.arn,
    aws_iam_policy.deploy.arn,
  ]
}

resource "github_actions_variable" "deploy_role" {
  repository    = "nixos-village"
  variable_name = "DEPLOY_ROLE_ARN"
  value         = aws_iam_role.deploy.arn
}

resource "github_actions_variable" "ssm_document_name" {
  repository    = "nixos-village"
  variable_name = "SSM_DOCUMENT_NAME"
  value         = module.ssm_documents.nixos_deploy.name
}

resource "github_actions_variable" "ssm_logs_bucket" {
  repository    = "nixos-village"
  variable_name = "SSM_LOGS_BUCKET"
  value         = aws_s3_bucket.ssm_logs.bucket
}

resource "github_repository_environment" "production" {
  repository  = "nixos-village"
  environment = "production"
}

