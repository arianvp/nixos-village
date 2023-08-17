locals {
  # https://nixos.org/download#nixos-amazon
  nixos_ami     = "ami-0d6ee9d5e1c985df6"
  instance_type = "t3.medium"
}

resource "aws_key_pair" "admin" {
  key_name   = "admin"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcJgoVsO3GT9aUVUZPTQrOydp+DwVagYlE3aEaslLFaIO65R+kit12mYSQ5J7tq7oDaAr9k09h4yl7onJsn16nO4RDoIAds6JjzdK6p9mjlHw2Kn570B3EnttPQk58tGj1936nXO5Vw/vLDzCgpYcCnfGrCBP1C3MoMnZ3Z51zlogSOMSz7DFmQNCDilnhup2cXmC8ORjg2l+WbkROyNpkS5ZXEjtciJ+o41LkyYjwyDnO60zTRKCu3q2eEht/+eCC859EiYelehUQV9qIIOaUnHtMhO5eUoJLGbsTqzknrHDj0Ff+oJPZqIP0SLk9TE1LoSZkZotx0C4L3f/dvqecPtfuagxE5K9TLEa0427/qQxnFvC4rlur3GjoF3EyaXDMdiN8a0/WhkXkDvGuu7RG2FjDy4sSwWAyO7djmRGq+z7lb+lDEjruiyBqGO71Ay7+sOvGiBCWvUI4zMvp3qQf6Yc9Y5YDRfUJ/a9AXQMLsWmiERMunAITWHipHKYgd7U= arian@framework"
}

resource "aws_launch_template" "webserver" {
  image_id      = local.nixos_ami
  instance_type = local.instance_type
  key_name      = aws_key_pair.admin.key_name
  iam_instance_profile {
    name = aws_iam_instance_profile.webserver.name
  }

  /*
  Sets the user data to the nix config.

  When the instance boots, it will take this config and nixos-rebuild switch into it.

  Problems:
  * Uses the nix-channel version of when the AMI was uploaded. This is never updated.
  * You will miss any kernel updates as the AMI is never updated
  * Building locally can use a lot of resources which makes this fail on smaller instances like t3.micro
  * For example ssm-agent is not in cache for the AMI, so it will need to rebuild it from scratch.
  * this takes like 10 minutes. So boot time is now 10 minutes! unacceptable.
  */
  user_data = base64encode(file("config/webserver.nix"))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "webserver"
    }
  }
}

resource "aws_instance" "webserver" {
  launch_template {
    name    = aws_launch_template.webserver.name
    version = aws_launch_template.webserver.latest_version
  }
  tags = { Name = "webserver" }
}
