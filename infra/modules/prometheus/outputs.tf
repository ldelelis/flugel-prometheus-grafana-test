output "master_subnet_id" {
  value       = aws_instance.prometheus_master.subnet_id
  description = "Subnet ID of the master instance."
}

output "master_discovery_role_arn" {
  value       = aws_iam_role.ec2_discovery_role.arn
  description = "ARN of the attached instance role."
}
