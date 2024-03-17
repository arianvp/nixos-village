module "vpc" {
  source = "./modules/vpc"
}

data "aws_region" "current" {
}

resource "aws_vpc_ipam" "ipam" {
  operating_regions {
    region_name = data.aws_region.current.name
  }
}

resource "aws_vpc_ipam_pool" "ipv4" {
  ipam_scope_id  = aws_vpc_ipam.ipam.private_default_scope_id
  address_family = "ipv4"
  locale         = data.aws_region.current.name
}

resource "aws_vpc_ipam_pool_cidr" "ipv4" {
  ipam_pool_id = aws_vpc_ipam_pool.ipv4.id
  cidr         = "10.0.0.0/8"
}

resource "aws_vpc_ipam_pool" "ipv6" {
  ipam_scope_id    = aws_vpc_ipam.ipam.public_default_scope_id
  address_family   = "ipv6"
  locale           = data.aws_region.current.name
  aws_service      = "ec2"
  public_ip_source = "amazon"
  # needed for manual subnets. Otherwise get error that they're already taken
  # Don't have to do manual stuff once https://github.com/hashicorp/terraform-provider-aws/issues/34615 lands
  auto_import = true
}

resource "aws_vpc_ipam_pool_cidr" "ipv6" {
  ipam_pool_id   = aws_vpc_ipam_pool.ipv6.id
  netmask_length = 52
}

resource "aws_vpc" "main" {
  ipv4_ipam_pool_id   = aws_vpc_ipam_pool.ipv4.id
  ipv4_netmask_length = 16
  ipv6_ipam_pool_id   = aws_vpc_ipam_pool.ipv6.id
  ipv6_netmask_length = 56
  depends_on          = [aws_vpc_ipam_pool_cidr.ipv4, aws_vpc_ipam_pool_cidr.ipv6]
  tags = {
    Name = "main"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "gw"
  }
}

resource "aws_egress_only_internet_gateway" "egress" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "egw"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.egress.id
  }
  tags = {
    Name = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gateway.id
  }
  tags = {
    Name = "public"
  }
}


data "aws_availability_zones" "zones" {
}

# would allow us to not hardcode this shit
resource "aws_subnet" "private" {
  count             = length(data.aws_availability_zones.zones.names)
  vpc_id            = aws_vpc.main.id
  availability_zone = data.aws_availability_zones.zones.names[count.index]

  # Don't have to do manual stuff once https://github.com/hashicorp/terraform-provider-aws/issues/34615 lands
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index)
  assign_ipv6_address_on_creation                = true
  ipv6_native                                    = true
  enable_resource_name_dns_aaaa_record_on_launch = true

  tags = {
    Name = "private-${data.aws_availability_zones.zones.names[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private[count.index].id
}

resource "aws_subnet" "public" {
  count             = length(data.aws_availability_zones.zones.names)
  vpc_id            = aws_vpc.main.id
  availability_zone = data.aws_availability_zones.zones.names[count.index]


  # Don't have to do manual stuff once https://github.com/hashicorp/terraform-provider-aws/issues/34615 lands
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 3 + count.index)
  assign_ipv6_address_on_creation                = true
  ipv6_native                                    = true
  enable_resource_name_dns_aaaa_record_on_launch = true

  tags = {
    Name = "public-${data.aws_availability_zones.zones.names[count.index]}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}
