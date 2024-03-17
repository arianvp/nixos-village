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
data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "./bootstrap/terraform.tfstate"
  }
}

locals {
  cache_bucket           = data.terraform_remote_state.bootstrap.outputs.cache_bucket
  cache_region           = data.terraform_remote_state.bootstrap.outputs.cache_region
  nix_substituter        = "s3://${local.cache_bucket}?region=${local.cache_region}"
  nix_trusted_public_key = file("../public.key")
}

resource "aws_launch_template" "web" {
  name          = "web"
  image_id      = data.aws_ami.nixos.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.admin.key_name

  iam_instance_profile { arn = module.instance_profile_web.arn }

  user_data = base64encode(<<-EOF
  #!/usr/bin/env bash
  set -e
  nix build '${var.nix_store_path}' \
    --profile /nix/var/nix/profiles/system \
    --experimental-features 'nix-command' \
    --extra-substituters '${local.nix_substituter}' \
    --extra-trusted-public-keys '${local.nix_trusted_public_key}'
  /nix/var/nix/profiles/system/bin/switch-to-configuration switch
  EOF
  )

  network_interfaces {
    ipv6_address_count  = 1
    enable_primary_ipv6 = true
  }

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

  vpc_zone_identifier = aws_subnet.public.*.id

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  health_check_type = "ELB"

  # These values should be as high as it takes for user-data script to complete.
  # use systemd-analyze to measure the time
  # Or you can set them to 0 if you have a lifecycle hook

  # used by maintenance 
  health_check_grace_period = 300

  # Used by scaling policies and instance refresh
  default_instance_warmup = 300

  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 110
  }

  traffic_source {
    type       = "elbv2"
    identifier = "arn:aws:elasticloadbalancing:eu-central-1:686862074153:targetgroup/web/099a97adf2234b0c"
  }

  instance_refresh {
    strategy = "Rolling"
  }
}
