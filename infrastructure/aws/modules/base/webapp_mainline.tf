###
## Mainline cloudfront website
###

###
## Create S3 Bucket to store content
###
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "mainline.${var.dns_base}" # public bucket could already be claimed
  #acl    = "private"
  block_public_acls = true

  force_destroy = true

  tags = {
    Name = var.deployment_group
  }
}

# add bucket policy to let the CloudFront OAC get objects:
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = module.s3_bucket.s3_bucket_id
  policy = data.aws_iam_policy_document.bucket_policy_document.json
}

###
## Cloudfront CDN distributes webapp globally
###
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = var.deployment_group
  description                       = "${var.deployment_group} OAC Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_identity" "oai_id" {
  comment = "${var.deployment_group} static web OAI"
}

resource "aws_cloudfront_distribution" "webapp_mainline" {
  origin {
    domain_name              = module.s3_bucket.s3_bucket_bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = var.dns_base
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.deployment_group} static web cloudfront s3 dist"
  default_root_object = "index.html"
  aliases             = ["${var.dns_base}"]

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

  # Cache behavior with precedence 1
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.dns_base

    response_headers_policy_id = aws_cloudfront_response_headers_policy.headers_policy_default.id
    cache_policy_id            = data.aws_cloudfront_cache_policy.cache_policy.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.origin_policy.id

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true   # gzip, brotli
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "index.html"   # disable cache
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.dns_base

    response_headers_policy_id = aws_cloudfront_response_headers_policy.headers_policy_index.id
    cache_policy_id            = data.aws_cloudfront_cache_policy.cache_policy_disabled.id   # disable cache
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
resource "aws_route53_record" "websiteurl" {
  name    = var.dns_base
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.webapp_mainline.domain_name
    zone_id                = aws_cloudfront_distribution.webapp_mainline.hosted_zone_id
    evaluate_target_health = true
  }
}


###
## Mainline website redirect (s3, cloudfront, dns)
###

resource "aws_s3_bucket" "mainline_redirect_s3_bucket" {
  bucket = "redirect.${var.dns_base}"

  tags = {
    Name = var.deployment_group
  }
}

# Configuration for S3 static website hosting
resource "aws_s3_bucket_website_configuration" "mainline_bucket_website_configuration" {
  bucket = "redirect.${var.dns_base}"

  redirect_all_requests_to {
    host_name = var.dns_base # redirect target site (mainline)
    protocol  = "https"
  }
  # (tags not supported here)
}

###
## Cloudfront CDN distributes website globally
#
# Known issue: "Please disassociate the policy before deleting"
# Workround for cloudfront headers policy changes:
# 2 terraform executions: once to reassociate the policy, once to remove the unused policy
# 1. First of all you have to delete the asignation
# **response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id**
# but you have to keep the resource "aws_cloudfront_response_headers_policy" in your terraform configuration file.
# 2. terraform apply the chage
# 3. Change the script again to delete the resource "aws_cloudfront_response_headers_policy" .
# 4. terrafom apply
#   (https://github.com/hashicorp/terraform-provider-aws/issues/21730)
#
###

# TODO: remove after initial change
resource "aws_cloudfront_response_headers_policy" "security_headers_policy" {
  name = "security-headers-policy-${var.deployment_group}"

  security_headers_config {
    # X-Content-Type-Option
    content_type_options {
      override = true # nosniff
    }

    # frame can't be put in an iframe with this option enabled
    # X-Frame-Options = 
    #frame_options {
    #  frame_option = "DENY"
    #  override     = true
    #}

    # Referrer-Policy
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # Strict-Transport-Security
    strict_transport_security {
      access_control_max_age_sec = "63072000"
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    # X-XSS-Protection
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }

}

resource "aws_cloudfront_response_headers_policy" "headers_policy_index" {
  name = "headers-policy-index-${var.deployment_group}"

  security_headers_config {
    # X-Content-Type-Option
    content_type_options {
      override = true # nosniff
    }

    # frame can't be put in an iframe with this option enabled
    # X-Frame-Options = 
    #frame_options {
    #  frame_option = "DENY"
    #  override     = true
    #}

    # Referrer-Policy
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # Strict-Transport-Security
    strict_transport_security {
      access_control_max_age_sec = "63072000"
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    # X-XSS-Protection
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "no-cache"
    }
  }

}

resource "aws_cloudfront_response_headers_policy" "headers_policy_default" {
  name = "headers-policy-default-${var.deployment_group}"

  security_headers_config {
    # X-Content-Type-Option
    content_type_options {
      override = true # nosniff
    }

    # frame can't be put in an iframe with this option enabled
    # X-Frame-Options = 
    #frame_options {
    #  frame_option = "DENY"
    #  override     = true
    #}

    # Referrer-Policy
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # Strict-Transport-Security
    strict_transport_security {
      access_control_max_age_sec = "63072000"
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    # X-XSS-Protection
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "max-age=31536000, immutable"
    }
  }

}

###
## Cloudfront CDN distributes website globally
resource "aws_cloudfront_distribution" "mainline_website_redirect" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.mainline_bucket_website_configuration.website_endpoint
    origin_id   = aws_s3_bucket.mainline_redirect_s3_bucket.id

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "redirect.${var.deployment_group} static web cloudfront s3 dist"
  aliases         = ["*.${var.dns_base}"]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Cache behavior with precedence 1
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.mainline_redirect_s3_bucket.id

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

resource "aws_route53_record" "mainline_redirect_dns" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "*.${var.dns_base}"
  type    = "CNAME"
  ttl     = 86400

  records = [aws_cloudfront_distribution.mainline_website_redirect.domain_name]

  # (tags not supported here)
}
