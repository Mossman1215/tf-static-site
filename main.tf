
## Providers definition
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# The provider below is required to handle ACM and Lambda in a CloudFront context
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

## ACM (AWS Certificate Manager)
# Creates the certificate
resource "aws_acm_certificate" "cert_website" {
  provider = aws.us-east-1 # Wilcard certificate used by CloudFront requires this specific region (https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html)

  domain_name               = var.website_domain_main
  subject_alternative_names = var.website_domain_aliases
  validation_method         = "DNS"

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
    Project   = var.project
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

## S3
# Creates bucket to store logs
resource "aws_s3_bucket" "website_logs" {
  bucket = "${var.website_domain_main}-logs"
  acl    = "log-delivery-write"

  # Comment the following line if you are uncomfortable with Terraform destroying the bucket even if this one is not empty 
  force_destroy = true

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
    Project   = var.project
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Creates bucket to store the static website
resource "aws_s3_bucket" "website_root" {
  bucket = "${var.website_domain_main}-root"
  acl    = "private"

  # Comment the following line if you are uncomfortable with Terraform destroying the bucket even if not empty 
  force_destroy = true

  logging {
    target_bucket = aws_s3_bucket.website_logs.bucket
    target_prefix = "s3/"
  }

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
    Project   = var.project
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = var.project
}

## CloudFront
# Creates the CloudFront distribution to serve the static website
resource "aws_cloudfront_distribution" "website_cdn_root" {
  enabled     = true
  price_class = "PriceClass_All"
  #viewer certificate should only exist if the certificate has been validated with DNS
  dynamic "viewer_certificate" {
    for_each = var.acm_arn_validated == null ? [] : [var.acm_arn_validated]
    content {
      acm_certificate_arn      = viewer_certificate.value
      ssl_support_method       = "sni-only"
      minimum_protocol_version = var.acm_arn_validated == null ? "TLSv1" : "TLSv1.2_2019"
    }
  }
  aliases = var.acm_arn_validated != null ? concat([var.website_domain_main], var.website_domain_aliases) : []
  origin {
    origin_id   = "origin-bucket-${aws_s3_bucket.website_root.id}"
    domain_name = aws_s3_bucket.website_root.bucket_regional_domain_name
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  dynamic "origin" {
    for_each = var.dynamic_paths
    content {
      custom_origin_config {
        http_port                = "80"
        https_port               = "443"
        origin_keepalive_timeout = "5"
        origin_protocol_policy   = "match-viewer"
        origin_read_timeout      = "30"
        origin_ssl_protocols     = ["TLSv1.2", "TLSv1.1", "TLSv1"]
      }

      domain_name = var.dynamic_endpoint
      origin_id   = origin.value
      origin_path = origin.value
    }
  }

  default_root_object = "index.html"

  logging_config {
    bucket = aws_s3_bucket.website_logs.bucket_domain_name
    prefix = "cloudfront/"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "origin-bucket-${aws_s3_bucket.website_root.id}"
    min_ttl          = "0"
    default_ttl      = "300"
    max_ttl          = "1200"

    viewer_protocol_policy = "redirect-to-https" # Redirects any HTTP request to HTTPS
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
    response_page_path    = "/404.html"
    response_code         = 404
  }

  tags = {
    ManagedBy = "terraform"
    Changed   = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
    Project   = var.project
  }

  lifecycle {
    ignore_changes = [
      tags,
      viewer_certificate,
    ]
  }
  depends_on = [aws_cloudfront_origin_access_identity.origin_access_identity]
}

# Creates policy to allow public access to the S3 bucket
resource "aws_s3_bucket_policy" "update_website_root_bucket_policy" {
  bucket = aws_s3_bucket.website_root.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "cloudfrontreadec2write",
  "Statement": 
    {
      "Sid": "cloudfrontread",
      "Effect": "Allow",
      "Principal": { 
        "AWS": "${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"
        },
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "${aws_s3_bucket.website_root.arn}/*"
    }
}
POLICY
  depends_on = [
    aws_cloudfront_origin_access_identity.origin_access_identity,
    aws_s3_bucket.website_root
  ]
}
