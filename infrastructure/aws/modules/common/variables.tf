variable "deployment_group" {
  type        = string
  description = "Environment / site tag"
  default     = "terraform"
}

variable "vpc_cidr" {
  description = "CIDR for the vpc"
  default     = "10.10.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnets"
  default     = "10.10.100.0/24"
}

variable "private_subnets" {
  description = "List of private subnets"
  default     = "10.10.0.0/24"
}

# variable "sn_public" {
#   description = "Public subnet"
# }

# variable "sn_private" {
#   description = "Private subnet"
# }

# variable "sg" {
#   description = "Security group"
# }

# variable "alb_tg_https" {
#   description = "Loadbalancer target group"
# }

# variable "alb_tg_dns" {
#   description = "Loadbalancer target group"
# }