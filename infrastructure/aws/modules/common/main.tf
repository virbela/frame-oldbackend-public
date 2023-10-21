###
## Setup infrastructure required in every region
###

terraform {
  required_version = "<= 1.3.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "=4.39.0"
    }
  }
}


###
## Cloudwatch LogGroup
###
resource "aws_cloudwatch_log_group" "log-group" {
  name              = "/ecs/${var.deployment_group}"
  retention_in_days = 3653 # 10yr history

  # tags = {
  #   Name = var.deployment_group
  # }
}


###
## ECS Cluster
###
resource "aws_ecs_cluster" "fargate" {
  name = var.deployment_group

  tags = {
    Name = var.deployment_group
  }
}


