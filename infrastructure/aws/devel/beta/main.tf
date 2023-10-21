###
## Infrastructure
##   Setup IAM roles and availability zones
##   Call common module in us-east-1
##   Call base module in us-east-1
##   Call common module in other regions
##   Call region module in other regions 
###

### Notes
## fargate cpu/mem: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
## https://particule.io/en/blog/cicd-ecr-ecs/
## https://engineering.finleap.com/posts/2020-02-20-ecs-fargate-terraform/
## Fargate 1.4.0+ needs to launch tasks in a private subnet having a VPC routing 
## table to a NAT gateway in a public subnet
## (https://itecnote.com/tecnote/r-aws-ecs-fargate-resourceinitializationerror-unable-to-pull-secrets-or-registry-auth/)
###

data "aws_region" "current_region" {}
#data "aws_availability_zones" "available" {
#  state = "available"
#}

###
## AWS Regions
##
## NOTE!: terraform can't remove provider aliases
##   until the resource has been removed first
###
provider "aws" {
  alias  = "n_virginia"
  region = "us-east-1"
}

provider "aws" {
  alias  = "frankfurt"
  region = "eu-central-1"
}

provider "aws" {
  alias  = "mumbai"
  region = "ap-south-1"
}

provider "aws" {
  alias  = "sydney"
  region = "ap-southeast-2"
}

###
## Setup common layer and base layer
###
module "primary_common" {
  source = "../../modules/common"

  providers = {
    aws = aws.n_virginia
  }

  deployment_group = var.deployment_group
}

module "primary_base" {
  source = "../../modules/base"

  providers = {
    aws = aws.n_virginia
  }

  enableAlerts = var.enableAlerts
  logGroup     = module.primary_common.logGroup

  dns_base                  = var.dns_base
  arn_taskexecution_name    = var.arn_taskexecution_name
  authentication_image_path = var.authentication_image_path
  signaling_image_path      = var.signaling_image_path

  immers_db        = var.immers_db
  vpc              = module.primary_common.vpc
  az_zones         = module.primary_common.az_zones
  ecs_cluster      = module.primary_common.ecs_cluster
  sn_public        = module.primary_common.sn_public
  sn_private       = module.primary_common.sn_private
  deployment_group = var.deployment_group
}

### input for github secret (<DEPLOYMENT>_CLOUDFRONT)
output "cloudfrontID" {
  description = "cloudfront ID for GitHub"
  value       = module.primary_base.cloudfront_distribution
}

###
## Setup common layer and primary regional layer
###
module "primary_region" {
  source = "../../modules/region"

  providers = {
    aws = aws.n_virginia
  }

  dns_base               = var.dns_base
  fargate_manage_task    = module.primary_base.fargate_manage_task
  arn_taskexecution_name = var.arn_taskexecution_name
  vpc                    = module.primary_common.vpc
  vpc_cidr               = module.primary_common.vpc_cidr
  aws_account_id         = module.primary_base.aws_account_id
  ingress_image_path     = var.ingress_image_path
  egress_image_path      = var.egress_image_path
  movement_image_path    = var.movement_image_path

  ecs_cluster = module.primary_common.ecs_cluster

  sn_public  = module.primary_common.sn_public
  sn_private = module.primary_common.sn_private

  enableAlerts   = var.enableAlerts
  sns_email_list = module.primary_base.sns_email_list

  ingress_desired_count       = 1
  autoscale_ingress_min_count = 1
  autoscale_ingress_max_count = 4

  egress_desired_count       = 1
  autoscale_egress_min_count = 1
  autoscale_egress_max_count = 4

  deployment_group = var.deployment_group
}

################################################
## Media Servers
################################################

###
## Frankfurt region (ingress, egress)
###
module "frankfurt_common" {
  source = "../../modules/common"

  providers = {
    aws = aws.frankfurt
  }

  deployment_group = var.deployment_group
}

module "frankfurt_region" {
  source = "../../modules/region"

  providers = {
    aws = aws.frankfurt
  }

  dns_base               = var.dns_base
  fargate_manage_task    = module.primary_base.fargate_manage_task
  arn_taskexecution_name = var.arn_taskexecution_name
  vpc                    = module.frankfurt_common.vpc
  vpc_cidr               = module.primary_common.vpc_cidr
  aws_account_id         = module.primary_base.aws_account_id
  ingress_image_path     = var.ingress_image_path
  egress_image_path      = var.egress_image_path
  movement_image_path    = var.movement_image_path

  ecs_cluster = module.frankfurt_common.ecs_cluster

  sn_public  = module.frankfurt_common.sn_public
  sn_private = module.frankfurt_common.sn_private

  enableAlerts   = var.enableAlerts
  sns_email_list = module.primary_base.sns_email_list

  ingress_desired_count       = 1
  autoscale_ingress_min_count = 1
  autoscale_ingress_max_count = 4

  egress_desired_count       = 1
  autoscale_egress_min_count = 1
  autoscale_egress_max_count = 4

  deployment_group = var.deployment_group
}

###
## Mumbai region (ingress, egress)
###
module "mumbai_common" {
  source = "../../modules/common"

  providers = {
    aws = aws.mumbai
  }

  deployment_group = var.deployment_group
}

module "mumbai_region" {
  source = "../../modules/region"

  providers = {
    aws = aws.mumbai
  }

  dns_base               = var.dns_base
  fargate_manage_task    = module.primary_base.fargate_manage_task
  arn_taskexecution_name = var.arn_taskexecution_name
  vpc                    = module.mumbai_common.vpc
  vpc_cidr               = module.primary_common.vpc_cidr
  aws_account_id         = module.primary_base.aws_account_id
  ingress_image_path     = var.ingress_image_path
  egress_image_path      = var.egress_image_path
  movement_image_path    = var.movement_image_path

  ecs_cluster = module.mumbai_common.ecs_cluster

  sn_public  = module.mumbai_common.sn_public
  sn_private = module.mumbai_common.sn_private

  enableAlerts   = var.enableAlerts
  sns_email_list = module.primary_base.sns_email_list

  ingress_desired_count       = 1
  autoscale_ingress_min_count = 1
  autoscale_ingress_max_count = 4

  egress_desired_count       = 1
  autoscale_egress_min_count = 1
  autoscale_egress_max_count = 4

  deployment_group = var.deployment_group
}

###
## Sydney region (ingress, egress)
###
module "sydney_common" {
  source = "../../modules/common"

  providers = {
    aws = aws.sydney
  }

  deployment_group = var.deployment_group
}

module "sydney_region" {
  source = "../../modules/region"

  providers = {
    aws = aws.sydney
  }

  dns_base               = var.dns_base
  fargate_manage_task    = module.primary_base.fargate_manage_task
  arn_taskexecution_name = var.arn_taskexecution_name
  vpc                    = module.sydney_common.vpc
  vpc_cidr               = module.primary_common.vpc_cidr
  aws_account_id         = module.primary_base.aws_account_id
  ingress_image_path     = var.ingress_image_path
  egress_image_path      = var.egress_image_path
  movement_image_path    = var.movement_image_path

  ecs_cluster = module.sydney_common.ecs_cluster

  sn_public  = module.sydney_common.sn_public
  sn_private = module.sydney_common.sn_private

  enableAlerts   = var.enableAlerts
  sns_email_list = module.primary_base.sns_email_list

  ingress_desired_count       = 1
  autoscale_ingress_min_count = 1
  autoscale_ingress_max_count = 4

  egress_desired_count       = 1
  autoscale_egress_min_count = 1
  autoscale_egress_max_count = 4

  deployment_group = var.deployment_group
}
