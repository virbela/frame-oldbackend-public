# cloudfront policy gets queried to dupe to the s3 policy
data "aws_iam_policy_document" "bucket_policy_document" {
  statement {
    actions = ["s3:GetObject"]

    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.webapp_mainline.arn]
    }
  }
}


data "aws_iam_policy_document" "quick_bucket_policy_document" {
  statement {
    actions = ["s3:GetObject"]

    resources = ["${module.quick_s3_bucket.s3_bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.webapp_quick.arn]
    }
  }
}

##
# website redirect policies
#
data "aws_iam_policy_document" "mainline_redirect_bucket_policy_document" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.mainline_redirect_s3_bucket.arn,
      "${aws_s3_bucket.mainline_redirect_s3_bucket.arn}/*",
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "quick_redirect_bucket_policy_document" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.quick_redirect_s3_bucket.arn,
      "${aws_s3_bucket.quick_redirect_s3_bucket.arn}/*",
    ]
    effect = "Allow"
  }
}


/* 
Fetch existing hosted zone info from domain name
For the dev environment, the hosted_zone must be
created manually: aws generates and assigns the NS 
records automatically, and they can't be reused
after they're deleted.

This is a pre-existing hosted zone because we don't 
want to destroy a customer's dns if these scripts are 
ever released

We do add A records to this existing resource though
*/

data "aws_route53_zone" "hosted_zone" {
  name = var.dns_base
}

data "aws_caller_identity" "acct_caller_id" {}

data "aws_secretsmanager_secret_version" "common_creds" {
  secret_id = "terraform/common"
}

data "aws_cloudfront_cache_policy" "cache_policy" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "cache_policy_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "origin_policy" {
  name = "Managed-CORS-S3Origin"
}
