output "current_region" {
  description = "The current region"
  value       = data.aws_region.current_region.name
}

# output "debug_dns_certval_recs" {
#   description = "peek at the certificate validation record info"
#   value       = module.primary_base.debug_dns_certval_recs
# }

output "dns_base" {
  description = "peek at the certificate validation record info"
  value       = var.dns_base
}

output "arn_taskexecution_name" {
  description = "The aws arn used for deployment tasks"
  value       = var.arn_taskexecution_name
}

output "immers_db" {
  description = "The immers-<name> db name to use in the dbstring"
  value       = var.immers_db
}

output "dbuser" {
  description = "mongoDB username"
  value       = module.primary_base.dbuser
}

output "connection_string" {
  description = "mongoDB connection string"
  value       = module.primary_base.connection_string
}

output "authentication_image_path" {
  description = "container image name for authentication"
  value       = var.authentication_image_path
}
output "signaling_image_path" {
  description = "container image name for signaling"
  value       = var.signaling_image_path
}
output "ingress_image_path" {
  description = "container image name for ingress"
  value       = var.ingress_image_path
}
output "egress_image_path" {
  description = "container image name for egress"
  value       = var.egress_image_path
}
output "movement_image_path" {
  description = "container image name for movement"
  value       = var.movement_image_path
}
