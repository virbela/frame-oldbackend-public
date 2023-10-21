output "alb_tg_netsocket" {
  value       = aws_alb_target_group.alb_tg_netsocket
  description = "load balancer netsocket target group"
}

output "fargate_manage_task" {
  value       = aws_iam_role.fargate_manage_task
  description = "iam role for ecs task"
}

output "cloudfront_distribution" {
  value       = aws_cloudfront_distribution.webapp_mainline.id
  description = "The cloudfront ID used by github deployment as a secret"
}

output "quick_cloudfront_distribution" {
  value       = aws_cloudfront_distribution.webapp_quick.id
  description = "The quick cloudfront ID used by github deployment as a secret"
}

output "dns_data_api_arec" {
  description = "The hosted zone that is updated with A records for <host>.*, api.<host>.*"
  value       = data.aws_route53_zone.hosted_zone.name
}

output "acm_ssl_cert" {
  description = "ACM certificate"
  value       = aws_acm_certificate.cert
}

output "dbuser" {
  description = "Randomized username for mongoDB access"
  value       = random_string.dbuser.id
}

# useful for debug situations
# output "debug_dns_certval_recs" {
#   description = "certificate validation record info"
#   value       = aws_route53_record.cert_validation_mainline
# }

output "aws_account_id" {
  value = data.aws_caller_identity.acct_caller_id.account_id
}

output "connection_string" {
  value = nonsensitive(local.connection_string)
}

output "sns_email_list" {
  value       = var.sns_email_list
  description = "email list for sns alerts"
}