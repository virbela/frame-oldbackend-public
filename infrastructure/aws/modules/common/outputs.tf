output "vpc" {
  value       = aws_vpc.aws-vpc
  description = "VPC"
}

output "vpc_cidr" {
  value       = var.vpc_cidr
  description = "VPC CIDR value"
}

output "logGroup" {
  value       = aws_cloudwatch_log_group.log-group
  description = "CloudWatch Log Group"
}

output "sn_private" {
  value       = aws_subnet.private
  description = "private subnet for fargate container"
}

output "sn_public" {
  value       = aws_subnet.public
  description = "public subnet for fargate container"
}

# output "sg_ingress" {
#     value = aws_security_group.sg_ingress
#     description = "ingress security group for fargate container"
# }

# output "sg_egress" {
#     value = aws_security_group.sg_egress
#     description = "egress security group for fargate container"
# }

output "az_zones" {
  value       = data.aws_availability_zones.available
  description = "availability zones for current region"
}

output "ecs_cluster" {
  value       = aws_ecs_cluster.fargate
  description = "ECS cluster"
}
