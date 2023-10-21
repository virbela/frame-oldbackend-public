variable "deployment_group" {
  type        = string
  description = "Environment / site tag"
  default     = "terraform"
}

variable "dns_base" {
  description = "The dns suffix used for api.*, i.*, quick.*"
}

variable "fargate_manage_task" {
  description = "The aws task role arn name used for fargate access to deployment tasks"
}
variable "arn_taskexecution_name" {
  description = "The aws task execution arn name used for deployment tasks"
}

variable "vpc" {
}

variable "vpc_cidr" {
  description = "CIDR for the vpc"
}

variable "ecs_cluster" {
}

variable "sn_public" {
  description = "Public subnet for the signaling server"
}

variable "sn_private" {
  description = "Private group for the signaling server"
}

# set to ignored to avoid clobbering manual changes
variable "ingress_desired_count" {
  description = "Desired number of running tasks for ingress (normal operation)" # must be <= autoscale_egress_min_count
  default     = "1"
}

variable "autoscale_ingress_min_count" {
  description = "Minimum number of running tasks for ingress autoscaling" # can be less than 'desired', but why?
  default     = "1"
}

variable "autoscale_ingress_max_count" {
  description = "Maximum number of running tasks ingress autoscaling"
  default     = "4"
}

# set to ignored to avoid clobbering manual changes
variable "egress_desired_count" {
  description = "Desired number of running tasks for egress (normal operation)" # must be <= autoscale_egress_min_count
  default     = "1"
}

variable "autoscale_egress_min_count" {
  description = "Minimum number of running tasks for egress autoscaling" # can be less than 'desired', but why?
  default     = "1"
}

variable "autoscale_egress_max_count" {
  description = "Maximum number of running tasks egress autoscaling"
  default     = "4"
}

variable "aws_account_id" {
  description = "the account id used for policies and ecr hosts"
}

variable "ingress_image_path" {
  description = "container image name for ingress"
}
variable "egress_image_path" {
  description = "container image name for authentication"
}
variable "movement_image_path" {
  description = "container image path for movement"
}

variable "enableAlerts" {
  description = "True to send the sns alert action for EventBridge issues"
  type        = bool
}

variable "sns_email_list" {
  description = "reuse alert email list for EventBridge notifications"
}
