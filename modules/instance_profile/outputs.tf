output "name" {
  value = aws_iam_instance_profile.this.name
}

output "id" {
  value = aws_iam_instance_profile.this.id
}

output "arn" {
  value = aws_iam_instance_profile.this.arn
}

output "role_arn" {
  value = aws_iam_role.this.arn
}