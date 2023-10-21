##
# NOTE: certificates must be in us-east-1:
#    https://docs.aws.amazon.com/acm/latest/userguide/acm-regions.html
##
# provider "aws" {
#   alias  = "acm" # certificates must be in us-east-1!!
#   region = "us-east-1"
# }

////////////////////////////////////
/* DNS                            */
////////////////////////////////////
## Generate ACM cert with records for movement
# Must use us-east-1 (https://docs.aws.amazon.com/acm/latest/userguide/acm-regions.html)
resource "aws_acm_certificate" "movement_cert" {
  #provider                  = aws.acm
  domain_name               = "*.movement.${var.dns_base}"
  subject_alternative_names = ["*.movement.${var.dns_base}"]
  validation_method         = "DNS"

  # tf aws_acm_certificate docs recommend enabling create_before_destroy:
  #   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
  #   (api.<deployment>.framevr.io is registered with the lb listener)
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = var.deployment_group
  }
}

/* 
add dns validation CNAME record for movement (subject alt: *.movement.<deployment>.frame.io)
*/
resource "aws_route53_record" "cert_validation_movement" {
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.movement_cert.domain_validation_options)[0].resource_record_name
  type            = tolist(aws_acm_certificate.movement_cert.domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.hosted_zone.zone_id
  records         = [tolist(aws_acm_certificate.movement_cert.domain_validation_options)[0].resource_record_value]
  ttl             = 60
}

/* run the DNS certificate validation */
resource "aws_acm_certificate_validation" "cert_validation_movement" {
  #provider        = aws.acm
  certificate_arn = aws_acm_certificate.movement_cert.arn
  validation_record_fqdns = [
    "${aws_route53_record.cert_validation_movement.fqdn}"
  ]

  timeouts {
    create = "60m"
  }
}