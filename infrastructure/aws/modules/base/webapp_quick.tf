###
## Quick 2D interface
###

###
## Create S3 Bucket to store content
###
module "quick_s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "quick.${var.dns_base}" # public bucket could already be claimed
  #acl    = "private"
  block_public_acls = true


  force_destroy = true

  tags = {
    Name = var.deployment_group
  }
}

# add bucket policy to let the CloudFront OAC get objects:
resource "aws_s3_bucket_policy" "quick_bucket_policy" {
  bucket = module.quick_s3_bucket.s3_bucket_id
  policy = data.aws_iam_policy_document.quick_bucket_policy_document.json
}

###
## Cloudfront CDN to distribute webapp globally
###
resource "aws_cloudfront_origin_access_control" "quick_oac" {
  name                              = "quick.${var.deployment_group}"
  description                       = "quick.${var.deployment_group} OAC Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_identity" "quick_oai_id" {
  comment = "quick.${var.deployment_group} static web OAI"
}

resource "aws_cloudfront_distribution" "webapp_quick" {
  origin {
    domain_name              = module.quick_s3_bucket.s3_bucket_bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.quick_oac.id
    origin_id                = "quick.${var.dns_base}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "quick.${var.deployment_group} static web cloudfront s3 dist"
  default_root_object = "index.html"
  aliases             = ["quick.${var.dns_base}"]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }
  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "quick.${var.dns_base}"

    response_headers_policy_id = aws_cloudfront_response_headers_policy.headers_policy_default.id
    cache_policy_id            = data.aws_cloudfront_cache_policy.cache_policy.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.origin_policy.id

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true   # gzip, brotli
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
    cloudfront_default_certificate = true
  }

  tags = {
    Name = var.deployment_group
  }
}


###
## Domain names
###
# Make url root point to cloudfront
resource "aws_route53_record" "quick_interface" {
  name    = "quick.${var.dns_base}"
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.webapp_quick.domain_name
    zone_id                = aws_cloudfront_distribution.webapp_quick.hosted_zone_id
    evaluate_target_health = true
  }
}


###
## Quick website redirect (s3, cloudfront, dns)
###

resource "aws_s3_bucket" "quick_redirect_s3_bucket" {
  bucket = "redirect.quick.${var.dns_base}"

  tags = {
    Name = var.deployment_group
  }
}

# Configuration for S3 static website hosting
resource "aws_s3_bucket_website_configuration" "quick_bucket_website_configuration" {
  bucket = "redirect.quick.${var.dns_base}"

  redirect_all_requests_to {
    host_name = "quick.${var.dns_base}" # redirect target site (quick)
    protocol  = "https"
  }
  # (tags not supported here)
}

###
## Cloudfront CDN distributes website globally
#
resource "aws_cloudfront_distribution" "quick_website_redirect" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.quick_bucket_website_configuration.website_endpoint
    origin_id   = aws_s3_bucket.quick_redirect_s3_bucket.id

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "redirect.quick.${var.deployment_group} static web cloudfront s3 dist"
  aliases         = ["*.quick.${var.dns_base}"]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.quick_redirect_s3_bucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }

  tags = {
    Name = var.deployment_group
  }
}

resource "aws_route53_record" "quick_redirect_dns" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "*.quick.${var.dns_base}"
  type    = "CNAME"
  ttl     = 86400

  records = [aws_cloudfront_distribution.quick_website_redirect.domain_name]

  # (tags not supported here)
}
