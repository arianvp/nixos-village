data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default" {
  availability_zone = "eu-central-1a"
  default_for_az    = true
  vpc_id            = data.aws_vpc.default.id
}
