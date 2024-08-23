resource "aws_ec2_host" "macos" {
  instance_type     = "mac2-m2.metal"
  availability_zone = "eu-central-1a"
}

import {
  id = "h-0e63deea1a63be003"
  to = aws_ec2_host.macos
}

data "aws_ami" "macos" {
  owners = ["amazon"]
  filter {
    name   = "architecture"
    values = ["arm64_mac"]
  }
  most_recent = true
}

import {
  id = "macos"
  to = aws_iam_role.macos
}

import {
  id = "macos"
  to = aws_iam_instance_profile.macos
}

resource "aws_iam_role" "macos" {
  name = "macos"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_instance_profile" "macos" {
  name = "macos"
  role = aws_iam_role.macos.name
}

resource "aws_instance" "macos" {
  ami                  = data.aws_ami.macos.id
  instance_type        = "mac2-m2.metal"
  tenancy              = "host"
  iam_instance_profile = aws_iam_instance_profile.macos.name
  ebs_optimized        = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    throughput  = "1000"
    iops        = "16000"
  }
  tags = {
    Name = "macos"
  }
}

resource "random_password" "password" {
  length  = 16
  special = false
}

resource "aws_ssm_document" "provision_macos" {
  name          = "ProvisionMacOS"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Enable AutoLogin"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "EnableAutoLogin"
        inputs = {
          runCommand = [<<-EOF
            # skip if already enabled, continue if not enabled
            (sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser && exit 0) || true

            # Enable VNC
            sudo launchctl enable system/com.apple.screensharing
            sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

            # Enable AutoLogin
            curl -O https://raw.githubusercontent.com/timsutton/osx-vm-templates/eb09892c82215e15feaed04032d4045a37832a68/scripts/support/set_kcpassword.py
            sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser ec2-user
            sudo dscl . -passwd /Users/ec2-user '${random_password.password.result}'
            sudo python3 ./set_kcpassword.py '${random_password.password.result}'

            # Reboot to apply changes
            # exit 194
            EOF
          ]
        }
      }
    ]
  })
}

# We use SSM instead of user-data as changing User-Data requires instance stop and start
# which takes 2 hours for mac2.metal instances
# NOTE: Make sure this document is idempotent!
/*resource "aws_ssm_document" "provision_macos" {
  name          = "ProvisionMacOS"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Provision MacOS"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "ProvisionMacOS"
        inputs = {
          runCommand = [
            "sudo -u ec2-user /opt/homebrew/bin/brew install cirruslabs/cli/tart",
            "sudo -u ec2-user /opt/homebrew/bin/brew install hashicorp/tap/packer",
            "sudo -u ec2-user /opt/homebrew/bin/brew install hashicorp/tap/terraform",
            "sudo -u ec2-user /opt/homebrew/bin/tart pull ghcr.io/cirruslabs/macos-sonoma-base:latest"
          ]
        }
      }
    ]
  })
}*/

resource "aws_ssm_association" "macos" {
  name             = aws_ssm_document.provision_macos.name
  document_version = aws_ssm_document.provision_macos.document_version
  targets {
    key    = "tag:Name"
    values = ["macos"]
  }
}
