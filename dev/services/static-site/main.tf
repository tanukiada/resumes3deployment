provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "content_bucket" {
  tags = {
    Name = "Website Bucket"
  }
}

resource "aws_s3_bucket_acl" "content_bucket_acl" {
  bucket = aws_s3_bucket.content_bucket.id
  acl = "private"
}

resource "aws_cloudfront_origin_access_control" "default" {
  name = "resume access control"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "resume-site-log-bucket"
}

resource "aws_s3_bucket_logging" "mylogs" {
  bucket = aws_s3_bucket.content_bucket.id
  
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

locals {
  s3_origin_id = "ResumeWebsiteOriginS3"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.content_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id = local.s3_origin_id
  }

  enabled = true
  is_ipv6_enabled = true
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket = "mylogs.s3.amazonaws.com"
    prefix = "resumesite"
  }

  aliases = ["resume.adataylor.io"]

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  # cache behavior with prrecedence 0
  ordered_cache_behavior {
    path_pattern = "/content/immutable/*"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl = 0
    default_ttl = 86400
    max_ttl = 31536000
    compress = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern = "/content/*"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      cookies {
      forward = "none"
      }
    }

    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
    compress = true
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    environment = "dev"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

terraform {
  backend "s3" {
    bucket = "tf-state-bucket-ada-resume"
    key = "dev/services/static-site/terraform.tfstate"
    region = "us-east-2"

    dynamodb_table = "ada-resume-site-locks"
    encrypt = true
  }
}