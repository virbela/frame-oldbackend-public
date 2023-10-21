# variable "azlocations" {
#   type    = list
#   description = "The region where all resources are created."
#   default     = ["us-east-1a", "us-east-1b"]
# }

variable "deployment_group" {
  description = "The prefix which should be used for all resources in this example"
  default     = "bugs"
}

variable "enableAlerts" {
  description = "True to send the sns alert action for CloudWatch issues"
  type        = bool
  default     = false
}

variable "dns_base" {
  description = "The dns suffix used for api.*, i.*, quick.*"
  default     = "bugs.framevr.io"
}

variable "arn_taskexecution_name" {
  description = "The aws task execution arn name used for deployment tasks"
  default     = "AmazonECSTaskExecutionRolePolicy"
}

variable "immers_db" {
  description = "The immers-<name> db name to use in the dbstring"
  default     = "bugs"
}

# path varies, eg: authentication, authentication/<deployent>
variable "authentication_image_path" {
  description = "ecr path to container image path for authentication"
  default     = "authentication"
}
# path varies, eg: signaling, signaling/<deployent>
variable "signaling_image_path" {
  description = "container image path for signaling"
  default     = "signaling"
}
# path varies, eg: ingress, ingress/<deployent>
variable "ingress_image_path" {
  description = "container image path for ingress"
  default     = "ingress"
}
# path varies, eg: egress, egress/<deployent>
variable "egress_image_path" {
  description = "container image path for egress"
  default     = "egress"
}
variable "movement_image_path" {
  description = "container image path for movement"
  default     = "movement"
}
