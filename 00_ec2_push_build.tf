resource "aws_launch_template" "webserver_push_build" {
  name          = "webserver-push-build"
  image_id      = local.nixos_ami
  instance_type = "t3.medium"
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

resource "aws_instance" "webserver_push_build" {
  tags = { Name = "webserver-push-build" }

  launch_template {
    id      = aws_launch_template.webserver_push_build.id
    version = aws_launch_template.webserver_push_build.latest_version
  }

}

output "webserver_push_build_public_ip" {
  value = aws_instance.webserver_push_build.public_ip
}