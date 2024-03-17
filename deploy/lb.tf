resource "aws_lb" "web" {
  name               = "web"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public.*.id
  ip_address_type    = "dualstack"
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"


  default_action {
    type             = "forward"
    target_group_arn = "arn:aws:elasticloadbalancing:eu-central-1:686862074153:targetgroup/web/099a97adf2234b0c"
  }
}

# BUG IN TERRRAFORM 
/*resource "aws_lb_target_group" "web" {
  name            = "web"
  port            = 80
  protocol        = "HTTP"
  vpc_id          = aws_vpc.main.id
  ip_address_type = "ipv6"
}*/
