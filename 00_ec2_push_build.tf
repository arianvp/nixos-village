resource "aws_launch_template" "webserver_push_build" {
  name          = "webserver-push-build"
  image_id      = local.nixos_ami
  instance_type = "t3.nano"
  key_name      = aws_key_pair.admin.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.webserver.name
  }

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "webserver-push-build"
    }
  }
}

resource "aws_autoscaling_group" "webserver_push_build" {
  name = "webserver-push-build"

  max_size         = 1
  min_size         = 0
  desired_capacity = 1

  vpc_zone_identifier = [data.aws_subnet.default.id]

  launch_template {
    id      = aws_launch_template.webserver_push_build.id
    version = aws_launch_template.webserver_push_build.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
  }
}

