resource "aws_key_pair" "admin" {
  key_name   = "admin"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcJgoVsO3GT9aUVUZPTQrOydp+DwVagYlE3aEaslLFaIO65R+kit12mYSQ5J7tq7oDaAr9k09h4yl7onJsn16nO4RDoIAds6JjzdK6p9mjlHw2Kn570B3EnttPQk58tGj1936nXO5Vw/vLDzCgpYcCnfGrCBP1C3MoMnZ3Z51zlogSOMSz7DFmQNCDilnhup2cXmC8ORjg2l+WbkROyNpkS5ZXEjtciJ+o41LkyYjwyDnO60zTRKCu3q2eEht/+eCC859EiYelehUQV9qIIOaUnHtMhO5eUoJLGbsTqzknrHDj0Ff+oJPZqIP0SLk9TE1LoSZkZotx0C4L3f/dvqecPtfuagxE5K9TLEa0427/qQxnFvC4rlur3GjoF3EyaXDMdiN8a0/WhkXkDvGuu7RG2FjDy4sSwWAyO7djmRGq+z7lb+lDEjruiyBqGO71Ay7+sOvGiBCWvUI4zMvp3qQf6Yc9Y5YDRfUJ/a9AXQMLsWmiERMunAITWHipHKYgd7U= arian@framework"
}

data "aws_ami" "nixos" {
  owners      = ["427812963091"]
  most_recent = true

  filter {
    name   = "name"
    values = ["nixos/23.11*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "instance_profile_web" {
  source              = "./modules/instance_profile"
  name                = "web"
  managed_policy_arns = [aws_iam_policy.pull_cache.arn]
}

locals {
  nix_substituter    = "s3://${aws_s3_bucket.cache.bucket}?region=${aws_s3_bucket.cache.region}"
  nix_trusted_public_key = "nixos-21.11-1-427812963091"
}

resource "aws_launch_template" "web" {
  name          = "web"
  image_id      = data.aws_ami.nixos.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.admin.key_name

  iam_instance_profile { arn = module.instance_profile_web.arn }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_protocol_ipv6          = "enabled"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  user_data = base64encode(<<EOF
#!/usr/bin/env bash
set -e
nix-store \
  --realise '${var.nix_store_path}' \
  --extra-substituters '${local.nix_substituter}' \
  --extra-trusted-public-keys '${local.nix_trusted_public_key}' \
nix-env --set '${var.nix_store_path}' --profile /nix/var/nix/profiles/system
/nix/var/nix/profiles/system/bin/switch-to-configuration switch
EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 4
    }
  }
}


resource "aws_autoscaling_group" "web" {
  name = "web"

  max_size         = 3
  min_size         = 0
  desired_capacity = 1

  vpc_zone_identifier = module.vpc.public_subnet_ids

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
  default_instance_warmup   = 300

  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 110
  }

  traffic_source {
    type       = "elbv2"
    identifier = aws_lb_target_group.web.arn
  }

  instance_refresh {
    strategy = "Rolling"
  }


}
