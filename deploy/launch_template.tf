
module "instance_profile_web" {
  source              = "./modules/instance_profile"
  name                = "web"
  managed_policy_arns = [aws_iam_policy.pull_cache.arn]
}

resource "aws_launch_template" "web" {
  name          = "web"
  image_id      = var.image_id
  instance_type = var.instance_type
  # key_name      = aws_key_pair.admin.key_name

  iam_instance_profile { arn = module.instance_profile_web.arn }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_protocol_ipv6          = "enabled"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # TODO: cache.pub

  user_data = var.nix_closure == null ? null : base64encode(<<EOF
#!/usr/bin/env bash
set -e

nix-store \
  --realise ${var.nix_closure} \
  --extra-substituters s3://${aws_s3_bucket.cache.bucket}?region=${aws_s3_bucket.cache.region} \
  --extra-trusted-public-keys ${file("cache.pub")}

nix-env --set ${var.nix_closure} --profile /nix/var/nix/profiles/system

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

