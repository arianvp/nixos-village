resource "aws_key_pair" "admin" {
  key_name   = "admin"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcJgoVsO3GT9aUVUZPTQrOydp+DwVagYlE3aEaslLFaIO65R+kit12mYSQ5J7tq7oDaAr9k09h4yl7onJsn16nO4RDoIAds6JjzdK6p9mjlHw2Kn570B3EnttPQk58tGj1936nXO5Vw/vLDzCgpYcCnfGrCBP1C3MoMnZ3Z51zlogSOMSz7DFmQNCDilnhup2cXmC8ORjg2l+WbkROyNpkS5ZXEjtciJ+o41LkyYjwyDnO60zTRKCu3q2eEht/+eCC859EiYelehUQV9qIIOaUnHtMhO5eUoJLGbsTqzknrHDj0Ff+oJPZqIP0SLk9TE1LoSZkZotx0C4L3f/dvqecPtfuagxE5K9TLEa0427/qQxnFvC4rlur3GjoF3EyaXDMdiN8a0/WhkXkDvGuu7RG2FjDy4sSwWAyO7djmRGq+z7lb+lDEjruiyBqGO71Ay7+sOvGiBCWvUI4zMvp3qQf6Yc9Y5YDRfUJ/a9AXQMLsWmiERMunAITWHipHKYgd7U= arian@framework"
}

module "launch_template_web" {
  source        = "./modules/launch_template"
  name          = "web"
  image_id      = aws_ami.image.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.admin.key_name
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
