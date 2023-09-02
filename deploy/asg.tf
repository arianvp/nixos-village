
/*resource "aws_autoscaling_group" "webserver_user_data_pull" {
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


}*/