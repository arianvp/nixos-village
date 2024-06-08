resource "aws_key_pair" "admin" {
  key_name   = "admin"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcJgoVsO3GT9aUVUZPTQrOydp+DwVagYlE3aEaslLFaIO65R+kit12mYSQ5J7tq7oDaAr9k09h4yl7onJsn16nO4RDoIAds6JjzdK6p9mjlHw2Kn570B3EnttPQk58tGj1936nXO5Vw/vLDzCgpYcCnfGrCBP1C3MoMnZ3Z51zlogSOMSz7DFmQNCDilnhup2cXmC8ORjg2l+WbkROyNpkS5ZXEjtciJ+o41LkyYjwyDnO60zTRKCu3q2eEht/+eCC859EiYelehUQV9qIIOaUnHtMhO5eUoJLGbsTqzknrHDj0Ff+oJPZqIP0SLk9TE1LoSZkZotx0C4L3f/dvqecPtfuagxE5K9TLEa0427/qQxnFvC4rlur3GjoF3EyaXDMdiN8a0/WhkXkDvGuu7RG2FjDy4sSwWAyO7djmRGq+z7lb+lDEjruiyBqGO71Ay7+sOvGiBCWvUI4zMvp3qQf6Yc9Y5YDRfUJ/a9AXQMLsWmiERMunAITWHipHKYgd7U= arian@framework"
}

resource "aws_key_pair" "utm" {
  key_name   = "utm"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICILdRig9yBu9SLpJQxhSW13yMXsshKibyeeQHUQZwg/ arian@utm"
}


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
  ]
}

module "ssm_documents" {
  source = "./modules/ssm_documents"
}

resource "aws_instance" "web" {
  count                = 2
  ami                  = data.aws_ami.nixos.id
  instance_type        = "t4g.xlarge"
  key_name             = aws_key_pair.utm.key_name
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
    resources = ["arn:aws:s3:::${aws_s3_bucket.ssm_logs.bucket}/*"]
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
    actions   = ["ssm:SendCommand"]
    effect    = "Allow"
    resources = [module.ssm_documents.nixos_deploy.arn]
  }
  statement {
    actions   = ["ssm:SendCommand"]
    effect    = "Allow"
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringLike"
      variable = "ssm:resourceTag/Finance"
      values   = ["WebServer"]
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

resource "github_repository_environment" "production" {
  repository  = "nixos-village"
  environment = "production"
}
