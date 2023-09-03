module "instance_profile_web" {
  source              = "../instance_profile"
  name                = var.name
  managed_policy_arns = var.managed_policy_arns
}

resource "aws_launch_template" "this" {
  name          = var.name
  image_id      = var.image_id
  instance_type = var.instance_type
  # key_name      = aws_key_pair.admin.key_name

  iam_instance_profile { arn = module.instance_profile_web.arn }

  key_name = var.key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_protocol_ipv6          = "enabled"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  user_data = var.nix == null ? null : base64encode(<<EOF
#!/usr/bin/env bash
set -e

nix-store \
  --realise ${var.nix.closure} \
  --extra-substituters ${var.nix.subsituter} \
  --extra-trusted-public-keys ${var.nix.trusted_public_key}

nix-env --set ${var.nix.closure} --profile /nix/var/nix/profiles/system

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
