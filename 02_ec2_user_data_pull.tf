resource "aws_launch_template" "webserver_user_data_build" {
  image_id      = local.nixos_ami
  instance_type = local.instance_type
  key_name      = aws_key_pair.admin.key_name
  iam_instance_profile {
    name = aws_iam_instance_profile.webserver.name
  }

  user_data = base64encode(<<EOF
  #!/usr/bin/env bash
  set -euo pipefail

  nix-store --realise ${var.nix_closure} --option extra-substituters s3://${aws_s3_bucket.cache.bucket_name}

  EOF)

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "webserver-user-data-build"
    }
  }
}

resource "aws_autoscaling_group" "webserver_user_data_build" {
  name = "webserver-user-data-build"

  max_size         = 1
  min_size         = 0
  desired_capacity = 1

  vpc_zone_identifier = [data.aws_subnet.default.id]

  launch_template {
    name    = aws_launch_template.webserver_user_data_build.name
    version = aws_launch_template.webserver_user_data_build.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
  }
}
