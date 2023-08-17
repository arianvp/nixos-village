locals {
  # https://nixos.org/download#nixos-amazon
  nixos_ami = "ami-0d6ee9d5e1c985df6"
}

resource "aws_key_pair" "admin" {
  key_name   = "admin"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_launch_template" "nixos" {
  image_id      = local.nixos_ami
  instance_type = "t3.micro"
  key_name      = aws_key_pair.admin.key_name

  user_data = base64encode(file("config/configuration.nix"))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "nixos"
    }
  }
}

resource "aws_instance" "nixos" {
  launch_template {
    name    = aws_launch_template.nixos.name
    version = aws_launch_template.nixos.latest_version
  }
  tags = { Name = "nixos" }
}
