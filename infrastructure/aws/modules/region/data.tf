data "aws_caller_identity" "acct_caller_id" {}

data "aws_route53_zone" "hosted_zone" {
  name = var.dns_base
}