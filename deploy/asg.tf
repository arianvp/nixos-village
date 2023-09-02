module "launch_template_web" {
  source        = "./modules/launch_template"
  name          = "web"
  image_id      = var.image_id
  instance_type = var.instance_type
}

resource "aws_autoscaling_group" "web" {
  name = "web"

  max_size         = 3
  min_size         = 0
  desired_capacity = 1

  vpc_zone_identifier = module.vpc.public_subnet_ids

  launch_template {
    id      = module.launch_template_web.id
    version = module.launch_template_web.latest_version
  }


  # default_instance_warmup = 0


  /*initial_lifecycle_hook {
    name                 = "launching"
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }*/

  traffic_source {
    type       = "elbv2"
    identifier = aws_lb_target_group.web.arn
  }

  instance_refresh {
    strategy = "Rolling"
  }


}
