variable "nix_closure" {
  description = "Injected by CI"
}

data "aws_iam_policy_document" "deploy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = ["${aws_s3_bucket.cache.arn}/*", aws_s3_bucket.cache.arn]
  }
  statement {
    actions   = ["autoscaling:CompleteLifecycleAction"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy" {
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.webserver.name
  policy_arn = aws_iam_policy.deploy.arn
}

resource "aws_launch_template" "webserver_user_data_pull" {
  name          = "webserver-user-data-pull"
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

  user_data = base64encode(<<EOF
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
      volume_size = 50
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name       = "webserver-user-data-pull"
      NixClosure = var.nix_closure
    }
  }
}

resource "aws_lb" "web" {
  name               = "web"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_target_group" "web" {
  name     = "web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_autoscaling_group" "webserver_user_data_pull" {
  name = "webserver-user-data-pull"

  max_size         = 3
  min_size         = 0
  desired_capacity = 3

  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.webserver_user_data_pull.id
    version = aws_launch_template.webserver_user_data_pull.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
  }

  default_instance_warmup = 0

  initial_lifecycle_hook {
    name                 = "launching"
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }

  traffic_source {
    type       = "elbv2"
    identifier = aws_lb_target_group.web.arn
  }


}