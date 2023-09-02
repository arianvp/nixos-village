output "id" {
  value = data.aws_vpc.default.id
}

output "public_subnet_ids" {
  value = data.aws_subnets.default.ids
}

output "private_subnet_ids" {
  value = []
}