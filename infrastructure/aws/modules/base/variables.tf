variable "deployment_group" {
  type        = string
  description = "Environment / site tag"
  default     = "terraform"
}

variable "enableAlerts" {
  description = "True to send the sns alert action for CloudWatch issues"
  type        = bool
}

variable "sns_email_list" {
  description = "list of emails for sns alerts"
  default = ["gabe@framevr.io", "james@framevr.io", "techtruth@gmail.com", "jason@framevr.io", "clint@framevr.io"]
}

variable "dns_base" {
  description = "The dns suffix used for api.*, i.*, quick.*"
}

variable "arn_taskexecution_name" {
  description = "The aws task execution arn name used for deployment tasks"
}

variable "immers_db" {
  description = "The immers-<name> db name to use in the dbstring"
}

variable "vpc" {
}

variable "logGroup" {
}

variable "az_zones" {
}
# variable "task_role_arn" {
# }

# variable "efs_fs" {
# }

variable "ecs_cluster" {
}

variable "sn_public" {
  description = "Public subnet for the signaling server"
}

variable "sn_private" {
  description = "Private group for the signaling server"
}

# variable "sg_ingress" {
#   description = "Security group for the ingress server"
# }

# variable "sg_egress" {
#   description = "Security group for the egress server"
# }


# variable "alb_tg_alt_https" {
#   description = "Load balancer alt https target group"
# }

# variable "alb_tg_netsocket" {
#   description = "Load balancer netsocket target group"
# }

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

variable "authentication_image_path" {
  description = "container image name for authentication"
}
variable "signaling_image_path" {
  description = "container image name for signaling"
}
